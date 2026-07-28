import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/models/cost_of_quality.dart';

import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/quality_metrics_calculator.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/field_regenerate_undo_buttons.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/planning_ai_notes_card.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/inner_page_navigation_hint.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/launch_editable_section.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';
import 'package:ndu_project/widgets/csv_import_dialog.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
enum _QualityTab { plan, objectives, inspection, audit, metrics, coq }

const _dateHint = 'Select date';

String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

QualityManagementData _qualityData(BuildContext context,
 {bool listen = false}) {
 final data = ProjectDataHelper.getData(context, listen: listen);
 return data.qualityManagementData ?? QualityManagementData.empty();
}

Future<bool> _updateQualityData(
 BuildContext context, {
 required String checkpoint,
 required QualityManagementData Function(QualityManagementData current)
 updater,
 String? successMessage,
}) async {
 final success = await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: checkpoint,
 showSnackbar: false,
 dataUpdater: (data) {
 final current =
 data.qualityManagementData ?? QualityManagementData.empty();
 return data.copyWith(qualityManagementData: updater(current));
 },
 );

 if (context.mounted && success && successMessage != null) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(successMessage),
 behavior: SnackBarBehavior.floating,
 backgroundColor: const Color(0xFF16A34A),
 ),
 );
 }

 if (context.mounted && !success) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Unable to save quality data'),
 behavior: SnackBarBehavior.floating,
 backgroundColor: Color(0xFFDC2626),
 ),
 );
 }

 return success;
}

DateTime? _parseFlexibleDate(String raw) {
 final trimmed = raw.trim();
 if (trimmed.isEmpty) return null;

 final parsedIso = DateTime.tryParse(trimmed);
 if (parsedIso != null) return parsedIso;

 final mmdd = RegExp(r'^(\d{1,2})\/(\d{1,2})$').firstMatch(trimmed);
 if (mmdd != null) {
 final month = int.tryParse(mmdd.group(1) ?? '');
 final day = int.tryParse(mmdd.group(2) ?? '');
 if (month != null && day != null) {
 return DateTime(DateTime.now().year, month, day);
 }
 }

 final mmddyy =
 RegExp(r'^(\d{1,2})\/(\d{1,2})\/(\d{2}|\d{4})$').firstMatch(trimmed);
 if (mmddyy != null) {
 final month = int.tryParse(mmddyy.group(1) ?? '');
 final day = int.tryParse(mmddyy.group(2) ?? '');
 final yearRaw = int.tryParse(mmddyy.group(3) ?? '');
 if (month != null && day != null && yearRaw != null) {
 final year = yearRaw < 100 ? 2000 + yearRaw : yearRaw;
 return DateTime(year, month, day);
 }
 }

 return null;
}

String _formatDate(DateTime? value) {
 if (value == null) return '';
 return DateFormat('yyyy-MM-dd').format(value);
}

String _normalizedDateText(String raw, {bool fallbackToToday = false}) {
 final parsed = _parseFlexibleDate(raw);
 if (parsed != null) return _formatDate(parsed);
 return fallbackToToday ? _formatDate(DateTime.now()) : '';
}

Future<DateTime?> _showQualityDatePicker(
 BuildContext context, {
 required String currentValue,
}) async {
 final now = DateTime.now();
 final firstDate = DateTime(now.year - 20);
 final lastDate = DateTime(now.year + 20);
 final parsed = _parseFlexibleDate(currentValue);
 var initialDate = parsed ?? now;
 if (initialDate.isBefore(firstDate)) initialDate = firstDate;
 if (initialDate.isAfter(lastDate)) initialDate = lastDate;

 return showDatePicker(
 context: context,
 initialDate: initialDate,
 firstDate: firstDate,
 lastDate: lastDate,
 );
}

Widget _datePickerField(
 BuildContext context, {
 required TextEditingController controller,
 required Future<void> Function() onTap,
}) {
 return VoiceTextField(
 controller: controller,
 readOnly: true,
 onTap: () => onTap(),
 decoration: _inputDecoration(context, _dateHint).copyWith(
 suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
 ),
 );
}

int? _durationDays(String start, String end) {
 final s = _parseFlexibleDate(start);
 final e = _parseFlexibleDate(end);
 if (s == null || e == null) return null;
 return e.difference(s).inDays.abs();
}

List<String> _ownerOptions(BuildContext context) {
 final data = ProjectDataHelper.getData(context);
 final options = <String>{};

 for (final role in data.projectRoles) {
 final title = role.title.trim();
 if (title.isNotEmpty) options.add(title);
 }
 for (final member in data.teamMembers) {
 final name = member.name.trim();
 if (name.isNotEmpty) options.add(name);
 }

 if (options.isEmpty) {
 return const ['Owner'];
 }

 final sorted = options.toList()..sort((a, b) => a.compareTo(b));
 return sorted;
}

String _buildQualityAiContext(ProjectDataModel data) {
  final methodology =
  ProjectDataHelper.resolvedProjectMethodology(data).name.toUpperCase();
  final location = data.orgLocation.trim();

  // Collect risk context for quality risk identification
  final riskItems = data.frontEndPlanning.riskRegisterItems;
  final riskContext = riskItems.isNotEmpty
      ? '\nTop Project Risks: ${riskItems.take(5).map((r) => "${r.riskName} (${r.impactLevel}/${r.likelihood})").join('; ')}'
      : '';
  
  // Collect opportunity context for quality opportunities
  final opportunityContext = data.frontEndPlanning.opportunityItems.isNotEmpty
      ? '\nOpportunities: ${data.frontEndPlanning.opportunityItems.take(3).map((o) => o.opportunity.isNotEmpty ? o.opportunity : 'Opportunity').join('; ')}'
      : '';
      
  // IT Considerations from Initiation phase for tech-related quality
  final itContext = data.itConsiderationsData != null 
      ? [
          if (data.itConsiderationsData!.softwareRequirements.isNotEmpty)
            'Software Requirements: ${data.itConsiderationsData!.softwareRequirements}',
          if (data.itConsiderationsData!.hardwareRequirements.isNotEmpty)
            'Hardware Requirements: ${data.itConsiderationsData!.hardwareRequirements}',
          if (data.itConsiderationsData!.networkRequirements.isNotEmpty)
            'Network Requirements: ${data.itConsiderationsData!.networkRequirements}',
        ].join('\n')
      : '';

  // Team size and structure for scaling quality activities
  final teamSize = data.teamMembers.length;
  final roleCount = data.projectRoles.length;

  return [
    'Generate a comprehensive project quality management package tailored to the current project.',
    'Use this context to recommend appropriate quality standards, metrics, and activities based on project type, scale, and risks.',
    '',
    '=== PROJECT IDENTITY ===',
    'Project Name: ${data.projectName}',
    'Solution Title: ${data.solutionTitle}',
    'Solution Description: ${data.solutionDescription}',
    'Project Objective: ${data.projectObjective}',
    'Business Case: ${data.businessCase}',
    '',
    '=== PROJECT CLASSIFICATION ===',
    'Industry / Sector: ${data.overallFramework ?? 'Not specified'}',
    'Delivery Framework: $methodology',
    'Project Location: ${location.isEmpty ? 'Not specified' : location}',
    'Team Size: $teamSize members, $roleCount defined roles',
    '',
    '=== TECHNICAL CONTEXT ===',
    'Technology Notes: ${data.frontEndPlanning.technology}',
    if (itContext.isNotEmpty) itContext,
    'Security Context: ${data.frontEndPlanning.security}',
    'Requirements Summary: ${data.frontEndPlanning.requirements}',
    '',
    '=== RISK & OPPORTUNITY CONTEXT ===',
    if (riskContext.isNotEmpty) riskContext,
    if (opportunityContext.isNotEmpty) opportunityContext,
    '',
    '=== ADDITIONAL NOTES ===',
    'General Notes: ${data.notes}',
    '',
    '=== QUALITY GENERATION GUIDELINES ===',
    'Based on the above context:',
    '- Recommend industry-appropriate quality standards (ISO 9001, ISO 25010, ISO 27001, CMMI, etc.)',
    '- Suggest relevant quality metrics based on project type and framework ($methodology)',
    '- Identify potential quality risks based on project characteristics',
    '- Propose inspection and test activities appropriate to the delivery approach',
    '- Consider team size and location when recommending QA/QC resource needs',
    '- For agile projects: include sprint-level quality gates, definition of done, continuous integration quality',
    '- For waterfall projects: include phase-gate quality reviews, milestone inspections',
    '- Include applicable regulatory/compliance requirements based on industry',
  ].join('\n');
}

Map<String, List<LaunchEntry>> _buildExecutionQualitySections(
 QualityManagementData quality,
) {
 return {
 'quality_management_plan': [
 LaunchEntry(
 title: 'Project Quality Management Plan',
 details: [
 quality.qualityPlan,
 if (quality.reviewCadence.isNotEmpty)
 'Review Cadence: ${quality.reviewCadence}',
 if (quality.escalationPath.isNotEmpty)
 'Escalation Path: ${quality.escalationPath}',
 if (quality.changeControlProcess.isNotEmpty)
 'Change Control: ${quality.changeControlProcess}',
 ].where((value) => value.trim().isNotEmpty).join('\n\n'),
 status: 'Active',
 ),
 ],
 'quality_objectives': quality.objectives
 .map(
 (objective) => LaunchEntry(
 title: objective.title,
 details: [
 'Acceptance Criteria: ${objective.acceptanceCriteria}',
 'Metric: ${objective.successMetric}',
 'Target: ${objective.targetValue}',
 'Current: ${objective.currentValue}',
 'Owner: ${objective.owner}',
 'Requirement: ${objective.linkedRequirement}',
 'WBS: ${objective.linkedWbs}',
 ].join('\n'),
 status: objective.status,
 ),
 )
 .toList(),
 'inspection_test_plan': [
 ...quality.workflowControls
 .where((control) => control.type == QualityWorkflowType.qa)
 .map(
 (control) => LaunchEntry(
 title: control.name,
 details: [
 'Method: ${control.method}',
 'Tools: ${control.tools}',
 'Checklist: ${control.checklist}',
 'Frequency: ${control.frequency}',
 'Owner: ${control.owner}',
 'Standards: ${control.standardsReference}',
 ].join('\n'),
 status: 'Inspection Control',
 ),
 ),
 ...quality.qaTaskLog.map(
 (task) => LaunchEntry(
 title: task.task,
 details: [
 'Responsible: ${task.responsible}',
 'Start: ${task.startDate}',
 'End: ${task.endDate}',
 'Comments: ${task.comments}',
 ].join('\n'),
 status: task.status.name,
 ),
 ),
 ],
 'quality_metrics_dashboard': [
 LaunchEntry(
 title: 'Quality KPI Dashboard',
 details: [
 'Defect Density: ${quality.metrics.defectDensity.value} ${quality.metrics.defectDensity.unit}'.trim(),
 'Customer Satisfaction: ${quality.metrics.customerSatisfaction.value} ${quality.metrics.customerSatisfaction.unit}'.trim(),
 'On-Time Delivery: ${quality.metrics.onTimeDelivery.value} ${quality.metrics.onTimeDelivery.unit}'.trim(),
 'Target Resolution Days: ${quality.dashboardConfig.targetTimeToResolutionDays}',
 'Manual Override: ${quality.dashboardConfig.allowManualMetricsOverride ? 'Enabled' : 'Disabled'}',
 ].join('\n'),
 status: 'Tracking',
 ),
 ],
 'quality_audit_plan': [
 ...quality.workflowControls
 .where((control) => control.type == QualityWorkflowType.qc)
 .map(
 (control) => LaunchEntry(
 title: control.name,
 details: [
 'Method: ${control.method}',
 'Frequency: ${control.frequency}',
 'Owner: ${control.owner}',
 'Checklist: ${control.checklist}',
 ].join('\n'),
 status: 'Audit Control',
 ),
 ),
 ...quality.auditPlan.map(
 (audit) => LaunchEntry(
 title: audit.title,
 details: [
 'Scope: ${audit.scope}',
 'Planned Date: ${audit.plannedDate}',
 'Completed Date: ${audit.completedDate}',
 'Owner: ${audit.owner}',
 'Findings: ${audit.findings}',
 'Notes: ${audit.notes}',
 ].join('\n'),
 status: audit.result.name,
 ),
 ),
 ],
 'nonconformance_corrective_actions': quality.correctiveActions
 .map(
 (action) => LaunchEntry(
 title: action.title,
 details: [
 'Root Cause: ${action.rootCause}',
 'Action: ${action.action}',
 'Owner: ${action.owner}',
 'Due Date: ${action.dueDate}',
 'Verification: ${action.verificationNotes}',
 ].join('\n'),
 status: action.status.name,
 ),
 )
 .toList(),
 };
}

List<ScheduleActivity> _syncQualityActivitiesToCalendar(
 ProjectDataModel data,
 QualityManagementData quality,
) {
 final updated = List<ScheduleActivity>.from(data.scheduleActivities);

 void upsertActivity({
 required String key,
 required String title,
 required String date,
 required String assignee,
 }) {
 final normalizedDate = _normalizedDateText(date);
 if (normalizedDate.isEmpty) return;
 final entry = ScheduleActivity(
 id: key,
 title: title,
 assignee: assignee,
 startDate: normalizedDate,
 dueDate: normalizedDate,
 status: 'planned',
 phase: 'execution',
 workPackageType: 'execution',
 discipline: 'Quality',
 milestone: 'Quality',
 durationDays: 1,
 );
 final index = updated.indexWhere(
 (activity) => activity.id == key || activity.title == title,
 );
 if (index == -1) {
 updated.add(entry);
 } else {
 updated[index] = entry;
 }
 }

 for (final control in quality.workflowControls) {
 upsertActivity(
 key: 'quality-control-${control.id}',
 title: 'Quality ${control.type.name.toUpperCase()} Review: ${control.name}',
 date: control.frequency,
 assignee: control.owner,
 );
 }
 for (final audit in quality.auditPlan) {
 upsertActivity(
 key: 'quality-audit-${audit.id}',
 title: 'Quality Audit: ${audit.title}',
 date: audit.plannedDate,
 assignee: audit.owner,
 );
 }
 for (final task in [...quality.qaTaskLog, ...quality.qcTaskLog]) {
 upsertActivity(
 key: 'quality-task-${task.id}',
 title: 'Quality Task: ${task.task}',
 date: task.endDate.isNotEmpty ? task.endDate : task.startDate,
 assignee: task.responsible,
 );
 }
 for (final action in quality.correctiveActions) {
 upsertActivity(
 key: 'quality-corrective-${action.id}',
 title: 'Corrective Action: ${action.title}',
 date: action.dueDate,
 assignee: action.owner,
 );
 }

 return updated;
}

List<QualityStandard> _standardsPresets(ProjectDataModel data) {
 final contextText = [
 data.projectName,
 data.solutionTitle,
 data.solutionDescription,
 data.projectObjective,
 data.businessCase,
 data.frontEndPlanning.requirements,
 data.frontEndPlanning.security,
 ].join(' ').toLowerCase();

 final presets = <QualityStandard>[
 QualityStandard(
 id: _newId(),
 name: 'ISO 9001 Process Quality Management',
 source: 'ISO 9001',
 category: 'Quality Management',
 description:
 'Document procedures, establish ownership, and run periodic quality audits.',
 applicability: 'Project-wide',
 ),
 QualityStandard(
 id: _newId(),
 name: 'Stakeholder Acceptance Criteria Governance',
 source: 'Project requirements',
 category: 'Acceptance',
 description:
 'Define measurable acceptance criteria for deliverables and approvals.',
 applicability: 'Requirements and deliverables',
 ),
 ];

 if (contextText.contains('software') ||
 contextText.contains('application') ||
 contextText.contains('api')) {
 presets.add(
 QualityStandard(
 id: _newId(),
 name: 'ISO/IEC 25010 Software Quality',
 source: 'ISO/IEC 25010',
 category: 'Software Quality',
 description:
 'Apply quality characteristics such as reliability, security, and maintainability.',
 applicability: 'Software components',
 ),
 );
 }

 if (contextText.contains('security') || contextText.contains('access')) {
 presets.add(
 QualityStandard(
 id: _newId(),
 name: 'ISO 27001 Control Evidence Readiness',
 source: 'ISO 27001',
 category: 'Security Compliance',
 description:
 'Maintain audit trail for controls, access reviews, and incident handling.',
 applicability: 'Security-sensitive workflows',
 ),
 );
 }

 if (contextText.contains('construction') ||
 contextText.contains('facility') ||
 contextText.contains('equipment')) {
 presets.add(
 QualityStandard(
 id: _newId(),
 name: 'Inspection and Test Plan (ITP) Discipline',
 source: 'Industry best practice',
 category: 'Inspection',
 description:
 'Set hold points, witness points, and inspection acceptance criteria.',
 applicability: 'Physical works and procurement',
 ),
 );
 }

 return presets;
}

Future<void> _createTrainingActivityShortcut(
 BuildContext context, {
 required String checkpoint,
 String defaultTitle = 'Quality Training Session',
}) async {
 final result = await showDialog<TrainingActivity>(
 context: context,
 builder: (_) => _TrainingShortcutDialog(defaultTitle: defaultTitle),
 );

 if (!context.mounted) return;
 if (result == null) return;

 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: checkpoint,
 showSnackbar: false,
 dataUpdater: (data) {
 final updated = List<TrainingActivity>.from(data.trainingActivities)
 ..add(result);
 return data.copyWith(trainingActivities: updated);
 },
 );

 if (context.mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Training activity created'),
 behavior: SnackBarBehavior.floating,
 backgroundColor: Color(0xFF16A34A),
 ),
 );
 }
}

class QualityManagementScreen extends StatefulWidget {
 const QualityManagementScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const QualityManagementScreen()),
 );
 }

 @override
 State<QualityManagementScreen> createState() =>
 _QualityManagementScreenState();
}

class _QualityManagementScreenState extends State<QualityManagementScreen> {
 _QualityTab _selectedTab = _QualityTab.plan;

 void _handleTabSelected(_QualityTab tab) {
 if (_selectedTab == tab) return;
 setState(() => _selectedTab = tab);
 }

 Widget _buildNavigationHint() {
 return InnerPageNavigationHint(
 pageId: 'quality_management',
 pageTitle: 'Quality Management',
 description: 'Navigate between quality management sections',
 currentSectionId: _selectedTab.name,
 onSectionTap: (sectionId) {
 final tab = _QualityTab.values.firstWhere(
 (t) => t.name == sectionId,
 orElse: () => _selectedTab,
 );
 _handleTabSelected(tab);
 },
 sections: [
 InnerPageSection(
 id: _QualityTab.plan.name,
 label: 'Quality Plan',
 icon: Icons.description_outlined,
 stepNumber: 1,
 status: _selectedTab == _QualityTab.plan
 ? InnerPageSectionStatus.current
 : InnerPageSectionStatus.available,
 ),
 InnerPageSection(
 id: _QualityTab.objectives.name,
 label: 'Objectives',
 icon: Icons.flag_outlined,
 stepNumber: 2,
 status: _selectedTab == _QualityTab.objectives
 ? InnerPageSectionStatus.current
 : InnerPageSectionStatus.available,
 ),
 InnerPageSection(
 id: _QualityTab.inspection.name,
 label: 'Inspection & Test',
 icon: Icons.verified_outlined,
 stepNumber: 3,
 status: _selectedTab == _QualityTab.inspection
 ? InnerPageSectionStatus.current
 : InnerPageSectionStatus.available,
 ),
 InnerPageSection(
 id: _QualityTab.audit.name,
 label: 'Audit & Register',
 icon: Icons.fact_check_outlined,
 stepNumber: 4,
 status: _selectedTab == _QualityTab.audit
 ? InnerPageSectionStatus.current
 : InnerPageSectionStatus.available,
 ),
  InnerPageSection(
  id: _QualityTab.metrics.name,
  label: 'Metrics',
  icon: Icons.analytics_outlined,
  stepNumber: 5,
  status: _selectedTab == _QualityTab.metrics
  ? InnerPageSectionStatus.current
  : InnerPageSectionStatus.available,
  ),
  InnerPageSection(
  id: _QualityTab.coq.name,
  label: 'Cost of Quality',
  icon: Icons.account_balance_wallet_outlined,
  stepNumber: 6,
  status: _selectedTab == _QualityTab.coq
  ? InnerPageSectionStatus.current
  : InnerPageSectionStatus.available,
  ),
  ],
  );
 }

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 final horizontalPadding = isMobile ? 16.0 : 32.0;

 // Mobile: Scaffold with drawer → full-width content
 if (isMobile) {
 return Scaffold(
 backgroundColor: Colors.white,
 drawer: MobileSidebarDrawer(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Quality Management',
 ),
 ),
 body: SafeArea(
 child: Stack(
 children: [
 SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 16),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(title: 'Quality Management', onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 // Hamburger + title row for mobile
 Row(
 children: [
 Builder(builder: (ctx) {
 return IconButton(
 icon: const Icon(Icons.menu,
 color: Color(0xFF374151)),
 onPressed: () {
 final scaffold = Scaffold.maybeOf(ctx);
 if (scaffold != null && scaffold.hasDrawer) {
 scaffold.openDrawer();
 }
 },
 tooltip: 'Open menu',
 );
 }),
 const Expanded(child: _PageHeader()),
 ],
 ),
 const SizedBox(height: 24),
 const PlanningAiNotesCard(
 title: 'Notes',
 sectionLabel: 'Quality Management',
 noteKey: 'planning_quality_management_notes',
 checkpoint: 'quality_management',
 description:
 'Summarize quality targets, assurance cadence, and control measures.',
 ),
 const SizedBox(height: 24),
 _TabStrip(
 selectedTab: _selectedTab,
 onSelected: _handleTabSelected,
 ),
 const SizedBox(height: 16),
 _buildNavigationHint(),
 const SizedBox(height: 28),
 _TabContent(selectedTab: _selectedTab),
 const SizedBox(height: 28),
 _NavigationRow(
 onBack: () => PlanningPhaseNavigation.goToPrevious(
 context,
 'quality_management',
 ),
 onNext: () => PlanningPhaseNavigation.goToNext(
 context,
 'quality_management',
 ),
 ),
 const SizedBox(height: 48),
 ],
 ),
 ),
 const KazAiChatBubble(),
 ],
 ),
 ),
 );
 }

 // Desktop/Tablet: Row with sidebar
 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Quality Management',
 ),
 ),
 Expanded(
 child: Stack(
 children: [
 SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 28),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(title: 'Quality Management', onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 const _PageHeader(),
 const SizedBox(height: 24),
 const PlanningAiNotesCard(
 title: 'Notes',
 sectionLabel: 'Quality Management',
 noteKey: 'planning_quality_management_notes',
 checkpoint: 'quality_management',
 description:
 'Summarize quality targets, assurance cadence, and control measures.',
 ),
 const SizedBox(height: 24),
 _TabStrip(
 selectedTab: _selectedTab,
 onSelected: _handleTabSelected,
 ),
 const SizedBox(height: 16),
 _buildNavigationHint(),
 const SizedBox(height: 28),
 _TabContent(selectedTab: _selectedTab),
 const SizedBox(height: 28),
 _NavigationRow(
 onBack: () => PlanningPhaseNavigation.goToPrevious(
 context,
 'quality_management',
 ),
 onNext: () => PlanningPhaseNavigation.goToNext(
 context,
 'quality_management',
 ),
 ),
 const SizedBox(height: 48),
 ],
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

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Quality Management',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_quality_management_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

class _PageHeader extends StatelessWidget {
 const _PageHeader();

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Quality Management',
 style: TextStyle(
 fontSize: 30,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 SizedBox(height: 8),
 Text(
 'Manage quality standards, objectives, QA/QC workflows, audits, and corrective actions',
 style: TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 16),
 ],
 ),
 ],
 );
 }
}

class _NavigationRow extends StatelessWidget {
 const _NavigationRow({required this.onBack, required this.onNext});

 final VoidCallback onBack;
 final VoidCallback onNext;

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 return Row(
 children: [
 Expanded(
 child: OutlinedButton.icon(
 onPressed: onBack,
 icon: const Icon(Icons.arrow_back, size: 16),
 label: Flexible(
 child: FittedBox(
 fit: BoxFit.scaleDown,
 child: Text(
 PlanningPhaseNavigation.backLabel('quality_management')),
 ),
 ),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF374151),
 side: const BorderSide(color: Color(0xFFD1D5DB)),
 padding: EdgeInsets.symmetric(
 horizontal: isMobile ? 8 : 20,
 vertical: 12,
 ),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8)),
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 flex: 2,
 child: FilledButton.icon(
 onPressed: onNext,
 icon: const Icon(Icons.arrow_forward, size: 16),
 label: Flexible(
 child: FittedBox(
 fit: BoxFit.scaleDown,
 child: Text(
 PlanningPhaseNavigation.nextLabel('quality_management')),
 ),
 ),
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFFFFC044),
 foregroundColor: const Color(0xFF111827),
 padding: EdgeInsets.symmetric(
 horizontal: isMobile ? 8 : 20,
 vertical: 12,
 ),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8)),
 ),
 ),
 ),
 ],
 );
 }
}

class _TabStrip extends StatelessWidget {
 const _TabStrip({required this.selectedTab, required this.onSelected});

 final _QualityTab selectedTab;
 final ValueChanged<_QualityTab> onSelected;

 @override
 Widget build(BuildContext context) {
 const tabs = [
 _TabData(
 label: 'Quality Plan',
 icon: Icons.description_outlined,
 tab: _QualityTab.plan,
 ),
 _TabData(
 label: 'Objectives',
 icon: Icons.flag_outlined,
 tab: _QualityTab.objectives,
 ),
 _TabData(
 label: 'Inspection & Test',
 icon: Icons.verified_outlined,
 tab: _QualityTab.inspection,
 ),
 _TabData(
 label: 'Audit & Register',
 icon: Icons.fact_check_outlined,
 tab: _QualityTab.audit,
 ),
  _TabData(
  label: 'Metrics',
  icon: Icons.analytics_outlined,
  tab: _QualityTab.metrics,
  ),
  _TabData(
  label: 'Cost of Quality',
  icon: Icons.account_balance_wallet_outlined,
  tab: _QualityTab.coq,
  ),
  ];

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 18,
 offset: const Offset(0, 12),
 ),
 ],
 ),
 child: SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: Row(
 children: [
 for (int i = 0; i < tabs.length; i++) ...[
 _TabChip(
 data: tabs[i],
 selected: tabs[i].tab == selectedTab,
 onTap: () => onSelected(tabs[i].tab),
 ),
 if (i != tabs.length - 1) const SizedBox(width: 12),
 ],
 ],
 ),
 ),
 );
 }
}

class _TabData {
 const _TabData({required this.label, required this.icon, required this.tab});

 final String label;
 final IconData icon;
 final _QualityTab tab;
}

class _TabChip extends StatelessWidget {
 const _TabChip({
 required this.data,
 required this.selected,
 required this.onTap,
 });

 final _TabData data;
 final bool selected;
 final VoidCallback onTap;

 @override
 Widget build(BuildContext context) {
 final background = selected ? const Color(0xFFFFC044) : Colors.transparent;
 final textColor =
 selected ? const Color(0xFF1A1D1F) : const Color(0xFF4B5563);

 return Material(
 color: Colors.transparent,
 child: InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(16),
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 160),
 padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
 decoration: BoxDecoration(
 color: background,
 borderRadius: BorderRadius.circular(16),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(data.icon, color: textColor, size: 18),
 const SizedBox(width: 10),
 Text(
 data.label,
 style: TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w600,
 color: textColor,
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }
}

class _TabContent extends StatelessWidget {
 const _TabContent({required this.selectedTab});

 final _QualityTab selectedTab;

 @override
 Widget build(BuildContext context) {
 switch (selectedTab) {
 case _QualityTab.plan:
 return const _QualityPlanView();
 case _QualityTab.objectives:
 return const _ObjectivesView();
 case _QualityTab.inspection:
 return const _QaTrackingView();
 case _QualityTab.audit:
 return const _QcTrackingView();
  case _QualityTab.metrics:
  return const _MetricsView();
  case _QualityTab.coq:
  return const _CoqView();
 }
 }
}

class _QualityPlanView extends StatefulWidget {
 const _QualityPlanView();

 @override
 State<_QualityPlanView> createState() => _QualityPlanViewState();
}

class _QualityPlanViewState extends State<_QualityPlanView> {
 late final TextEditingController _planController;
 late final TextEditingController _reviewCadenceController;
 late final TextEditingController _escalationPathController;
 late final TextEditingController _changeControlController;
 bool _didInit = false;
 bool _isGenerating = false;
 Timer? _saveDebounce;

 // ── Per-field history + AI state ─────────────────────────────────────
 final Map<String, List<String>> _fieldHistories = {};
 final Map<String, int> _fieldHistoryIndices = {};
 final Map<String, bool> _fieldIsAiGenerated = {};
 final Map<String, bool> _fieldIsRegenerating = {};

 static const _fieldKeys = {
 'quality_narrative': 'Quality Narrative',
 'review_cadence': 'Review Cadence',
 'escalation_path': 'Escalation Path',
 'change_control': 'Change Control Process',
 };

 void _onFieldChanged() {
 _saveDebounce?.cancel();
 _saveDebounce = Timer(const Duration(milliseconds: 300), () {
 if (mounted) _savePlan();
 });
 }

 @override
 void initState() {
 super.initState();
 ApiKeyManager.initializeApiKey();
 _planController = TextEditingController();
 _reviewCadenceController = TextEditingController();
 _escalationPathController = TextEditingController();
 _changeControlController = TextEditingController();
 }

 @override
 void didChangeDependencies() {
 super.didChangeDependencies();
 if (_didInit) return;
 final qData = _qualityData(context);
 _planController.text = qData.qualityPlan;
 _reviewCadenceController.text = qData.reviewCadence;
 _escalationPathController.text = qData.escalationPath;
 _changeControlController.text = qData.changeControlProcess;
 // Record initial values in history for undo/redo
 if (qData.qualityPlan.isNotEmpty) {
 _recordFieldHistory('quality_narrative', qData.qualityPlan);
 }
 if (qData.reviewCadence.isNotEmpty) {
 _recordFieldHistory('review_cadence', qData.reviewCadence);
 }
 if (qData.escalationPath.isNotEmpty) {
 _recordFieldHistory('escalation_path', qData.escalationPath);
 }
 if (qData.changeControlProcess.isNotEmpty) {
 _recordFieldHistory('change_control', qData.changeControlProcess);
 }
 _planController.addListener(_onFieldChanged);
 _reviewCadenceController.addListener(_onFieldChanged);
 _escalationPathController.addListener(_onFieldChanged);
 _changeControlController.addListener(_onFieldChanged);
 _didInit = true;
 }

 @override
 void dispose() {
 _saveDebounce?.cancel();
 _planController.removeListener(_onFieldChanged);
 _reviewCadenceController.removeListener(_onFieldChanged);
 _escalationPathController.removeListener(_onFieldChanged);
 _changeControlController.removeListener(_onFieldChanged);
 _planController.dispose();
 _reviewCadenceController.dispose();
 _escalationPathController.dispose();
 _changeControlController.dispose();
 super.dispose();
 }

 Future<void> _savePlan() async {
 await _updateQualityData(
 context,
 checkpoint: 'quality_management',
 successMessage: 'Quality plan saved',
 updater: (current) => current.copyWith(
 qualityPlan: _planController.text.trim(),
 reviewCadence: _reviewCadenceController.text.trim(),
 escalationPath: _escalationPathController.text.trim(),
 changeControlProcess: _changeControlController.text.trim(),
 ),
 );
 }

 // ── Field history tracking for undo/redo ─────────────────────────────
 void _recordFieldHistory(String key, String value, {bool isAi = false}) {
 final history = _fieldHistories.putIfAbsent(key, () => []);
 final index = _fieldHistoryIndices.putIfAbsent(key, () => -1);
 if (index < history.length - 1) {
 history.removeRange(index + 1, history.length);
 }
 if (history.isEmpty || history.last != value) {
 history.add(value);
 _fieldHistoryIndices[key] = history.length - 1;
 }
 if (isAi) _fieldIsAiGenerated[key] = true;
 }

 bool _canUndoField(String key) =>
 (_fieldHistoryIndices[key] ?? -1) > 0;

 bool _canRedoField(String key) {
 final idx = _fieldHistoryIndices[key] ?? -1;
 final history = _fieldHistories[key] ?? [];
 return idx >= 0 && idx < history.length - 1;
 }

 void _undoField(String key, TextEditingController controller) {
 if (!_canUndoField(key)) return;
 final idx = _fieldHistoryIndices[key]! - 1;
 _fieldHistoryIndices[key] = idx;
 controller.text = _fieldHistories[key]![idx];
 _onFieldChanged();
 }

 void _redoField(String key, TextEditingController controller) {
 if (!_canRedoField(key)) return;
 final idx = _fieldHistoryIndices[key]! + 1;
 _fieldHistoryIndices[key] = idx;
 controller.text = _fieldHistories[key]![idx];
 _onFieldChanged();
 }

 // ── Per-field AI regeneration ────────────────────────────────────────
 Future<void> _regenerateField(String key, String label) async {
 setState(() => _fieldIsRegenerating[key] = true);
 try {
 final project = ProjectDataHelper.getData(context);
 final contextText =
 ProjectDataHelper.buildFepContext(project, sectionLabel: label);
 final ai = OpenAiServiceSecure();
 final result = await ai.generateCompletion(
 'Based on this project context, regenerate the "$label" section.\n\n'
 'Context:\n$contextText\n\n'
 'Provide 2-3 sentences of specific, actionable recommendations. '
 'Return ONLY the text content (no JSON, no markdown headers).',
 maxTokens: 300,
 temperature: 0.6,
 );
 final cleaned = result.trim();
 if (cleaned.isNotEmpty) {
 final controller = _controllerForKey(key);
 controller.text = cleaned;
 _recordFieldHistory(key, cleaned, isAi: true);
 _onFieldChanged();
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('AI regeneration failed: $e')),
 );
 }
 }
 if (mounted) setState(() => _fieldIsRegenerating[key] = false);
 }

 TextEditingController _controllerForKey(String key) {
 switch (key) {
 case 'quality_narrative':
 return _planController;
 case 'review_cadence':
 return _reviewCadenceController;
 case 'escalation_path':
 return _escalationPathController;
 case 'change_control':
 return _changeControlController;
 default:
 return _planController;
 }
 }

 // ── Build a field with KAZ AI + clear + formatting toolbar ───────────
 Widget _buildEnhancedField({
 required String key,
 required String label,
 required TextEditingController controller,
 required String hint,
 int minLines = 3,
 int maxLines = 6,
 }) {
 final isAiGenerated = _fieldIsAiGenerated[key] ?? false;

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // ── Label row with AI badge ──────────────────────────────
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 _FieldLabel(label),
 if (isAiGenerated)
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7E6),
 borderRadius: BorderRadius.circular(6),
 ),
 child: const Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.auto_awesome,
 size: 10, color: Color(0xFFD97706)),
 SizedBox(width: 3),
 Text('AI',
 style: TextStyle(
 fontSize: 9,
 fontWeight: FontWeight.w700,
 color: Color(0xFFD97706))),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 6),

 // ── VoiceTextField (already includes TextFormattingToolbar +
 //    KAZ AI button + Clear button + mic + docx import) ──
 VoiceTextField(
 controller: controller,
 minLines: minLines,
 maxLines: maxLines,
 kazAiLabel: label,
 onChanged: (value) {
 _recordFieldHistory(key, value);
 _onFieldChanged();
 setState(() {});
 },
 decoration: _inputDecoration(context, hint),
 ),
 ],
 );
 }

 Future<void> _generateFromContext() async {
 if (_isGenerating) return;
 if (!mounted) return;
 setState(() => _isGenerating = true);

 try {
 final project = ProjectDataHelper.getData(context);
 final contextText = _buildQualityAiContext(project);

 final ai = OpenAiServiceSecure();
 final seed = await ai.generateQualitySeedBundle(
 context: contextText,
 section: 'Quality Management',
 );

 final narrative = _composeNarrative(seed);
 _planController.text = narrative;

 if (!mounted) return;
 await _updateQualityData(
 context,
 checkpoint: 'quality_management',
 successMessage: 'Quality planning data generated',
 updater: (current) => current.copyWith(
 qualityPlan: narrative,
 standards:
 seed.standards.isNotEmpty ? seed.standards : current.standards,
 objectives:
 seed.objectives.isNotEmpty ? seed.objectives : current.objectives,
 workflowControls: seed.workflowControls.isNotEmpty
 ? seed.workflowControls
 : current.workflowControls,
 auditPlan:
 seed.auditPlan.isNotEmpty ? seed.auditPlan : current.auditPlan,
 dashboardConfig: seed.dashboardConfig,
 ),
 );
 } catch (error) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Unable to generate seed: $error'),
 behavior: SnackBarBehavior.floating,
 backgroundColor: const Color(0xFFDC2626),
 ),
 );
 } finally {
 if (mounted) setState(() => _isGenerating = false);
 }
 }

 String _composeNarrative(QualitySeedBundle seed) {
 final lines = <String>[
 'Quality objectives and controls are defined for planning, delivery, and acceptance.',
 '',
 ];

 if (seed.objectives.isNotEmpty) {
 lines.add('Key Objectives:');
 for (final objective in seed.objectives.take(6)) {
 lines.add('- ${objective.title}: ${objective.acceptanceCriteria}');
 }
 lines.add('');
 }

 if (seed.workflowControls.isNotEmpty) {
 lines.add('QA/QC Controls:');
 for (final control in seed.workflowControls.take(6)) {
 final kind = control.type == QualityWorkflowType.qa ? 'QA' : 'QC';
 lines.add('- [$kind] ${control.name} (${control.frequency})');
 }
 lines.add('');
 }

 if (seed.standards.isNotEmpty) {
 lines.add('Standards and References:');
 for (final standard in seed.standards.take(6)) {
 final source = standard.source.isEmpty ? 'Source TBD' : standard.source;
 lines.add('- ${standard.name} ($source)');
 }
 }

 return lines.join('\n').trim();
 }

 Future<void> _applyPresetStandards() async {
 final project = ProjectDataHelper.getData(context);
 final presets = _standardsPresets(project);

 await _updateQualityData(
 context,
 checkpoint: 'quality_management',
 successMessage: 'Standards presets applied',
 updater: (current) {
 final byName = <String, QualityStandard>{
 for (final standard in current.standards)
 standard.name.trim().toLowerCase(): standard,
 };
 for (final preset in presets) {
 byName[preset.name.trim().toLowerCase()] = preset;
 }
 return current.copyWith(standards: byName.values.toList());
 },
 );
 }

 Future<void> _syncToExecutionTracking() async {
 final project = ProjectDataHelper.getData(context);
 final projectId = project.projectId;
 if (projectId == null || projectId.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Project must be saved before syncing execution tracking.'),
 ),
 );
 return;
 }

 final quality = _qualityData(context);
 await ExecutionPhaseService.savePageData(
 projectId: projectId,
 pageKey: 'execution_quality_tracking',
 sections: _buildExecutionQualitySections(quality),
 );

 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'quality_management',
 showSnackbar: false,
 dataUpdater: (data) => data.copyWith(
 scheduleActivities: _syncQualityActivitiesToCalendar(data, quality),
 ),
 );

 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Execution quality tracking synced and calendar reminders created.',
 ),
 ),
 );
 }

 Future<void> _addStandard() async {
 final result = await showDialog<QualityStandard>(
 context: context,
 builder: (_) => const _QualityStandardDialog(),
 );
 if (!mounted) return;
 if (result == null) return;

 await _updateQualityData(
 context,
 checkpoint: 'quality_management',
 successMessage: 'Standard added',
 updater: (current) {
 final updated = List<QualityStandard>.from(current.standards)
 ..add(result);
 return current.copyWith(standards: updated);
 },
 );
 }

 Future<void> _editStandard(int index) async {
 final standards = _qualityData(context).standards;
 if (index < 0 || index >= standards.length) return;

 final result = await showDialog<QualityStandard>(
 context: context,
 builder: (_) => _QualityStandardDialog(initialValue: standards[index]),
 );
 if (!mounted) return;
 if (result == null) return;

 await _updateQualityData(
 context,
 checkpoint: 'quality_management',
 successMessage: 'Standard updated',
 updater: (current) {
 final updated = List<QualityStandard>.from(current.standards);
 updated[index] = result;
 return current.copyWith(standards: updated);
 },
 );
 }

  Future<void> _removeStandard(int index) async {
  final confirmed = await showDeleteConfirmationDialog(
  context,
  title: 'Remove Standard',
  );
  if (!confirmed) return;
  await _updateQualityData(
  context,
  checkpoint: 'quality_management',
  successMessage: 'Standard removed',
  updater: (current) {
  final updated = List<QualityStandard>.from(current.standards);
  if (index >= 0 && index < updated.length) {
  updated.removeAt(index);
  }
  return current.copyWith(standards: updated);
  },
  );
  }

 Future<void> _addChangeLog() async {
 final result = await showDialog<QualityChangeEntry>(
 context: context,
 builder: (_) => const _QualityChangeDialog(),
 );
 if (!mounted) return;
 if (result == null) return;

 await _updateQualityData(
 context,
 checkpoint: 'quality_management',
 successMessage: 'Change log entry added',
 updater: (current) {
 final updated = List<QualityChangeEntry>.from(current.qualityChangeLog)
 ..add(result);
 return current.copyWith(qualityChangeLog: updated);
 },
 );
 }

 Future<void> _editChangeLog(int index) async {
 final entries = _qualityData(context).qualityChangeLog;
 if (index < 0 || index >= entries.length) return;

 final result = await showDialog<QualityChangeEntry>(
 context: context,
 builder: (_) => _QualityChangeDialog(initialValue: entries[index]),
 );
 if (!mounted) return;
 if (result == null) return;

 await _updateQualityData(
 context,
 checkpoint: 'quality_management',
 successMessage: 'Change log entry updated',
 updater: (current) {
 final updated = List<QualityChangeEntry>.from(current.qualityChangeLog);
 updated[index] = result;
 return current.copyWith(qualityChangeLog: updated);
 },
 );
 }

  Future<void> _removeChangeLog(int index) async {
  final confirmed = await showDeleteConfirmationDialog(
  context,
  title: 'Remove Change Log Entry',
  );
  if (!confirmed) return;
  await _updateQualityData(
  context,
  checkpoint: 'quality_management',
  successMessage: 'Change log entry removed',
  updater: (current) {
  final updated = List<QualityChangeEntry>.from(current.qualityChangeLog);
  if (index >= 0 && index < updated.length) {
  updated.removeAt(index);
  }
  return current.copyWith(qualityChangeLog: updated);
  },
  );
  }

 @override
 Widget build(BuildContext context) {
 final quality = _qualityData(context, listen: true);

 return _PrimaryCard(
 icon: Icons.description_outlined,
 iconBackground: const Color(0xFFFFF7E6),
 iconColor: const Color(0xFFD97706),
 title: 'Quality Plan',
 subtitle:
 'Project Quality Management Plan with AI-generated standards, controls, and governance based on project context.',
 actions: [
 ElevatedButton.icon(
 onPressed: _isGenerating ? null : _generateFromContext,
 icon: _isGenerating
 ? const SizedBox(
 width: 16,
 height: 16,
 child: CircularProgressIndicator(strokeWidth: 2),
 )
 : const Icon(Icons.auto_awesome),
 label: const Text('Generate from Context'),
 style: ElevatedButton.styleFrom(
  backgroundColor: const Color(0xFFFFC812),
  foregroundColor: Colors.white,
  elevation: 0,
  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 ),
 OutlinedButton.icon(
 onPressed: _applyPresetStandards,
 icon: const Icon(Icons.tune),
 label: const Text('Apply Presets'),
 ),
 OutlinedButton.icon(
 onPressed: _syncToExecutionTracking,
 icon: const Icon(Icons.sync_outlined),
 label: const Text('Sync to Execution'),
 ),
 ElevatedButton.icon(
 onPressed: _savePlan,
 icon: const Icon(Icons.save_outlined),
 label: const Text('Save Plan'),
 style: ElevatedButton.styleFrom(
 backgroundColor: Theme.of(context).colorScheme.primary,
 foregroundColor: Colors.white,
 elevation: 0,
 ),
 ),
 ],
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildEnhancedField(
 key: 'quality_narrative',
 label: 'Quality Narrative',
 controller: _planController,
 hint:
 'Describe goals, assurance methods, control steps, and KPI governance.',
 minLines: 5,
 maxLines: 10,
 ),
 const SizedBox(height: 18),
 Row(
 children: [
 Expanded(
 child: _buildEnhancedField(
 key: 'review_cadence',
 label: 'Review Cadence',
 controller: _reviewCadenceController,
 hint: 'e.g. Weekly QA review, monthly management audit',
 minLines: 2,
 maxLines: 4,
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: _buildEnhancedField(
 key: 'escalation_path',
 label: 'Escalation Path',
 controller: _escalationPathController,
 hint: 'e.g. QA Lead -> PM -> Sponsor',
 minLines: 2,
 maxLines: 4,
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 _buildEnhancedField(
 key: 'change_control',
 label: 'Change Control Process',
 controller: _changeControlController,
 hint:
 'Document approval and communication process for quality plan changes.',
 minLines: 2,
 maxLines: 4,
 ),
 const SizedBox(height: 24),
 _SectionHeader(
 title: 'Applicable Standards',
 subtitle:
 'Capture industry and project-specific standards that drive quality controls.',
 trailing: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 OutlinedButton.icon(
 onPressed: () async {
 final rows = await showCsvImportDialog(context, tableTitle: 'Quality Standards', columns: [
 CsvColumnSpec(key: 'name', label: 'Standard Name', sampleValue: 'ISO 9001'),
 CsvColumnSpec(key: 'source', label: 'Source', sampleValue: 'ISO'),
 CsvColumnSpec(key: 'category', label: 'Category', sampleValue: 'Quality'),
 ]);
 if (rows == null || !mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${rows.length} standards imported from CSV'), backgroundColor: Colors.green));
 },
 icon: const Icon(Icons.upload_file_outlined, size: 16),
 label: const Text('Import CSV'),
  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), foregroundColor: const Color(0xFFFFC812), side: const BorderSide(color: Color(0xFFFDE68A))),
 ),
 const SizedBox(width: 8),
 ElevatedButton.icon(
 onPressed: _addStandard,
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add Standard'),
 ),
 ],
 ),
 ),
 const SizedBox(height: 12),
 _StandardsTable(
 standards: quality.standards,
 onEdit: _editStandard,
 onRemove: _removeStandard,
 ),
 const SizedBox(height: 24),
 _SectionHeader(
 title: 'Quality Change Log',
 subtitle:
 'Track post-approval quality plan updates and decision trail.',
 trailing: ElevatedButton.icon(
 onPressed: _addChangeLog,
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add Change'),
 ),
 ),
 const SizedBox(height: 12),
 _QualityChangeLogTable(
 entries: quality.qualityChangeLog,
 onEdit: _editChangeLog,
 onRemove: _removeChangeLog,
 ),
 ],
 ),
 );
 }
}

class _ObjectivesView extends StatefulWidget {
 const _ObjectivesView();

 @override
 State<_ObjectivesView> createState() => _ObjectivesViewState();
}

class _ObjectivesViewState extends State<_ObjectivesView> {
 Future<void> _addObjective() async {
 final result = await showDialog<QualityObjective>(
 context: context,
 builder: (_) =>
 _QualityObjectiveDialog(ownerOptions: _ownerOptions(context)),
 );
 if (!mounted) return;
 if (result == null) return;

 await _updateQualityData(
 context,
 checkpoint: 'quality_management',
 successMessage: 'Objective added',
 updater: (current) {
 final updated = List<QualityObjective>.from(current.objectives)
 ..add(result);
 return current.copyWith(objectives: updated);
 },
 );
 }

 Future<void> _editObjective(int index) async {
 final objectives = _qualityData(context).objectives;
 if (index < 0 || index >= objectives.length) return;

 final result = await showDialog<QualityObjective>(
 context: context,
 builder: (_) => _QualityObjectiveDialog(
 ownerOptions: _ownerOptions(context),
 initialValue: objectives[index],
 ),
 );
 if (!mounted) return;
 if (result == null) return;

 await _updateQualityData(
 context,
 checkpoint: 'quality_management',
 successMessage: 'Objective updated',
 updater: (current) {
 final updated = List<QualityObjective>.from(current.objectives);
 updated[index] = result;
 return current.copyWith(objectives: updated);
 },
 );
 }

  Future<void> _removeObjective(int index) async {
  final confirmed = await showDeleteConfirmationDialog(
  context,
  title: 'Remove Objective',
  );
  if (!confirmed) return;
  await _updateQualityData(
  context,
  checkpoint: 'quality_management',
  successMessage: 'Objective removed',
  updater: (current) {
  final updated = List<QualityObjective>.from(current.objectives);
  if (index >= 0 && index < updated.length) updated.removeAt(index);
  return current.copyWith(objectives: updated);
  },
  );
  }

 @override
 Widget build(BuildContext context) {
 final objectives = _qualityData(context, listen: true).objectives;

 return _PrimaryCard(
 icon: Icons.flag_outlined,
 iconBackground: const Color(0xFFF3F4FF),
 iconColor: const Color(0xFF7C3AED),
 title: 'Quality Objectives & Acceptance Criteria',
 subtitle:
 'Define measurable objectives, acceptance criteria, and linked requirements/WBS references.',
 actions: [
 ElevatedButton.icon(
 onPressed: _addObjective,
 icon: const Icon(Icons.add),
 label: const Text('Add Objective'),
 style: ElevatedButton.styleFrom(
 backgroundColor: Theme.of(context).colorScheme.primary,
 foregroundColor: Colors.white,
 elevation: 0,
 ),
 ),
 ],
 child: _ObjectivesTable(
 objectives: objectives,
 onEdit: _editObjective,
 onRemove: _removeObjective,
 ),
 );
 }
}

class _QaTrackingView extends StatefulWidget {
 const _QaTrackingView();

 @override
 State<_QaTrackingView> createState() => _QaTrackingViewState();
}

class _QaTrackingViewState extends State<_QaTrackingView> {
 Future<void> _addWorkflowControl() async {
 final result = await showDialog<QualityWorkflowControl>(
 context: context,
 builder: (_) => _WorkflowControlDialog(
 initialType: QualityWorkflowType.qa,
 ownerOptions: _ownerOptions(context),
 ),
 );
 if (!mounted) return;
 if (result == null) return;

 await _updateQualityData(
 context,
 checkpoint: 'quality_management',
 successMessage: 'QA control added',
 updater: (current) {
 final updated =
 List<QualityWorkflowControl>.from(current.workflowControls)
 ..add(result);
 return current.copyWith(workflowControls: updated);
 },
 );
 }

 Future<void> _editWorkflowControl(QualityWorkflowControl control) async {
 final result = await showDialog<QualityWorkflowControl>(
 context: context,
 builder: (_) => _WorkflowControlDialog(
 initialType: control.type,
 ownerOptions: _ownerOptions(context),
 initialValue: control,
 ),
 );
 if (!mounted) return;
 if (result == null) return;

 await _updateQualityData(
 context,
 checkpoint: 'quality_management',
 successMessage: 'QA control updated',
 updater: (current) {
 final updated =
 List<QualityWorkflowControl>.from(current.workflowControls);
 final index = updated.indexWhere((e) => e.id == control.id);
 if (index != -1) updated[index] = result;
 return current.copyWith(workflowControls: updated);
 },
 );
 }

  Future<void> _removeWorkflowControl(QualityWorkflowControl control) async {
  final confirmed = await showDeleteConfirmationDialog(
  context,
  title: 'Remove QA Control',
  itemLabel: control.name,
  );
  if (!confirmed) return;
  await _updateQualityData(
  context,
  checkpoint: 'quality_management',
  successMessage: 'QA control removed',
  updater: (current) {
  final updated =
  List<QualityWorkflowControl>.from(current.workflowControls)
  ..removeWhere((e) => e.id == control.id);
  return current.copyWith(workflowControls: updated);
  },
  );
  }

 Future<void> _addTask() async {
 final result = await showDialog<QualityTaskEntry>(
 context: context,
 builder: (_) => _QualityTaskDialog(ownerOptions: _ownerOptions(context)),
 );
 if (!mounted) return;
 if (result == null) return;

 await _updateQualityData(
 context,
 checkpoint: 'quality_management',
 successMessage: 'QA task added',
 updater: (current) {
 final updated = List<QualityTaskEntry>.from(current.qaTaskLog)
 ..add(result);
 return current.copyWith(qaTaskLog: updated);
 },
 );
 }

 Future<void> _editTask(QualityTaskEntry task) async {
 final result = await showDialog<QualityTaskEntry>(
 context: context,
 builder: (_) => _QualityTaskDialog(
 ownerOptions: _ownerOptions(context),
 initialValue: task,
 ),
 );
 if (!mounted) return;
 if (result == null) return;

 await _updateQualityData(
 context,
 checkpoint: 'quality_management',
 successMessage: 'QA task updated',
 updater: (current) {
 final updated = List<QualityTaskEntry>.from(current.qaTaskLog);
 final index = updated.indexWhere((e) => e.id == task.id);
 if (index != -1) updated[index] = result;
 return current.copyWith(qaTaskLog: updated);
 },
 );
 }

  Future<void> _removeTask(QualityTaskEntry task) async {
  final confirmed = await showDeleteConfirmationDialog(
  context,
  title: 'Remove QA Task',
  itemLabel: task.task,
  );
  if (!confirmed) return;
  await _updateQualityData(
  context,
  checkpoint: 'quality_management',
  successMessage: 'QA task removed',
  updater: (current) {
  final updated = List<QualityTaskEntry>.from(current.qaTaskLog)
  ..removeWhere((e) => e.id == task.id);
  return current.copyWith(qaTaskLog: updated);
  },
  );
  }

 @override
 Widget build(BuildContext context) {
 final quality = _qualityData(context, listen: true);
 final controls = quality.workflowControls
 .where((e) => e.type == QualityWorkflowType.qa)
 .toList();

 return _PrimaryCard(
 icon: Icons.verified_outlined,
 iconBackground: const Color(0xFFF3F4FF),
 iconColor: const Color(0xFF7C3AED),
 title: 'Inspection & Test Plan',
 subtitle:
 'Track quality assurance controls and task execution with owners, cadence, and completion metrics.',
 actions: [
 ElevatedButton.icon(
 onPressed: _addWorkflowControl,
 icon: const Icon(Icons.add),
 label: const Text('Add QA Control'),
 ),
 ElevatedButton.icon(
 onPressed: _addTask,
 icon: const Icon(Icons.playlist_add),
 label: const Text('Add QA Task'),
 ),
 OutlinedButton.icon(
 onPressed: () => _createTrainingActivityShortcut(
 context,
 checkpoint: 'quality_management',
 defaultTitle: 'QA Process Training',
 ),
 icon: const Icon(Icons.school_outlined),
 label: const Text('Create Training'),
 ),
 ],
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _SectionHeader(
 title: 'QA Workflow Controls',
 subtitle:
 'Methods, tools, checklists, and frequency used to prevent defects.',
 ),
 const SizedBox(height: 12),
 _WorkflowControlsTable(
 controls: controls,
 onEdit: _editWorkflowControl,
 onRemove: _removeWorkflowControl,
 ),
 const SizedBox(height: 24),
 _SectionHeader(
 title: 'QA Task Log',
 subtitle:
 'CSV-style tracking for QA activities, ownership, dates, status, and priority.',
 ),
 const SizedBox(height: 12),
 _TaskLogTable(
 tasks: quality.qaTaskLog,
 onEdit: _editTask,
 onRemove: _removeTask,
 ),
 ],
 ),
 );
 }
}

class _QcTrackingView extends StatefulWidget {
 const _QcTrackingView();

 @override
 State<_QcTrackingView> createState() => _QcTrackingViewState();
}

class _QcTrackingViewState extends State<_QcTrackingView> {
 Future<void> _addWorkflowControl() async {
 final result = await showDialog<QualityWorkflowControl>(
 context: context,
 builder: (_) => _WorkflowControlDialog(
 initialType: QualityWorkflowType.qc,
 ownerOptions: _ownerOptions(context),
 ),
 );
 if (!mounted) return;
 if (result == null) return;

 await _updateQualityData(
 context,
 checkpoint: 'quality_management',
 successMessage: 'QC control added',
 updater: (current) {
 final updated =
 List<QualityWorkflowControl>.from(current.workflowControls)
 ..add(result);
 return current.copyWith(workflowControls: updated);
 },
 );
 }

 Future<void> _editWorkflowControl(QualityWorkflowControl control) async {
 final result = await showDialog<QualityWorkflowControl>(
 context: context,
 builder: (_) => _WorkflowControlDialog(
 initialType: control.type,
 ownerOptions: _ownerOptions(context),
 initialValue: control,
 ),
 );
 if (!mounted) return;
 if (result == null) return;

 await _updateQualityData(
 context,
 checkpoint: 'quality_management',
 successMessage: 'QC control updated',
 updater: (current) {
 final updated =
 List<QualityWorkflowControl>.from(current.workflowControls);
 final index = updated.indexWhere((e) => e.id == control.id);
 if (index != -1) updated[index] = result;
 return current.copyWith(workflowControls: updated);
 },
 );
 }

  Future<void> _removeWorkflowControl(QualityWorkflowControl control) async {
  final confirmed = await showDeleteConfirmationDialog(
  context,
  title: 'Remove QC Control',
  itemLabel: control.name,
  );
  if (!confirmed) return;
  await _updateQualityData(
  context,
  checkpoint: 'quality_management',
  successMessage: 'QC control removed',
 updater: (current) {
 final updated =
 List<QualityWorkflowControl>.from(current.workflowControls)
 ..removeWhere((e) => e.id == control.id);
 return current.copyWith(workflowControls: updated);
 },
 );
 }

 Future<void> _addTask() async {
 final result = await showDialog<QualityTaskEntry>(
 context: context,
 builder: (_) => _QualityTaskDialog(ownerOptions: _ownerOptions(context)),
 );
 if (!mounted) return;
 if (result == null) return;

 await _updateQualityData(
 context,
 checkpoint: 'quality_management',
 successMessage: 'QC task added',
 updater: (current) {
 final updated = List<QualityTaskEntry>.from(current.qcTaskLog)
 ..add(result);
 return current.copyWith(qcTaskLog: updated);
 },
 );
 }

 Future<void> _editTask(QualityTaskEntry task) async {
 final result = await showDialog<QualityTaskEntry>(
 context: context,
 builder: (_) => _QualityTaskDialog(
 ownerOptions: _ownerOptions(context),
 initialValue: task,
 ),
 );
 if (!mounted) return;
 if (result == null) return;

 await _updateQualityData(
 context,
 checkpoint: 'quality_management',
 successMessage: 'QC task updated',
 updater: (current) {
 final updated = List<QualityTaskEntry>.from(current.qcTaskLog);
 final index = updated.indexWhere((e) => e.id == task.id);
 if (index != -1) updated[index] = result;
 return current.copyWith(qcTaskLog: updated);
 },
 );
 }

  Future<void> _removeTask(QualityTaskEntry task) async {
  final confirmed = await showDeleteConfirmationDialog(
  context,
  title: 'Remove QC Task',
  itemLabel: task.task,
  );
  if (!confirmed) return;
  await _updateQualityData(
  context,
  checkpoint: 'quality_management',
  successMessage: 'QC task removed',
 updater: (current) {
 final updated = List<QualityTaskEntry>.from(current.qcTaskLog)
 ..removeWhere((e) => e.id == task.id);
 return current.copyWith(qcTaskLog: updated);
 },
 );
 }

 Future<void> _addAudit() async {
 final result = await showDialog<QualityAuditEntry>(
 context: context,
 builder: (_) => _QualityAuditDialog(ownerOptions: _ownerOptions(context)),
 );
 if (!mounted) return;
 if (result == null) return;

 await _updateQualityData(
 context,
 checkpoint: 'quality_management',
 successMessage: 'Audit entry added',
 updater: (current) {
 final updated = List<QualityAuditEntry>.from(current.auditPlan)
 ..add(result);
 return current.copyWith(auditPlan: updated);
 },
 );
 }

 Future<void> _editAudit(QualityAuditEntry audit) async {
 final result = await showDialog<QualityAuditEntry>(
 context: context,
 builder: (_) => _QualityAuditDialog(
 ownerOptions: _ownerOptions(context),
 initialValue: audit,
 ),
 );
 if (!mounted) return;
 if (result == null) return;

 await _updateQualityData(
 context,
 checkpoint: 'quality_management',
 successMessage: 'Audit entry updated',
 updater: (current) {
 final updated = List<QualityAuditEntry>.from(current.auditPlan);
 final index = updated.indexWhere((e) => e.id == audit.id);
 if (index != -1) updated[index] = result;
 return current.copyWith(auditPlan: updated);
 },
 );
 }

  Future<void> _removeAudit(QualityAuditEntry audit) async {
  final confirmed = await showDeleteConfirmationDialog(
  context,
  title: 'Remove Audit Entry',
  itemLabel: audit.title,
  );
  if (!confirmed) return;
  await _updateQualityData(
  context,
  checkpoint: 'quality_management',
  successMessage: 'Audit entry removed',
 updater: (current) {
 final updated = List<QualityAuditEntry>.from(current.auditPlan)
 ..removeWhere((e) => e.id == audit.id);
 return current.copyWith(auditPlan: updated);
 },
 );
 }

 Future<void> _createCorrectiveAction(QualityAuditEntry audit) async {
 final result = await showDialog<CorrectiveActionEntry>(
 context: context,
 builder: (_) => _CorrectiveActionDialog(
 ownerOptions: _ownerOptions(context),
 initialValue: CorrectiveActionEntry.empty().copyWith(
 auditEntryId: audit.id,
 title: 'Corrective action for ${audit.title}',
 ),
 ),
 );
 if (!mounted) return;
 if (result == null) return;

 await _updateQualityData(
 context,
 checkpoint: 'quality_management',
 successMessage: 'Corrective action created',
 updater: (current) {
 final updated =
 List<CorrectiveActionEntry>.from(current.correctiveActions)
 ..add(result);
 return current.copyWith(correctiveActions: updated);
 },
 );
 }

 Future<void> _editCorrectiveAction(CorrectiveActionEntry entry) async {
 final result = await showDialog<CorrectiveActionEntry>(
 context: context,
 builder: (_) => _CorrectiveActionDialog(
 ownerOptions: _ownerOptions(context),
 initialValue: entry,
 ),
 );
 if (!mounted) return;
 if (result == null) return;

 await _updateQualityData(
 context,
 checkpoint: 'quality_management',
 successMessage: 'Corrective action updated',
 updater: (current) {
 final updated =
 List<CorrectiveActionEntry>.from(current.correctiveActions);
 final index = updated.indexWhere((e) => e.id == entry.id);
 if (index != -1) updated[index] = result;
 return current.copyWith(correctiveActions: updated);
 },
 );
 }

  Future<void> _removeCorrectiveAction(CorrectiveActionEntry entry) async {
  final confirmed = await showDeleteConfirmationDialog(
  context,
  title: 'Remove Corrective Action',
  itemLabel: entry.title,
  );
  if (!confirmed) return;
  await _updateQualityData(
  context,
  checkpoint: 'quality_management',
  successMessage: 'Corrective action removed',
 updater: (current) {
 final updated =
 List<CorrectiveActionEntry>.from(current.correctiveActions)
 ..removeWhere((e) => e.id == entry.id);
 return current.copyWith(correctiveActions: updated);
 },
 );
 }

 @override
 Widget build(BuildContext context) {
 final quality = _qualityData(context, listen: true);
 final controls = quality.workflowControls
 .where((e) => e.type == QualityWorkflowType.qc)
 .toList();

 return _PrimaryCard(
 icon: Icons.fact_check_outlined,
 iconBackground: const Color(0xFFF3F4FF),
 iconColor: const Color(0xFF7C3AED),
 title: 'Quality Audit Plan & Register',
 subtitle:
 'Track inspections, audit outcomes, and corrective actions with full ownership and due dates.',
 actions: [
 ElevatedButton.icon(
 onPressed: _addWorkflowControl,
 icon: const Icon(Icons.add),
 label: const Text('Add QC Control'),
 ),
 ElevatedButton.icon(
 onPressed: _addTask,
 icon: const Icon(Icons.playlist_add),
 label: const Text('Add QC Task'),
 ),
 ElevatedButton.icon(
 onPressed: _addAudit,
 icon: const Icon(Icons.fact_check_outlined),
 label: const Text('Add Audit'),
 ),
 OutlinedButton.icon(
 onPressed: () => _createTrainingActivityShortcut(
 context,
 checkpoint: 'quality_management',
 defaultTitle: 'QC Inspection Training',
 ),
 icon: const Icon(Icons.school_outlined),
 label: const Text('Create Training'),
 ),
 ],
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _SectionHeader(
 title: 'QC Workflow Controls',
 subtitle:
 'Inspection methods, checklists, and frequencies that detect defects early.',
 ),
 const SizedBox(height: 12),
 _WorkflowControlsTable(
 controls: controls,
 onEdit: _editWorkflowControl,
 onRemove: _removeWorkflowControl,
 ),
 const SizedBox(height: 24),
 _SectionHeader(
 title: 'QC Task Log',
 subtitle:
 'Track process audits, inspections, and compliance checks across deliverables.',
 ),
 const SizedBox(height: 12),
 _TaskLogTable(
 tasks: quality.qcTaskLog,
 onEdit: _editTask,
 onRemove: _removeTask,
 ),
 const SizedBox(height: 24),
 _SectionHeader(
 title: 'Audit Plan & Results',
 subtitle:
 'Run planned audits and convert failed/conditional results into corrective actions.',
 ),
 const SizedBox(height: 12),
 _AuditPlanTable(
 audits: quality.auditPlan,
 onEdit: _editAudit,
 onRemove: _removeAudit,
 onCreateCorrectiveAction: _createCorrectiveAction,
 ),
 const SizedBox(height: 24),
 _SectionHeader(
 title: 'Nonconformance & Corrective Action Log',
 subtitle:
 'Manage remediation ownership, due dates, and verification closure.',
 ),
 const SizedBox(height: 12),
 _CorrectiveActionsTable(
 actions: quality.correctiveActions,
 onEdit: _editCorrectiveAction,
 onRemove: _removeCorrectiveAction,
 ),
 ],
 ),
 );
 }
}

class _MetricsView extends StatefulWidget {
 const _MetricsView();

 @override
 State<_MetricsView> createState() => _MetricsViewState();
}

class _MetricsViewState extends State<_MetricsView> {
 Future<void> _editDashboardConfig() async {
 final quality = _qualityData(context);
 final result = await showDialog<QualityDashboardConfig>(
 context: context,
 builder: (_) =>
 _DashboardConfigDialog(initialValue: quality.dashboardConfig),
 );
 if (!mounted) return;
 if (result == null) return;

 await _updateQualityData(
 context,
 checkpoint: 'quality_management',
 successMessage: 'Dashboard config updated',
 updater: (current) => current.copyWith(dashboardConfig: result),
 );
 }

 Future<void> _editManualMetrics() async {
 final quality = _qualityData(context);
 final result = await showDialog<QualityMetrics>(
 context: context,
 builder: (_) => _MetricsEditDialog(metrics: quality.metrics),
 );
 if (!mounted) return;
 if (result == null) return;

 await _updateQualityData(
 context,
 checkpoint: 'quality_management',
 successMessage: 'Manual metrics updated',
 updater: (current) => current.copyWith(metrics: result),
 );
 }

 Future<void> _saveSnapshot() async {
 final quality = _qualityData(context);
 final computed = QualityMetricsCalculator.computeSnapshot(quality);

 await _updateQualityData(
 context,
 checkpoint: 'quality_management',
 successMessage: 'Computed snapshot saved',
 updater: (current) {
 final metrics = current.metrics.copyWith(
 defectTrendData: computed.defectTrendData,
 satisfactionTrendData: computed.satisfactionTrendData,
 );
 return current.copyWith(computedSnapshot: computed, metrics: metrics);
 },
 );
 }

 List<_RoadmapItem> _buildRoadmap(QualityManagementData quality) {
 final items = <_RoadmapItem>[];

 void addEvent({
 required String source,
 required String title,
 required String owner,
 required String status,
 required String primaryDate,
 String fallbackDate = '',
 }) {
 final parsedDate =
 _parseFlexibleDate(primaryDate) ?? _parseFlexibleDate(fallbackDate);
 if (parsedDate == null) return;

 items.add(
 _RoadmapItem(
 date: parsedDate,
 source: source,
 title: title.trim().isEmpty ? 'Untitled activity' : title.trim(),
 owner: owner.trim().isEmpty ? 'Unassigned' : owner.trim(),
 status: status.trim().isEmpty ? 'Planned' : status.trim(),
 ),
 );
 }

 for (final task in quality.qaTaskLog) {
 addEvent(
 source: 'QA Task',
 title: task.task,
 owner: task.responsible,
 status: _taskStatusLabel(task.status),
 primaryDate: task.endDate,
 fallbackDate: task.startDate,
 );
 }

 for (final task in quality.qcTaskLog) {
 addEvent(
 source: 'QC Task',
 title: task.task,
 owner: task.responsible,
 status: _taskStatusLabel(task.status),
 primaryDate: task.endDate,
 fallbackDate: task.startDate,
 );
 }

 for (final audit in quality.auditPlan) {
 addEvent(
 source: 'Audit',
 title: audit.title,
 owner: audit.owner,
 status: _auditStatusLabel(audit.result),
 primaryDate: audit.completedDate,
 fallbackDate: audit.plannedDate,
 );
 }

 for (final action in quality.correctiveActions) {
 addEvent(
 source: 'Corrective Action',
 title: action.title,
 owner: action.owner,
 status: _correctiveStatusLabel(action.status),
 primaryDate: action.dueDate,
 fallbackDate: action.closedAt,
 );
 }

 items.sort((a, b) => a.date.compareTo(b.date));
 return items;
 }

 String _taskStatusLabel(QualityTaskStatus status) {
 switch (status) {
 case QualityTaskStatus.notStarted:
 return 'Not Started';
 case QualityTaskStatus.inProgress:
 return 'In Progress';
 case QualityTaskStatus.complete:
 return 'Complete';
 case QualityTaskStatus.blocked:
 return 'Blocked';
 }
 }

 String _auditStatusLabel(AuditResultStatus status) {
 switch (status) {
 case AuditResultStatus.pass:
 return 'Pass';
 case AuditResultStatus.conditional:
 return 'Conditional';
 case AuditResultStatus.fail:
 return 'Fail';
 case AuditResultStatus.pending:
 return 'Pending';
 }
 }

 String _correctiveStatusLabel(CorrectiveActionStatus status) {
 switch (status) {
 case CorrectiveActionStatus.open:
 return 'Open';
 case CorrectiveActionStatus.inProgress:
 return 'In Progress';
 case CorrectiveActionStatus.verified:
 return 'Verified';
 case CorrectiveActionStatus.closed:
 return 'Closed';
 case CorrectiveActionStatus.overdue:
 return 'Overdue';
 }
 }

 @override
 Widget build(BuildContext context) {
 final quality = _qualityData(context, listen: true);
 final computed = QualityMetricsCalculator.computeSnapshot(quality);
 final roadmapItems = _buildRoadmap(quality);

 final statusTallies = computed.statusTallies;
 final priorityTallies = computed.priorityTallies;

 final summaryCards = [
 _MetricSummaryData(
 title: 'Avg Resolution Time',
 value: '${computed.averageTimeToResolutionDays.toStringAsFixed(2)} d',
 changeLabel:
 '${computed.targetTimeToResolutionDays.toStringAsFixed(1)} d',
 changeContext: 'target',
 trend: computed.averageTimeToResolutionDays <=
 computed.targetTimeToResolutionDays
 ? _MetricTrend.up
 : _MetricTrend.down,
 ),
 _MetricSummaryData(
 title: 'Avg Task Completion',
 value: '${computed.averageTaskCompletionPercent.toStringAsFixed(1)}%',
 changeLabel: '${quality.qaTaskLog.length + quality.qcTaskLog.length}',
 changeContext: 'tasks tracked',
 trend: computed.averageTaskCompletionPercent >= 70
 ? _MetricTrend.up
 : _MetricTrend.neutral,
 ),
 _MetricSummaryData(
 title: 'Planned Audits Completion',
 value: '${computed.plannedAuditsCompletionPercent.toStringAsFixed(1)}%',
 changeLabel: '${quality.auditPlan.length}',
 changeContext: 'audits total',
 trend: computed.plannedAuditsCompletionPercent >= 80
 ? _MetricTrend.up
 : _MetricTrend.neutral,
 ),
 _MetricSummaryData(
 title: 'Corrective Actions Open',
 value:
 '${quality.correctiveActions.where((e) => e.status == CorrectiveActionStatus.open || e.status == CorrectiveActionStatus.inProgress).length}',
 changeLabel: '${quality.correctiveActions.length}',
 changeContext: 'total actions',
 trend: quality.correctiveActions
 .where((e) =>
 e.status == CorrectiveActionStatus.open ||
 e.status == CorrectiveActionStatus.inProgress)
 .isEmpty
 ? _MetricTrend.up
 : _MetricTrend.down,
 ),
 ];

 final List<double> defectTrendPoints = computed.defectTrendData.isNotEmpty
 ? List<double>.from(computed.defectTrendData)
 : const <double>[0, 0, 0, 0, 0, 0];
 final List<double> satisfactionTrendPoints =
 computed.satisfactionTrendData.isNotEmpty
 ? List<double>.from(computed.satisfactionTrendData)
 : const <double>[0, 0, 0, 0, 0, 0];

 const trendLabels = ['M1', 'M2', 'M3', 'M4', 'M5', 'M6'];

 return _PrimaryCard(
 icon: Icons.analytics_outlined,
 iconBackground: const Color(0xFFF0F9F9),
 iconColor: const Color(0xFF0F766E),
 title: 'Quality Metrics Dashboard',
 subtitle:
 'Auto-computed KPI dashboard from QA/QC logs, audits, and corrective actions.',
 actions: [
 OutlinedButton.icon(
 onPressed: _editDashboardConfig,
 icon: const Icon(Icons.tune, size: 16),
 label: const Text('Dashboard Config'),
 ),
 if (quality.dashboardConfig.allowManualMetricsOverride)
 OutlinedButton.icon(
 onPressed: _editManualMetrics,
 icon: const Icon(Icons.edit, size: 16),
 label: const Text('Manual Override'),
 ),
 ElevatedButton.icon(
 onPressed: _saveSnapshot,
 icon: const Icon(Icons.save_outlined),
 label: const Text('Save Snapshot'),
 ),
 ],
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 LayoutBuilder(
 builder: (context, constraints) {
 final isWide = constraints.maxWidth >= 900;
 final isTablet = constraints.maxWidth >= 640;

 if (isWide) {
 return Row(
 children: [
 for (int i = 0; i < summaryCards.length; i++) ...[
 Expanded(
 child: _MetricSummaryCard(data: summaryCards[i])),
 if (i != summaryCards.length - 1)
 const SizedBox(width: 16),
 ],
 ],
 );
 }

 final itemWidth = isTablet
 ? (constraints.maxWidth - 16) / 2
 : constraints.maxWidth;
 return Wrap(
 spacing: 16,
 runSpacing: 16,
 children: [
 for (final card in summaryCards)
 SizedBox(
 width: itemWidth,
 child: _MetricSummaryCard(data: card)),
 ],
 );
 },
 ),
 const SizedBox(height: 24),
 _SectionHeader(
 title: 'Status Tallies',
 subtitle: 'Counts are auto-derived from QA/QC task logs.',
 ),
 const SizedBox(height: 10),
 Wrap(
 spacing: 10,
 runSpacing: 10,
 children: [
 _KpiPill(
 label: 'Not Started',
 value: '${statusTallies['notStarted'] ?? 0}'),
 _KpiPill(
 label: 'In Progress',
 value: '${statusTallies['inProgress'] ?? 0}'),
 _KpiPill(
 label: 'Complete',
 value: '${statusTallies['complete'] ?? 0}'),
 _KpiPill(
 label: 'Blocked', value: '${statusTallies['blocked'] ?? 0}'),
 ],
 ),
 const SizedBox(height: 16),
 _SectionHeader(
 title: 'Priority Tallies',
 subtitle: 'Counts by minimal/moderate/critical priorities.',
 ),
 const SizedBox(height: 10),
 Wrap(
 spacing: 10,
 runSpacing: 10,
 children: [
 _KpiPill(
 label: 'Minimal',
 value: '${priorityTallies['minimal'] ?? 0}'),
 _KpiPill(
 label: 'Moderate',
 value: '${priorityTallies['moderate'] ?? 0}'),
 _KpiPill(
 label: 'Critical',
 value: '${priorityTallies['critical'] ?? 0}'),
 ],
 ),
 const SizedBox(height: 24),
 LayoutBuilder(
 builder: (context, constraints) {
 final sideBySide = constraints.maxWidth >= 900;

 if (sideBySide) {
 return Row(
 children: [
 Expanded(
 child: _TrendCard(
 title: 'Defect Trend',
 subtitle: 'Failed audits + blocked tasks trend',
 lineColor: const Color(0xFF7C3AED),
 areaColor: const Color(0xFFDAD5FF),
 dataPoints: defectTrendPoints,
 labels: trendLabels,
 maxYBuffer: 1,
 ),
 ),
 const SizedBox(width: 20),
 Expanded(
 child: _TrendCard(
 title: 'Satisfaction Proxy Trend',
 subtitle: 'Completion-based satisfaction proxy',
 lineColor: const Color(0xFF16A34A),
 areaColor: const Color(0xFFCDEFD6),
 dataPoints: satisfactionTrendPoints,
 labels: trendLabels,
 maxYBuffer: 1,
 ),
 ),
 ],
 );
 }

 return Column(
 children: [
 _TrendCard(
 title: 'Defect Trend',
 subtitle: 'Failed audits + blocked tasks trend',
 lineColor: const Color(0xFF7C3AED),
 areaColor: const Color(0xFFDAD5FF),
 dataPoints: defectTrendPoints,
 labels: trendLabels,
 maxYBuffer: 1,
 ),
 const SizedBox(height: 20),
 _TrendCard(
 title: 'Satisfaction Proxy Trend',
 subtitle: 'Completion-based satisfaction proxy',
 lineColor: const Color(0xFF16A34A),
 areaColor: const Color(0xFFCDEFD6),
 dataPoints: satisfactionTrendPoints,
 labels: trendLabels,
 maxYBuffer: 1,
 ),
 ],
 );
 },
 ),
 const SizedBox(height: 24),
 _SectionHeader(
 title: 'Quality Activity Roadmap',
 subtitle:
 'Chronological view of QA/QC tasks, audits, and corrective actions.',
 ),
 const SizedBox(height: 12),
 _RoadmapTimeline(items: roadmapItems),
 ],
 ),
 );
 }
}

class _PrimaryCard extends StatelessWidget {
 const _PrimaryCard({
 required this.icon,
 required this.iconBackground,
 required this.iconColor,
 required this.title,
 required this.subtitle,
 required this.child,
 this.actions,
 });

 final IconData icon;
 final Color iconBackground;
 final Color iconColor;
 final String title;
 final String subtitle;
 final Widget child;
 final List<Widget>? actions;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(26),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.03),
 blurRadius: 20,
 offset: const Offset(0, 14),
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
 width: 44,
 height: 44,
 decoration: BoxDecoration(
 color: iconBackground,
 borderRadius: BorderRadius.circular(16),
 ),
 child: Icon(icon, color: iconColor, size: 22),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 6),
 Text(
 subtitle,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 ),
 if (actions != null) ...[
 const SizedBox(width: 20),
 Flexible(
 child: Wrap(
 spacing: 10,
 runSpacing: 10,
 alignment: WrapAlignment.end,
 children: actions!,
 ),
 ),
 ],
 ],
 ),
 const SizedBox(height: 28),
 child,
 ],
 ),
 );
 }
}

class _SectionHeader extends StatelessWidget {
 const _SectionHeader({
 required this.title,
 required this.subtitle,
 this.trailing,
 });

 final String title;
 final String subtitle;
 final Widget? trailing;

 @override
 Widget build(BuildContext context) {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 3),
 Text(
 subtitle,
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF6B7280),
 height: 1.35,
 ),
 ),
 ],
 ),
 ),
 if (trailing != null) ...[
 const SizedBox(width: 12),
 trailing!,
 ],
 ],
 );
 }
}

class _FieldLabel extends StatelessWidget {
 const _FieldLabel(this.text);

 final String text;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 6),
 child: Text(
 text,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF374151),
 ),
 ),
 );
 }
}

InputDecoration _inputDecoration(BuildContext context, String hint) {
 return InputDecoration(
 hintText: hint,
 hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
 filled: true,
 fillColor: const Color(0xFFF9FAFB),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide:
 BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
 ),
 contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 );
}

class _StandardsTable extends StatelessWidget {
 const _StandardsTable({
 required this.standards,
 required this.onEdit,
 required this.onRemove,
 });

 final List<QualityStandard> standards;
 final ValueChanged<int> onEdit;
 final ValueChanged<int> onRemove;

 @override
 Widget build(BuildContext context) {
 if (standards.isEmpty) {
 return const _EmptyState(
 message:
 'No standards defined. Add standards to ensure QA/QC controls align with requirements.',
 );
 }

 return _DataTableShell(
 table: DataTable(
 headingRowColor: WidgetStateProperty.all(const Color(0xFFF3F4F6)),
 columns: const [
 DataColumn(label: Text('Standard')),
 DataColumn(label: Text('Source')),
 DataColumn(label: Text('Category')),
 DataColumn(label: Text('Applicability')),
 DataColumn(label: Text('Actions')),
 ],
 rows: [
 for (int i = 0; i < standards.length; i++)
 DataRow(
 cells: [
 DataCell(SizedBox(width: 220, child: Text(standards[i].name))),
 DataCell(
 SizedBox(width: 140, child: Text(standards[i].source))),
 DataCell(
 SizedBox(width: 120, child: Text(standards[i].category))),
 DataCell(SizedBox(
 width: 180, child: Text(standards[i].applicability))),
 DataCell(
 Row(
 children: [
 IconButton(
 icon: const Icon(Icons.edit_outlined, size: 18),
 onPressed: () => onEdit(i),
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline, size: 18),
 color: const Color(0xFFDC2626),
 onPressed: () => onRemove(i),
 ),
 ],
 ),
 ),
 ],
 ),
 ],
 ),
 );
 }
}

class _ObjectivesTable extends StatelessWidget {
 const _ObjectivesTable({
 required this.objectives,
 required this.onEdit,
 required this.onRemove,
 });

 final List<QualityObjective> objectives;
 final ValueChanged<int> onEdit;
 final ValueChanged<int> onRemove;

 @override
 Widget build(BuildContext context) {
 if (objectives.isEmpty) {
 return const _EmptyState(
 message:
 'No objectives defined. Add measurable objectives and acceptance criteria.',
 );
 }

 return _DataTableShell(
 table: DataTable(
 headingRowColor: WidgetStateProperty.all(const Color(0xFFF3F4F6)),
 columns: const [
 DataColumn(label: Text('Objective')),
 DataColumn(label: Text('Metric')),
 DataColumn(label: Text('Target')),
 DataColumn(label: Text('Current')),
 DataColumn(label: Text('Owner')),
 DataColumn(label: Text('Status')),
 DataColumn(label: Text('Actions')),
 ],
 rows: [
 for (int i = 0; i < objectives.length; i++)
 DataRow(
 cells: [
 DataCell(
 SizedBox(width: 220, child: Text(objectives[i].title))),
 DataCell(SizedBox(
 width: 140, child: Text(objectives[i].successMetric))),
 DataCell(Text(objectives[i].targetValue)),
 DataCell(Text(objectives[i].currentValue)),
 DataCell(
 SizedBox(width: 130, child: Text(objectives[i].owner))),
 DataCell(_StatusChipText(label: objectives[i].status)),
 DataCell(Row(
 children: [
 IconButton(
 icon: const Icon(Icons.edit_outlined, size: 18),
 onPressed: () => onEdit(i),
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline, size: 18),
 color: const Color(0xFFDC2626),
 onPressed: () => onRemove(i),
 ),
 ],
 )),
 ],
 ),
 ],
 ),
 );
 }
}

class _WorkflowControlsTable extends StatelessWidget {
 const _WorkflowControlsTable({
 required this.controls,
 required this.onEdit,
 required this.onRemove,
 });

 final List<QualityWorkflowControl> controls;
 final ValueChanged<QualityWorkflowControl> onEdit;
 final ValueChanged<QualityWorkflowControl> onRemove;

 @override
 Widget build(BuildContext context) {
 if (controls.isEmpty) {
 return const _EmptyState(
 message:
 'No workflow controls defined. Add controls to enforce standardized QA/QC practice.',
 );
 }

 return _DataTableShell(
 table: DataTable(
 headingRowColor: WidgetStateProperty.all(const Color(0xFFF3F4F6)),
 columns: const [
 DataColumn(label: Text('Control')),
 DataColumn(label: Text('Method')),
 DataColumn(label: Text('Tools')),
 DataColumn(label: Text('Frequency')),
 DataColumn(label: Text('Owner')),
 DataColumn(label: Text('Standards')),
 DataColumn(label: Text('Actions')),
 ],
 rows: [
 for (final control in controls)
 DataRow(cells: [
 DataCell(SizedBox(width: 180, child: Text(control.name))),
 DataCell(SizedBox(width: 220, child: Text(control.method))),
 DataCell(SizedBox(width: 140, child: Text(control.tools))),
 DataCell(Text(control.frequency)),
 DataCell(SizedBox(width: 140, child: Text(control.owner))),
 DataCell(SizedBox(
 width: 180, child: Text(control.standardsReference))),
 DataCell(Row(
 children: [
 IconButton(
 icon: const Icon(Icons.edit_outlined, size: 18),
 onPressed: () => onEdit(control),
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline, size: 18),
 color: const Color(0xFFDC2626),
 onPressed: () => onRemove(control),
 ),
 ],
 )),
 ]),
 ],
 ),
 );
 }
}

class _TaskLogTable extends StatelessWidget {
 const _TaskLogTable({
 required this.tasks,
 required this.onEdit,
 required this.onRemove,
 });

 final List<QualityTaskEntry> tasks;
 final ValueChanged<QualityTaskEntry> onEdit;
 final ValueChanged<QualityTaskEntry> onRemove;

 String _statusLabel(QualityTaskStatus status) {
 switch (status) {
 case QualityTaskStatus.notStarted:
 return 'Not Started';
 case QualityTaskStatus.inProgress:
 return 'In Progress';
 case QualityTaskStatus.complete:
 return 'Complete';
 case QualityTaskStatus.blocked:
 return 'Blocked';
 }
 }

 String _priorityLabel(QualityTaskPriority priority) {
 switch (priority) {
 case QualityTaskPriority.minimal:
 return 'Minimal';
 case QualityTaskPriority.moderate:
 return 'Moderate';
 case QualityTaskPriority.critical:
 return 'Critical';
 }
 }

 @override
 Widget build(BuildContext context) {
 if (tasks.isEmpty) {
 return const _EmptyState(
 message:
 'No task entries yet. Add tasks to compute completion and resolution KPIs automatically.',
 );
 }

 return _DataTableShell(
 table: DataTable(
 headingRowColor: WidgetStateProperty.all(const Color(0xFFF3F4F6)),
 columns: const [
 DataColumn(label: Text('Task')),
 DataColumn(label: Text('% Complete')),
 DataColumn(label: Text('Responsible')),
 DataColumn(label: Text('Start')),
 DataColumn(label: Text('End')),
 DataColumn(label: Text('Duration')),
 DataColumn(label: Text('Status')),
 DataColumn(label: Text('Priority')),
 DataColumn(label: Text('Comments')),
 DataColumn(label: Text('Actions')),
 ],
 rows: [
 for (final task in tasks)
 DataRow(cells: [
 DataCell(SizedBox(width: 170, child: Text(task.task))),
 DataCell(Text('${task.percentComplete.toStringAsFixed(0)}%')),
 DataCell(SizedBox(width: 130, child: Text(task.responsible))),
 DataCell(Text(task.startDate)),
 DataCell(Text(task.endDate)),
 DataCell(Text(
 task.durationDays == null ? '-' : '${task.durationDays} d',
 )),
 DataCell(_StatusChipText(label: _statusLabel(task.status))),
 DataCell(_StatusChipText(label: _priorityLabel(task.priority))),
 DataCell(SizedBox(width: 200, child: Text(task.comments))),
 DataCell(Row(
 children: [
 IconButton(
 icon: const Icon(Icons.edit_outlined, size: 18),
 onPressed: () => onEdit(task),
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline, size: 18),
 color: const Color(0xFFDC2626),
 onPressed: () => onRemove(task),
 ),
 ],
 )),
 ]),
 ],
 ),
 );
 }
}

class _AuditPlanTable extends StatelessWidget {
 const _AuditPlanTable({
 required this.audits,
 required this.onEdit,
 required this.onRemove,
 required this.onCreateCorrectiveAction,
 });

 final List<QualityAuditEntry> audits;
 final ValueChanged<QualityAuditEntry> onEdit;
 final ValueChanged<QualityAuditEntry> onRemove;
 final ValueChanged<QualityAuditEntry> onCreateCorrectiveAction;

 String _resultLabel(AuditResultStatus status) {
 switch (status) {
 case AuditResultStatus.pass:
 return 'Pass';
 case AuditResultStatus.conditional:
 return 'Conditional';
 case AuditResultStatus.fail:
 return 'Fail';
 case AuditResultStatus.pending:
 return 'Pending';
 }
 }

 @override
 Widget build(BuildContext context) {
 if (audits.isEmpty) {
 return const _EmptyState(
 message:
 'No audit entries yet. Add planned audits and record outcomes.',
 );
 }

 return _DataTableShell(
 table: DataTable(
 headingRowColor: WidgetStateProperty.all(const Color(0xFFF3F4F6)),
 columns: const [
 DataColumn(label: Text('Audit')),
 DataColumn(label: Text('Scope')),
 DataColumn(label: Text('Planned')),
 DataColumn(label: Text('Completed')),
 DataColumn(label: Text('Owner')),
 DataColumn(label: Text('Result')),
 DataColumn(label: Text('Actions')),
 ],
 rows: [
 for (final audit in audits)
 DataRow(cells: [
 DataCell(SizedBox(width: 180, child: Text(audit.title))),
 DataCell(SizedBox(width: 220, child: Text(audit.scope))),
 DataCell(Text(audit.plannedDate)),
 DataCell(Text(audit.completedDate)),
 DataCell(SizedBox(width: 130, child: Text(audit.owner))),
 DataCell(_StatusChipText(label: _resultLabel(audit.result))),
 DataCell(Row(
 children: [
 if (audit.result == AuditResultStatus.fail ||
 audit.result == AuditResultStatus.conditional)
 IconButton(
 tooltip: 'Create corrective action',
 icon: const Icon(Icons.rule_folder_outlined, size: 18),
 onPressed: () => onCreateCorrectiveAction(audit),
 ),
 IconButton(
 icon: const Icon(Icons.edit_outlined, size: 18),
 onPressed: () => onEdit(audit),
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline, size: 18),
 color: const Color(0xFFDC2626),
 onPressed: () => onRemove(audit),
 ),
 ],
 )),
 ]),
 ],
 ),
 );
 }
}

class _CorrectiveActionsTable extends StatelessWidget {
 const _CorrectiveActionsTable({
 required this.actions,
 required this.onEdit,
 required this.onRemove,
 });

 final List<CorrectiveActionEntry> actions;
 final ValueChanged<CorrectiveActionEntry> onEdit;
 final ValueChanged<CorrectiveActionEntry> onRemove;

 String _statusLabel(CorrectiveActionStatus status) {
 switch (status) {
 case CorrectiveActionStatus.open:
 return 'Open';
 case CorrectiveActionStatus.inProgress:
 return 'In Progress';
 case CorrectiveActionStatus.verified:
 return 'Verified';
 case CorrectiveActionStatus.closed:
 return 'Closed';
 case CorrectiveActionStatus.overdue:
 return 'Overdue';
 }
 }

 @override
 Widget build(BuildContext context) {
 if (actions.isEmpty) {
 return const _EmptyState(
 message:
 'No corrective actions created. Failed or conditional audits should produce corrective actions.',
 );
 }

 return _DataTableShell(
 table: DataTable(
 headingRowColor: WidgetStateProperty.all(const Color(0xFFF3F4F6)),
 columns: const [
 DataColumn(label: Text('Action')),
 DataColumn(label: Text('Root Cause')),
 DataColumn(label: Text('Owner')),
 DataColumn(label: Text('Due Date')),
 DataColumn(label: Text('Status')),
 DataColumn(label: Text('Actions')),
 ],
 rows: [
 for (final entry in actions)
 DataRow(cells: [
 DataCell(SizedBox(width: 190, child: Text(entry.title))),
 DataCell(SizedBox(width: 220, child: Text(entry.rootCause))),
 DataCell(SizedBox(width: 130, child: Text(entry.owner))),
 DataCell(Text(entry.dueDate)),
 DataCell(_StatusChipText(label: _statusLabel(entry.status))),
 DataCell(Row(
 children: [
 IconButton(
 icon: const Icon(Icons.edit_outlined, size: 18),
 onPressed: () => onEdit(entry),
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline, size: 18),
 color: const Color(0xFFDC2626),
 onPressed: () => onRemove(entry),
 ),
 ],
 )),
 ]),
 ],
 ),
 );
 }
}

class _QualityChangeLogTable extends StatelessWidget {
 const _QualityChangeLogTable({
 required this.entries,
 required this.onEdit,
 required this.onRemove,
 });

 final List<QualityChangeEntry> entries;
 final ValueChanged<int> onEdit;
 final ValueChanged<int> onRemove;

 @override
 Widget build(BuildContext context) {
 if (entries.isEmpty) {
 return const _EmptyState(
 message:
 'No change log entries. Record quality plan updates and approvals after baseline.',
 );
 }

 return _DataTableShell(
 table: DataTable(
 headingRowColor: WidgetStateProperty.all(const Color(0xFFF3F4F6)),
 columns: const [
 DataColumn(label: Text('Description')),
 DataColumn(label: Text('Reason')),
 DataColumn(label: Text('Requested By')),
 DataColumn(label: Text('Approved By')),
 DataColumn(label: Text('Date')),
 DataColumn(label: Text('Status')),
 DataColumn(label: Text('Actions')),
 ],
 rows: [
 for (int i = 0; i < entries.length; i++)
 DataRow(cells: [
 DataCell(
 SizedBox(width: 220, child: Text(entries[i].description))),
 DataCell(SizedBox(width: 160, child: Text(entries[i].reason))),
 DataCell(Text(entries[i].requestedBy)),
 DataCell(Text(entries[i].approvedBy)),
 DataCell(Text(entries[i].date)),
 DataCell(_StatusChipText(label: entries[i].status)),
 DataCell(Row(
 children: [
 IconButton(
 icon: const Icon(Icons.edit_outlined, size: 18),
 onPressed: () => onEdit(i),
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline, size: 18),
 color: const Color(0xFFDC2626),
 onPressed: () => onRemove(i),
 ),
 ],
 )),
 ]),
 ],
 ),
 );
 }
}

class _EmptyState extends StatelessWidget {
 const _EmptyState({required this.message});

 final String message;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Text(
 message,
 style: const TextStyle(
 color: Color(0xFF6B7280),
 fontSize: 13,
 height: 1.4,
 ),
 textAlign: TextAlign.center,
 ),
 );
 }
}

class _DataTableShell extends StatelessWidget {
 const _DataTableShell({required this.table});

 final DataTable table;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: table,
 ),
 );
 }
}

class _StatusChipText extends StatelessWidget {
 const _StatusChipText({required this.label});

 final String label;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 label,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFF374151),
 ),
 ),
 );
 }
}

class _KpiPill extends StatelessWidget {
 const _KpiPill({required this.label, required this.value});

 final String label;
 final String value;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 borderRadius: BorderRadius.circular(999),
 ),
 child: RichText(
 text: TextSpan(
 children: [
 TextSpan(
 text: '$label: ',
 style: const TextStyle(
 color: Color(0xFF6B7280),
 fontSize: 12,
 fontWeight: FontWeight.w600,
 ),
 ),
 TextSpan(
 text: value,
 style: const TextStyle(
 color: Color(0xFF111827),
 fontSize: 12,
 fontWeight: FontWeight.w700,
 ),
 ),
 ],
 ),
 ),
 );
 }
}

class _RoadmapItem {
 const _RoadmapItem({
 required this.date,
 required this.source,
 required this.title,
 required this.owner,
 required this.status,
 });

 final DateTime date;
 final String source;
 final String title;
 final String owner;
 final String status;
}

class _RoadmapTimeline extends StatelessWidget {
 const _RoadmapTimeline({required this.items});

 final List<_RoadmapItem> items;

 Color _sourceColor(String source) {
 switch (source) {
 case 'QA Task':
 return const Color(0xFFD97706);
 case 'QC Task':
 return const Color(0xFF7C3AED);
 case 'Audit':
 return const Color(0xFFCA8A04);
 case 'Corrective Action':
 return const Color(0xFFDC2626);
 default:
 return const Color(0xFF374151);
 }
 }

 @override
 Widget build(BuildContext context) {
 if (items.isEmpty) {
 return const _EmptyState(
 message:
 'No roadmap milestones yet. Add QA/QC tasks or audits to populate the timeline.',
 );
 }

 final displayItems = items.length > 14 ? items.sublist(0, 14) : items;

 return Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 children: [
 for (int i = 0; i < displayItems.length; i++) ...[
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 SizedBox(
 width: 102,
 child: Text(
 DateFormat('yyyy-MM-dd').format(displayItems[i].date),
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFF374151),
 ),
 ),
 ),
 Container(
 width: 10,
 margin: const EdgeInsets.only(top: 2),
 child: Column(
 children: [
 Container(
 width: 8,
 height: 8,
 decoration: BoxDecoration(
 color: _sourceColor(displayItems[i].source),
 shape: BoxShape.circle,
 ),
 ),
 if (i != displayItems.length - 1)
 Container(
 width: 2,
 height: 34,
 color: const Color(0xFFE5E7EB),
 ),
 ],
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Padding(
 padding: const EdgeInsets.only(top: 1),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 displayItems[i].title,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 4),
 Wrap(
 spacing: 8,
 runSpacing: 6,
 children: [
 _StatusChipText(label: displayItems[i].source),
 _StatusChipText(label: displayItems[i].status),
 Text(
 'Owner: ${displayItems[i].owner}',
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
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
 if (i != displayItems.length - 1) const SizedBox(height: 8),
 ],
 ],
 ),
 );
 }
}

class _QualityStandardDialog extends StatefulWidget {
 const _QualityStandardDialog({this.initialValue});

 final QualityStandard? initialValue;

 @override
 State<_QualityStandardDialog> createState() => _QualityStandardDialogState();
}

class _QualityStandardDialogState extends State<_QualityStandardDialog> {
 late final TextEditingController _name;
 late final TextEditingController _source;
 late final TextEditingController _category;
 late final TextEditingController _description;
 late final TextEditingController _applicability;

 @override
 void initState() {
 super.initState();
 _name = TextEditingController(text: widget.initialValue?.name ?? '');
 _source = TextEditingController(text: widget.initialValue?.source ?? '');
 _category =
 TextEditingController(text: widget.initialValue?.category ?? '');
 _description =
 TextEditingController(text: widget.initialValue?.description ?? '');
 _applicability =
 TextEditingController(text: widget.initialValue?.applicability ?? '');
 }

 @override
 void dispose() {
 _name.dispose();
 _source.dispose();
 _category.dispose();
 _description.dispose();
 _applicability.dispose();
 super.dispose();
 }

 void _save() {
 if (_name.text.trim().isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Standard name is required')),
 );
 return;
 }

 Navigator.of(context).pop(
 QualityStandard(
 id: widget.initialValue?.id ?? _newId(),
 name: _name.text.trim(),
 source: _source.text.trim(),
 category: _category.text.trim(),
 description: _description.text.trim(),
 applicability: _applicability.text.trim(),
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 return AlertDialog(
 title:
 Text(widget.initialValue == null ? 'Add Standard' : 'Edit Standard'),
 content: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel('Name'),
 VoiceTextField(
 controller: _name, decoration: _inputDecoration(context, '')),
 const SizedBox(height: 10),
 _FieldLabel('Source'),
 VoiceTextField(
 controller: _source,
 decoration: _inputDecoration(context, 'e.g. ISO 9001')),
 const SizedBox(height: 10),
 _FieldLabel('Category'),
 VoiceTextField(
 controller: _category,
 decoration: _inputDecoration(context, '')),
 const SizedBox(height: 10),
 _FieldLabel('Description'),
 VoiceTextField(
 controller: _description,
 minLines: 2,
 maxLines: 4,
 decoration: _inputDecoration(context, ''),
 ),
 const SizedBox(height: 10),
 _FieldLabel('Applicability'),
 VoiceTextField(
 controller: _applicability,
 decoration: _inputDecoration(context, '')),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(),
 child: const Text('Cancel')),
 ElevatedButton(onPressed: _save, child: const Text('Save')),
 ],
 );
 }
}

class _QualityObjectiveDialog extends StatefulWidget {
 const _QualityObjectiveDialog({
 required this.ownerOptions,
 this.initialValue,
 });

 final List<String> ownerOptions;
 final QualityObjective? initialValue;

 @override
 State<_QualityObjectiveDialog> createState() =>
 _QualityObjectiveDialogState();
}

class _QualityObjectiveDialogState extends State<_QualityObjectiveDialog> {
 late final TextEditingController _title;
 late final TextEditingController _acceptance;
 late final TextEditingController _metric;
 late final TextEditingController _target;
 late final TextEditingController _current;
 late final TextEditingController _linkedReq;
 late final TextEditingController _linkedWbs;
 late final TextEditingController _status;
 late String _owner;

 @override
 void initState() {
 super.initState();
 final initial = widget.initialValue;
 _title = TextEditingController(text: initial?.title ?? '');
 _acceptance =
 TextEditingController(text: initial?.acceptanceCriteria ?? '');
 _metric = TextEditingController(text: initial?.successMetric ?? '');
 _target = TextEditingController(text: initial?.targetValue ?? '');
 _current = TextEditingController(text: initial?.currentValue ?? '');
 _linkedReq = TextEditingController(text: initial?.linkedRequirement ?? '');
 _linkedWbs = TextEditingController(text: initial?.linkedWbs ?? '');
 _status = TextEditingController(text: initial?.status ?? 'Draft');
 _owner = initial?.owner.isNotEmpty == true
 ? initial!.owner
 : widget.ownerOptions.first;
 }

 @override
 void dispose() {
 _title.dispose();
 _acceptance.dispose();
 _metric.dispose();
 _target.dispose();
 _current.dispose();
 _linkedReq.dispose();
 _linkedWbs.dispose();
 _status.dispose();
 super.dispose();
 }

 void _save() {
 if (_title.text.trim().isEmpty || _metric.text.trim().isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Objective title and metric are required')),
 );
 return;
 }

 Navigator.of(context).pop(
 QualityObjective(
 id: widget.initialValue?.id ?? _newId(),
 title: _title.text.trim(),
 acceptanceCriteria: _acceptance.text.trim(),
 successMetric: _metric.text.trim(),
 targetValue: _target.text.trim(),
 currentValue: _current.text.trim(),
 owner: _owner,
 linkedRequirement: _linkedReq.text.trim(),
 linkedWbs: _linkedWbs.text.trim(),
 status: _status.text.trim().isEmpty ? 'Draft' : _status.text.trim(),
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 return AlertDialog(
 title: Text(
 widget.initialValue == null ? 'Add Objective' : 'Edit Objective'),
 content: SingleChildScrollView(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 _FieldLabel('Objective'),
 VoiceTextField(
 controller: _title, decoration: _inputDecoration(context, '')),
 const SizedBox(height: 10),
 _FieldLabel('Acceptance Criteria'),
 VoiceTextField(
 controller: _acceptance,
 minLines: 2,
 maxLines: 4,
 decoration: _inputDecoration(context, ''),
 ),
 const SizedBox(height: 10),
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel('Metric'),
 VoiceTextField(
 controller: _metric,
 decoration: _inputDecoration(context, '')),
 ],
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel('Target'),
 VoiceTextField(
 controller: _target,
 decoration: _inputDecoration(context, '')),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel('Current'),
 VoiceTextField(
 controller: _current,
 decoration: _inputDecoration(context, '')),
 ],
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel('Owner'),
 DropdownButtonFormField<String>(
 value: _owner,
 decoration: _inputDecoration(context, ''),
 items: widget.ownerOptions
 .map((e) =>
 DropdownMenuItem(value: e, child: Text(e)))
 .toList(),
 onChanged: (value) {
 if (value != null) setState(() => _owner = value);
 },
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 _FieldLabel('Linked Requirement'),
 VoiceTextField(
 controller: _linkedReq,
 decoration: _inputDecoration(context, '')),
 const SizedBox(height: 10),
 _FieldLabel('Linked WBS'),
 VoiceTextField(
 controller: _linkedWbs,
 decoration: _inputDecoration(context, '')),
 const SizedBox(height: 10),
 _FieldLabel('Status'),
 VoiceTextField(
 controller: _status,
 decoration:
 _inputDecoration(context, 'Draft/On Track/Off Track')),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(),
 child: const Text('Cancel')),
 ElevatedButton(onPressed: _save, child: const Text('Save')),
 ],
 );
 }
}

class _WorkflowControlDialog extends StatefulWidget {
 const _WorkflowControlDialog({
 required this.initialType,
 required this.ownerOptions,
 this.initialValue,
 });

 final QualityWorkflowType initialType;
 final List<String> ownerOptions;
 final QualityWorkflowControl? initialValue;

 @override
 State<_WorkflowControlDialog> createState() => _WorkflowControlDialogState();
}

class _WorkflowControlDialogState extends State<_WorkflowControlDialog> {
 late final TextEditingController _name;
 late final TextEditingController _method;
 late final TextEditingController _tools;
 late final TextEditingController _checklist;
 late final TextEditingController _frequency;
 late final TextEditingController _standards;
 late String _owner;

 @override
 void initState() {
 super.initState();
 final initial = widget.initialValue;
 _name = TextEditingController(text: initial?.name ?? '');
 _method = TextEditingController(text: initial?.method ?? '');
 _tools = TextEditingController(text: initial?.tools ?? '');
 _checklist = TextEditingController(text: initial?.checklist ?? '');
 _frequency = TextEditingController(text: initial?.frequency ?? '');
 _standards = TextEditingController(text: initial?.standardsReference ?? '');
 _owner = initial?.owner.isNotEmpty == true
 ? initial!.owner
 : widget.ownerOptions.first;
 }

 @override
 void dispose() {
 _name.dispose();
 _method.dispose();
 _tools.dispose();
 _checklist.dispose();
 _frequency.dispose();
 _standards.dispose();
 super.dispose();
 }

 void _save() {
 if (_name.text.trim().isEmpty || _owner.trim().isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Control name and owner are required')),
 );
 return;
 }

 Navigator.of(context).pop(
 QualityWorkflowControl(
 id: widget.initialValue?.id ?? _newId(),
 type: widget.initialValue?.type ?? widget.initialType,
 name: _name.text.trim(),
 method: _method.text.trim(),
 tools: _tools.text.trim(),
 checklist: _checklist.text.trim(),
 frequency: _frequency.text.trim(),
 owner: _owner,
 standardsReference: _standards.text.trim(),
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 final titlePrefix =
 widget.initialType == QualityWorkflowType.qa ? 'QA' : 'QC';

 return AlertDialog(
 title: Text(widget.initialValue == null
 ? 'Add $titlePrefix Control'
 : 'Edit $titlePrefix Control'),
 content: SingleChildScrollView(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 _FieldLabel('Control Name'),
 VoiceTextField(
 controller: _name, decoration: _inputDecoration(context, '')),
 const SizedBox(height: 10),
 _FieldLabel('Method'),
 VoiceTextField(
 controller: _method,
 minLines: 2,
 maxLines: 4,
 decoration: _inputDecoration(context, ''),
 ),
 const SizedBox(height: 10),
 _FieldLabel('Tools'),
 VoiceTextField(
 controller: _tools, decoration: _inputDecoration(context, '')),
 const SizedBox(height: 10),
 _FieldLabel('Checklist'),
 VoiceTextField(
 controller: _checklist,
 decoration: _inputDecoration(context, '')),
 const SizedBox(height: 10),
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel('Frequency'),
 VoiceTextField(
 controller: _frequency,
 decoration: _inputDecoration(context, 'Weekly')),
 ],
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel('Owner'),
 DropdownButtonFormField<String>(
 value: _owner,
 decoration: _inputDecoration(context, ''),
 items: widget.ownerOptions
 .map((e) =>
 DropdownMenuItem(value: e, child: Text(e)))
 .toList(),
 onChanged: (value) {
 if (value != null) setState(() => _owner = value);
 },
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 _FieldLabel('Standards Reference'),
 VoiceTextField(
 controller: _standards,
 decoration:
 _inputDecoration(context, 'ISO 9001 / Internal SOP')),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(),
 child: const Text('Cancel')),
 ElevatedButton(onPressed: _save, child: const Text('Save')),
 ],
 );
 }
}

class _QualityTaskDialog extends StatefulWidget {
 const _QualityTaskDialog({
 required this.ownerOptions,
 this.initialValue,
 });

 final List<String> ownerOptions;
 final QualityTaskEntry? initialValue;

 @override
 State<_QualityTaskDialog> createState() => _QualityTaskDialogState();
}

class _QualityTaskDialogState extends State<_QualityTaskDialog> {
 late final TextEditingController _task;
 late final TextEditingController _percent;
 late final TextEditingController _start;
 late final TextEditingController _end;
 late final TextEditingController _comments;
 late String _responsible;
 late QualityTaskStatus _status;
 late QualityTaskPriority _priority;

 @override
 void initState() {
 super.initState();
 final initial = widget.initialValue;
 _task = TextEditingController(text: initial?.task ?? '');
 _percent = TextEditingController(
 text: (initial?.percentComplete ?? 0).toStringAsFixed(0));
 _start = TextEditingController(
 text: _normalizedDateText(initial?.startDate ?? ''),
 );
 _end = TextEditingController(
 text: _normalizedDateText(initial?.endDate ?? ''),
 );
 _comments = TextEditingController(text: initial?.comments ?? '');
 _responsible = initial?.responsible.isNotEmpty == true
 ? initial!.responsible
 : widget.ownerOptions.first;
 _status = initial?.status ?? QualityTaskStatus.notStarted;
 _priority = initial?.priority ?? QualityTaskPriority.minimal;
 }

 Future<void> _pickStartDate() async {
 final picked = await _showQualityDatePicker(
 context,
 currentValue: _start.text.trim(),
 );
 if (!mounted || picked == null) return;
 setState(() => _start.text = _formatDate(picked));
 }

 Future<void> _pickEndDate() async {
 final picked = await _showQualityDatePicker(
 context,
 currentValue: _end.text.trim(),
 );
 if (!mounted || picked == null) return;
 setState(() => _end.text = _formatDate(picked));
 }

 @override
 void dispose() {
 _task.dispose();
 _percent.dispose();
 _start.dispose();
 _end.dispose();
 _comments.dispose();
 super.dispose();
 }

 void _save() {
 if (_task.text.trim().isEmpty || _responsible.trim().isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Task name and responsible owner are required')),
 );
 return;
 }

 final percent =
 double.tryParse(_percent.text.replaceAll('%', '').trim()) ?? 0;

 final startDate = _parseFlexibleDate(_start.text.trim());
 var endText = _end.text.trim();
 var endDate = _parseFlexibleDate(endText);

 if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('End date cannot be before start date')),
 );
 return;
 }

 if (_status == QualityTaskStatus.complete && endText.isEmpty) {
 endText = _formatDate(DateTime.now());
 endDate = _parseFlexibleDate(endText);
 }

 final duration = _durationDays(_start.text.trim(), endText);

 Navigator.of(context).pop(
 QualityTaskEntry(
 id: widget.initialValue?.id ?? _newId(),
 task: _task.text.trim(),
 percentComplete: percent,
 responsible: _responsible,
 startDate: _start.text.trim(),
 endDate: endText,
 durationDays: duration,
 status: _status,
 priority: _priority,
 comments: _comments.text.trim(),
 resolvedDate: _status == QualityTaskStatus.complete
 ? _formatDate(endDate ?? DateTime.now())
 : null,
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 return AlertDialog(
 title: Text(widget.initialValue == null ? 'Add Task' : 'Edit Task'),
 content: SingleChildScrollView(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 _FieldLabel('Task'),
 VoiceTextField(
 controller: _task,
 decoration: _inputDecoration(context, 'Task title')),
 const SizedBox(height: 10),
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel('% Complete'),
 VoiceTextField(
 controller: _percent,
 decoration: _inputDecoration(context, '0-100')),
 ],
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel('Responsible'),
 DropdownButtonFormField<String>(
 value: _responsible,
 decoration: _inputDecoration(context, ''),
 items: widget.ownerOptions
 .map((e) =>
 DropdownMenuItem(value: e, child: Text(e)))
 .toList(),
 onChanged: (value) {
 if (value != null) {
 setState(() => _responsible = value);
 }
 },
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel('Start Date'),
 _datePickerField(
 context,
 controller: _start,
 onTap: _pickStartDate,
 ),
 ],
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel('End Date'),
 _datePickerField(
 context,
 controller: _end,
 onTap: _pickEndDate,
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel('Status'),
 DropdownButtonFormField<QualityTaskStatus>(
 value: _status,
 decoration: _inputDecoration(context, ''),
 items: const [
 DropdownMenuItem(
 value: QualityTaskStatus.notStarted,
 child: Text('Not Started')),
 DropdownMenuItem(
 value: QualityTaskStatus.inProgress,
 child: Text('In Progress')),
 DropdownMenuItem(
 value: QualityTaskStatus.complete,
 child: Text('Complete')),
 DropdownMenuItem(
 value: QualityTaskStatus.blocked,
 child: Text('Blocked')),
 ],
 onChanged: (value) {
 if (value != null) setState(() => _status = value);
 },
 ),
 ],
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel('Priority'),
 DropdownButtonFormField<QualityTaskPriority>(
 value: _priority,
 decoration: _inputDecoration(context, ''),
 items: const [
 DropdownMenuItem(
 value: QualityTaskPriority.minimal,
 child: Text('Minimal')),
 DropdownMenuItem(
 value: QualityTaskPriority.moderate,
 child: Text('Moderate')),
 DropdownMenuItem(
 value: QualityTaskPriority.critical,
 child: Text('Critical')),
 ],
 onChanged: (value) {
 if (value != null) setState(() => _priority = value);
 },
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 _FieldLabel('Comments'),
 VoiceTextField(
 controller: _comments,
 minLines: 2,
 maxLines: 4,
 decoration: _inputDecoration(context, ''),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(),
 child: const Text('Cancel')),
 ElevatedButton(onPressed: _save, child: const Text('Save')),
 ],
 );
 }
}

class _QualityAuditDialog extends StatefulWidget {
 const _QualityAuditDialog({
 required this.ownerOptions,
 this.initialValue,
 });

 final List<String> ownerOptions;
 final QualityAuditEntry? initialValue;

 @override
 State<_QualityAuditDialog> createState() => _QualityAuditDialogState();
}

class _QualityAuditDialogState extends State<_QualityAuditDialog> {
 late final TextEditingController _title;
 late final TextEditingController _scope;
 late final TextEditingController _planned;
 late final TextEditingController _completed;
 late final TextEditingController _findings;
 late final TextEditingController _notes;
 late String _owner;
 late AuditResultStatus _result;

 @override
 void initState() {
 super.initState();
 final initial = widget.initialValue;
 _title = TextEditingController(text: initial?.title ?? '');
 _scope = TextEditingController(text: initial?.scope ?? '');
 _planned = TextEditingController(
 text: _normalizedDateText(initial?.plannedDate ?? ''),
 );
 _completed = TextEditingController(
 text: _normalizedDateText(initial?.completedDate ?? ''),
 );
 _findings = TextEditingController(text: initial?.findings ?? '');
 _notes = TextEditingController(text: initial?.notes ?? '');
 _owner = initial?.owner.isNotEmpty == true
 ? initial!.owner
 : widget.ownerOptions.first;
 _result = initial?.result ?? AuditResultStatus.pending;
 }

 Future<void> _pickPlannedDate() async {
 final picked = await _showQualityDatePicker(
 context,
 currentValue: _planned.text.trim(),
 );
 if (!mounted || picked == null) return;
 setState(() => _planned.text = _formatDate(picked));
 }

 Future<void> _pickCompletedDate() async {
 final picked = await _showQualityDatePicker(
 context,
 currentValue: _completed.text.trim(),
 );
 if (!mounted || picked == null) return;
 setState(() => _completed.text = _formatDate(picked));
 }

 @override
 void dispose() {
 _title.dispose();
 _scope.dispose();
 _planned.dispose();
 _completed.dispose();
 _findings.dispose();
 _notes.dispose();
 super.dispose();
 }

 void _save() {
 if (_title.text.trim().isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Audit title is required')),
 );
 return;
 }

 final plannedDate = _parseFlexibleDate(_planned.text.trim());
 var completedText = _completed.text.trim();
 final completedDate = _parseFlexibleDate(completedText);

 if (plannedDate != null &&
 completedDate != null &&
 completedDate.isBefore(plannedDate)) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Completed date cannot be before planned date')),
 );
 return;
 }

 if ((_result == AuditResultStatus.pass ||
 _result == AuditResultStatus.conditional ||
 _result == AuditResultStatus.fail) &&
 completedText.isEmpty) {
 completedText = _formatDate(DateTime.now());
 }

 Navigator.of(context).pop(
 QualityAuditEntry(
 id: widget.initialValue?.id ?? _newId(),
 title: _title.text.trim(),
 scope: _scope.text.trim(),
 plannedDate: _planned.text.trim(),
 completedDate: completedText,
 owner: _owner,
 result: _result,
 findings: _findings.text.trim(),
 notes: _notes.text.trim(),
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 return AlertDialog(
 title: Text(widget.initialValue == null ? 'Add Audit' : 'Edit Audit'),
 content: SingleChildScrollView(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 _FieldLabel('Audit Title'),
 VoiceTextField(
 controller: _title, decoration: _inputDecoration(context, '')),
 const SizedBox(height: 10),
 _FieldLabel('Scope'),
 VoiceTextField(
 controller: _scope,
 minLines: 2,
 maxLines: 3,
 decoration: _inputDecoration(context, ''),
 ),
 const SizedBox(height: 10),
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel('Planned Date'),
 _datePickerField(
 context,
 controller: _planned,
 onTap: _pickPlannedDate,
 ),
 ],
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel('Completed Date'),
 _datePickerField(
 context,
 controller: _completed,
 onTap: _pickCompletedDate,
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel('Owner'),
 DropdownButtonFormField<String>(
 value: _owner,
 decoration: _inputDecoration(context, ''),
 items: widget.ownerOptions
 .map((e) =>
 DropdownMenuItem(value: e, child: Text(e)))
 .toList(),
 onChanged: (value) {
 if (value != null) setState(() => _owner = value);
 },
 ),
 ],
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel('Result'),
 DropdownButtonFormField<AuditResultStatus>(
 value: _result,
 decoration: _inputDecoration(context, ''),
 items: const [
 DropdownMenuItem(
 value: AuditResultStatus.pending,
 child: Text('Pending'),
 ),
 DropdownMenuItem(
 value: AuditResultStatus.pass,
 child: Text('Pass'),
 ),
 DropdownMenuItem(
 value: AuditResultStatus.conditional,
 child: Text('Conditional'),
 ),
 DropdownMenuItem(
 value: AuditResultStatus.fail,
 child: Text('Fail'),
 ),
 ],
 onChanged: (value) {
 if (value != null) setState(() => _result = value);
 },
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 _FieldLabel('Findings'),
 VoiceTextField(
 controller: _findings,
 minLines: 2,
 maxLines: 4,
 decoration: _inputDecoration(context, ''),
 ),
 const SizedBox(height: 10),
 _FieldLabel('Notes'),
 VoiceTextField(
 controller: _notes,
 minLines: 2,
 maxLines: 4,
 decoration: _inputDecoration(context, ''),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(),
 child: const Text('Cancel')),
 ElevatedButton(onPressed: _save, child: const Text('Save')),
 ],
 );
 }
}

class _CorrectiveActionDialog extends StatefulWidget {
 const _CorrectiveActionDialog({
 required this.ownerOptions,
 this.initialValue,
 });

 final List<String> ownerOptions;
 final CorrectiveActionEntry? initialValue;

 @override
 State<_CorrectiveActionDialog> createState() =>
 _CorrectiveActionDialogState();
}

class _CorrectiveActionDialogState extends State<_CorrectiveActionDialog> {
 late final TextEditingController _title;
 late final TextEditingController _rootCause;
 late final TextEditingController _action;
 late final TextEditingController _dueDate;
 late final TextEditingController _verification;
 late String _owner;
 late CorrectiveActionStatus _status;
 String? _validationMessage;

 @override
 void initState() {
 super.initState();
 final initial = widget.initialValue;
 _title = TextEditingController(text: initial?.title ?? '');
 _rootCause = TextEditingController(text: initial?.rootCause ?? '');
 _action = TextEditingController(text: initial?.action ?? '');
 _dueDate = TextEditingController(
 text: _normalizedDateText(initial?.dueDate ?? ''),
 );
 _verification =
 TextEditingController(text: initial?.verificationNotes ?? '');
 _owner = initial?.owner.isNotEmpty == true
 ? initial!.owner
 : widget.ownerOptions.first;
 _status = initial?.status ?? CorrectiveActionStatus.open;
 }

 Future<void> _pickDueDate() async {
 final picked = await _showQualityDatePicker(
 context,
 currentValue: _dueDate.text.trim(),
 );
 if (!mounted || picked == null) return;
 setState(() {
 _dueDate.text = _formatDate(picked);
 _validationMessage = null;
 });
 }

 @override
 void dispose() {
 _title.dispose();
 _rootCause.dispose();
 _action.dispose();
 _dueDate.dispose();
 _verification.dispose();
 super.dispose();
 }

 void _save() {
 if (_rootCause.text.trim().isEmpty ||
 _action.text.trim().isEmpty ||
 _owner.trim().isEmpty ||
 _dueDate.text.trim().isEmpty) {
 setState(() {
 _validationMessage =
 'Root cause, action, owner, and due date are required';
 });
 return;
 }

 final due = _parseFlexibleDate(_dueDate.text.trim());
 if (due == null) {
 setState(() {
 _validationMessage = 'Due date must be selected from the date picker';
 });
 return;
 }

 final now = DateTime.now();
 _validationMessage = null;
 if (!mounted) return;

 Navigator.of(context).pop(
 CorrectiveActionEntry(
 id: widget.initialValue?.id ?? _newId(),
 auditEntryId: widget.initialValue?.auditEntryId ?? '',
 title: _title.text.trim().isEmpty
 ? 'Corrective Action'
 : _title.text.trim(),
 rootCause: _rootCause.text.trim(),
 action: _action.text.trim(),
 owner: _owner,
 dueDate: _formatDate(due),
 status: _status,
 createdAt: widget.initialValue?.createdAt ?? now.toIso8601String(),
 closedAt: _status == CorrectiveActionStatus.closed
 ? now.toIso8601String()
 : (widget.initialValue?.closedAt ?? ''),
 verificationNotes: _verification.text.trim(),
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 return AlertDialog(
 title: Text(widget.initialValue == null
 ? 'Create Corrective Action'
 : 'Edit Corrective Action'),
 content: SingleChildScrollView(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 _FieldLabel('Title'),
 VoiceTextField(
 controller: _title, decoration: _inputDecoration(context, '')),
 const SizedBox(height: 10),
 _FieldLabel('Root Cause'),
 VoiceTextField(
 controller: _rootCause,
 minLines: 2,
 maxLines: 4,
 decoration: _inputDecoration(context, ''),
 ),
 const SizedBox(height: 10),
 _FieldLabel('Action'),
 VoiceTextField(
 controller: _action,
 minLines: 2,
 maxLines: 4,
 decoration: _inputDecoration(context, ''),
 ),
 const SizedBox(height: 10),
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel('Owner'),
 DropdownButtonFormField<String>(
 value: _owner,
 decoration: _inputDecoration(context, ''),
 items: widget.ownerOptions
 .map((e) =>
 DropdownMenuItem(value: e, child: Text(e)))
 .toList(),
 onChanged: (value) {
 if (value != null) setState(() => _owner = value);
 },
 ),
 ],
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel('Due Date'),
 _datePickerField(
 context,
 controller: _dueDate,
 onTap: _pickDueDate,
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 _FieldLabel('Status'),
 DropdownButtonFormField<CorrectiveActionStatus>(
 value: _status,
 decoration: _inputDecoration(context, ''),
 items: const [
 DropdownMenuItem(
 value: CorrectiveActionStatus.open, child: Text('Open')),
 DropdownMenuItem(
 value: CorrectiveActionStatus.inProgress,
 child: Text('In Progress')),
 DropdownMenuItem(
 value: CorrectiveActionStatus.verified,
 child: Text('Verified')),
 DropdownMenuItem(
 value: CorrectiveActionStatus.closed,
 child: Text('Closed')),
 DropdownMenuItem(
 value: CorrectiveActionStatus.overdue,
 child: Text('Overdue')),
 ],
 onChanged: (value) {
 if (value != null) setState(() => _status = value);
 },
 ),
 const SizedBox(height: 10),
 _FieldLabel('Verification Notes'),
 VoiceTextField(
 controller: _verification,
 minLines: 2,
 maxLines: 4,
 decoration: _inputDecoration(context, ''),
 ),
 if (_validationMessage != null) ...[
 const SizedBox(height: 10),
 Text(
 _validationMessage!,
 style: const TextStyle(
 color: Color(0xFFDC2626),
 fontSize: 12,
 fontWeight: FontWeight.w600,
 ),
 ),
 ],
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(),
 child: const Text('Cancel')),
 ElevatedButton(onPressed: _save, child: const Text('Save')),
 ],
 );
 }
}

class _QualityChangeDialog extends StatefulWidget {
 const _QualityChangeDialog({this.initialValue});

 final QualityChangeEntry? initialValue;

 @override
 State<_QualityChangeDialog> createState() => _QualityChangeDialogState();
}

class _QualityChangeDialogState extends State<_QualityChangeDialog> {
 late final TextEditingController _description;
 late final TextEditingController _reason;
 late final TextEditingController _requestedBy;
 late final TextEditingController _approvedBy;
 late final TextEditingController _date;
 late final TextEditingController _status;

 @override
 void initState() {
 super.initState();
 final initial = widget.initialValue;
 _description = TextEditingController(text: initial?.description ?? '');
 _reason = TextEditingController(text: initial?.reason ?? '');
 _requestedBy = TextEditingController(text: initial?.requestedBy ?? '');
 _approvedBy = TextEditingController(text: initial?.approvedBy ?? '');
 _date = TextEditingController(
 text: _normalizedDateText(
 initial?.date ?? '',
 fallbackToToday: true,
 ),
 );
 _status = TextEditingController(text: initial?.status ?? 'Draft');
 }

 Future<void> _pickDate() async {
 final picked = await _showQualityDatePicker(
 context,
 currentValue: _date.text.trim(),
 );
 if (!mounted || picked == null) return;
 setState(() => _date.text = _formatDate(picked));
 }

 @override
 void dispose() {
 _description.dispose();
 _reason.dispose();
 _requestedBy.dispose();
 _approvedBy.dispose();
 _date.dispose();
 _status.dispose();
 super.dispose();
 }

 void _save() {
 if (_description.text.trim().isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Change description is required')),
 );
 return;
 }

 Navigator.of(context).pop(
 QualityChangeEntry(
 id: widget.initialValue?.id ?? _newId(),
 description: _description.text.trim(),
 reason: _reason.text.trim(),
 requestedBy: _requestedBy.text.trim(),
 approvedBy: _approvedBy.text.trim(),
 date: _date.text.trim(),
 status: _status.text.trim().isEmpty ? 'Draft' : _status.text.trim(),
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 return AlertDialog(
 title: Text(widget.initialValue == null ? 'Add Change' : 'Edit Change'),
 content: SingleChildScrollView(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 _FieldLabel('Description'),
 VoiceTextField(
 controller: _description,
 minLines: 2,
 maxLines: 4,
 decoration: _inputDecoration(context, ''),
 ),
 const SizedBox(height: 10),
 _FieldLabel('Reason'),
 VoiceTextField(
 controller: _reason, decoration: _inputDecoration(context, '')),
 const SizedBox(height: 10),
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel('Requested By'),
 VoiceTextField(
 controller: _requestedBy,
 decoration: _inputDecoration(context, '')),
 ],
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel('Approved By'),
 VoiceTextField(
 controller: _approvedBy,
 decoration: _inputDecoration(context, '')),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel('Date'),
 _datePickerField(
 context,
 controller: _date,
 onTap: _pickDate,
 ),
 ],
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel('Status'),
 VoiceTextField(
 controller: _status,
 decoration:
 _inputDecoration(context, 'Draft/Approved')),
 ],
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(),
 child: const Text('Cancel')),
 ElevatedButton(onPressed: _save, child: const Text('Save')),
 ],
 );
 }
}

class _TrainingShortcutDialog extends StatefulWidget {
 const _TrainingShortcutDialog({required this.defaultTitle});

 final String defaultTitle;

 @override
 State<_TrainingShortcutDialog> createState() =>
 _TrainingShortcutDialogState();
}

class _TrainingShortcutDialogState extends State<_TrainingShortcutDialog> {
 late final TextEditingController _title;
 late final TextEditingController _description;
 late final TextEditingController _date;
 late final TextEditingController _duration;
 bool _mandatory = false;

 @override
 void initState() {
 super.initState();
 _title = TextEditingController(text: widget.defaultTitle);
 _description = TextEditingController();
 _date = TextEditingController(text: _formatDate(DateTime.now()));
 _duration = TextEditingController(text: '60 mins');
 }

 @override
 void dispose() {
 _title.dispose();
 _description.dispose();
 _date.dispose();
 _duration.dispose();
 super.dispose();
 }

 void _save() {
 if (_title.text.trim().isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Training title is required')),
 );
 return;
 }

 Navigator.of(context).pop(
 TrainingActivity(
 title: _title.text.trim(),
 description: _description.text.trim(),
 date: _date.text.trim(),
 duration: _duration.text.trim(),
 category: 'Training',
 status: 'Upcoming',
 isMandatory: _mandatory,
 isCompleted: false,
 ),
 );
 }

 Future<void> _pickDate() async {
 final picked = await _showQualityDatePicker(
 context,
 currentValue: _date.text.trim(),
 );
 if (!mounted || picked == null) return;
 setState(() => _date.text = _formatDate(picked));
 }

 @override
 Widget build(BuildContext context) {
 return AlertDialog(
 title: const Text('Create Training Activity'),
 content: SingleChildScrollView(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 _FieldLabel('Title'),
 VoiceTextField(
 controller: _title, decoration: _inputDecoration(context, '')),
 const SizedBox(height: 10),
 _FieldLabel('Description'),
 VoiceTextField(
 controller: _description,
 minLines: 2,
 maxLines: 4,
 decoration: _inputDecoration(context, ''),
 ),
 const SizedBox(height: 10),
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel('Date'),
 _datePickerField(
 context,
 controller: _date,
 onTap: _pickDate,
 ),
 ],
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel('Duration'),
 VoiceTextField(
 controller: _duration,
 decoration: _inputDecoration(context, '60 mins')),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 Row(
 children: [
 Checkbox(
 value: _mandatory,
 onChanged: (value) {
 setState(() => _mandatory = value == true);
 },
 ),
 const Text('Mandatory'),
 ],
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(),
 child: const Text('Cancel')),
 ElevatedButton(onPressed: _save, child: const Text('Create')),
 ],
 );
 }
}

class _DashboardConfigDialog extends StatefulWidget {
 const _DashboardConfigDialog({required this.initialValue});

 final QualityDashboardConfig initialValue;

 @override
 State<_DashboardConfigDialog> createState() => _DashboardConfigDialogState();
}

class _DashboardConfigDialogState extends State<_DashboardConfigDialog> {
 late final TextEditingController _target;
 late final TextEditingController _trendPoints;
 late bool _allowOverride;

 @override
 void initState() {
 super.initState();
 _target = TextEditingController(
 text: widget.initialValue.targetTimeToResolutionDays.toStringAsFixed(1),
 );
 _trendPoints = TextEditingController(
 text: widget.initialValue.maxTrendPoints.toString(),
 );
 _allowOverride = widget.initialValue.allowManualMetricsOverride;
 }

 @override
 void dispose() {
 _target.dispose();
 _trendPoints.dispose();
 super.dispose();
 }

 void _save() {
 final target = double.tryParse(_target.text.trim());
 final points = int.tryParse(_trendPoints.text.trim());

 if (target == null || target <= 0) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Target time must be a positive number')),
 );
 return;
 }

 if (points == null || points < 3) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Max trend points must be 3 or more')),
 );
 return;
 }

 Navigator.of(context).pop(
 QualityDashboardConfig(
 targetTimeToResolutionDays: target,
 allowManualMetricsOverride: _allowOverride,
 maxTrendPoints: points,
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 return AlertDialog(
 title: const Text('Dashboard Config'),
 content: SingleChildScrollView(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 _FieldLabel('Target Time to Resolution (days)'),
 VoiceTextField(
 controller: _target,
 decoration: _inputDecoration(context, '15')),
 const SizedBox(height: 10),
 _FieldLabel('Max Trend Points'),
 VoiceTextField(
 controller: _trendPoints,
 decoration: _inputDecoration(context, '12')),
 const SizedBox(height: 10),
 Row(
 children: [
 Checkbox(
 value: _allowOverride,
 onChanged: (value) {
 setState(() => _allowOverride = value == true);
 },
 ),
 const Expanded(child: Text('Allow manual metrics override')),
 ],
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(),
 child: const Text('Cancel')),
 ElevatedButton(onPressed: _save, child: const Text('Save')),
 ],
 );
 }
}

class _MetricsEditDialog extends StatefulWidget {
 const _MetricsEditDialog({required this.metrics});

 final QualityMetrics metrics;

 @override
 State<_MetricsEditDialog> createState() => _MetricsEditDialogState();
}

class _MetricsEditDialogState extends State<_MetricsEditDialog> {
 late final TextEditingController _ddValue;
 late final TextEditingController _ddChange;
 late String _ddTrend;

 late final TextEditingController _csValue;
 late final TextEditingController _csChange;
 late String _csTrend;

 late final TextEditingController _otdValue;
 late final TextEditingController _otdChange;
 late String _otdTrend;

 late final TextEditingController _defectTrend;
 late final TextEditingController _satisfactionTrend;

 @override
 void initState() {
 super.initState();
 final m = widget.metrics;
 _ddValue = TextEditingController(text: m.defectDensity.value);
 _ddChange = TextEditingController(text: m.defectDensity.change);
 _ddTrend = m.defectDensity.trendDirection;

 _csValue = TextEditingController(text: m.customerSatisfaction.value);
 _csChange = TextEditingController(text: m.customerSatisfaction.change);
 _csTrend = m.customerSatisfaction.trendDirection;

 _otdValue = TextEditingController(text: m.onTimeDelivery.value);
 _otdChange = TextEditingController(text: m.onTimeDelivery.change);
 _otdTrend = m.onTimeDelivery.trendDirection;

 _defectTrend = TextEditingController(text: m.defectTrendData.join(', '));
 _satisfactionTrend =
 TextEditingController(text: m.satisfactionTrendData.join(', '));
 }

 @override
 void dispose() {
 _ddValue.dispose();
 _ddChange.dispose();
 _csValue.dispose();
 _csChange.dispose();
 _otdValue.dispose();
 _otdChange.dispose();
 _defectTrend.dispose();
 _satisfactionTrend.dispose();
 super.dispose();
 }

 List<double> _parseSeries(String raw) {
 if (raw.trim().isEmpty) return [];
 return raw.split(',').map((e) => double.tryParse(e.trim()) ?? 0).toList();
 }

 void _save() {
 Navigator.of(context).pop(
 QualityMetrics(
 defectDensity: MetricValue(
 value: _ddValue.text.trim(),
 unit: 'per 1000 LOC',
 change: _ddChange.text.trim(),
 trendDirection: _ddTrend,
 ),
 customerSatisfaction: MetricValue(
 value: _csValue.text.trim(),
 unit: 'from surveys',
 change: _csChange.text.trim(),
 trendDirection: _csTrend,
 ),
 onTimeDelivery: MetricValue(
 value: _otdValue.text.trim(),
 unit: 'last quarter',
 change: _otdChange.text.trim(),
 trendDirection: _otdTrend,
 ),
 defectTrendData: _parseSeries(_defectTrend.text),
 satisfactionTrendData: _parseSeries(_satisfactionTrend.text),
 ),
 );
 }

 Widget _metricRow(
 BuildContext context, {
 required String label,
 required TextEditingController value,
 required TextEditingController change,
 required String trend,
 required ValueChanged<String> onTrend,
 }) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _FieldLabel(label),
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: value,
 decoration: _inputDecoration(context, 'Value'),
 ),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: VoiceTextField(
 controller: change,
 decoration: _inputDecoration(context, 'Change'),
 ),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: DropdownButtonFormField<String>(
 value: trend,
 decoration: _inputDecoration(context, ''),
 items: const [
 DropdownMenuItem(value: 'neutral', child: Text('Neutral')),
 DropdownMenuItem(value: 'up', child: Text('Up')),
 DropdownMenuItem(value: 'down', child: Text('Down')),
 ],
 onChanged: (value) {
 if (value != null) onTrend(value);
 },
 ),
 ),
 ],
 ),
 ],
 );
 }

 @override
 Widget build(BuildContext context) {
 return AlertDialog(
 title: const Text('Manual Metrics Override'),
 content: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 _metricRow(
 context,
 label: 'Defect Density',
 value: _ddValue,
 change: _ddChange,
 trend: _ddTrend,
 onTrend: (v) => setState(() => _ddTrend = v),
 ),
 const SizedBox(height: 12),
 _metricRow(
 context,
 label: 'Customer Satisfaction',
 value: _csValue,
 change: _csChange,
 trend: _csTrend,
 onTrend: (v) => setState(() => _csTrend = v),
 ),
 const SizedBox(height: 12),
 _metricRow(
 context,
 label: 'On-Time Delivery',
 value: _otdValue,
 change: _otdChange,
 trend: _otdTrend,
 onTrend: (v) => setState(() => _otdTrend = v),
 ),
 const SizedBox(height: 12),
 _FieldLabel('Defect Trend (comma-separated)'),
 VoiceTextField(
 controller: _defectTrend,
 decoration: _inputDecoration(context, '12, 10, 9, 8, 7, 6'),
 ),
 const SizedBox(height: 10),
 _FieldLabel('Satisfaction Trend (comma-separated)'),
 VoiceTextField(
 controller: _satisfactionTrend,
 decoration:
 _inputDecoration(context, '3.5, 3.7, 4.0, 4.1, 4.3, 4.4'),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(),
 child: const Text('Cancel')),
 ElevatedButton(onPressed: _save, child: const Text('Save')),
 ],
 );
 }
}

class _MetricSummaryData {
 const _MetricSummaryData({
 required this.title,
 required this.value,
 required this.changeLabel,
 required this.changeContext,
 required this.trend,
 });

 final String title;
 final String value;
 final String changeLabel;
 final String changeContext;
 final _MetricTrend trend;
}

class _QaTechnique {
 const _QaTechnique({
 required this.name,
 required this.description,
 required this.frequency,
 required this.standards,
 });

 final String name;
 final String description;
 final String frequency;
 final String standards;
}

class _MetricSummaryCard extends StatelessWidget {
 const _MetricSummaryCard({required this.data});

 final _MetricSummaryData data;

 Color _trendColor() {
 switch (data.trend) {
 case _MetricTrend.up:
 return const Color(0xFF16A34A);
 case _MetricTrend.down:
 return const Color(0xFFEF4444);
 case _MetricTrend.neutral:
 return const Color(0xFF6B7280);
 }
 }

 IconData _trendIcon() {
 switch (data.trend) {
 case _MetricTrend.up:
 return Icons.trending_up;
 case _MetricTrend.down:
 return Icons.trending_down;
 case _MetricTrend.neutral:
 return Icons.horizontal_rule;
 }
 }

 @override
 Widget build(BuildContext context) {
 final trendColor = _trendColor();
 final isNeutral = data.trend == _MetricTrend.neutral;

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 14,
 offset: const Offset(0, 10),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 data.title,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF4B5563),
 ),
 ),
 Icon(_trendIcon(), color: trendColor, size: 20),
 ],
 ),
 const SizedBox(height: 12),
 Text(
 data.value,
 style: const TextStyle(
 fontSize: 28,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 8),
 RichText(
 text: TextSpan(
 children: [
 TextSpan(
 text: '${data.changeLabel} ',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: isNeutral ? const Color(0xFF6B7280) : trendColor,
 ),
 ),
 TextSpan(
 text: data.changeContext,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }
}

class _TrendCard extends StatelessWidget {
 const _TrendCard({
 required this.title,
 required this.subtitle,
 required this.lineColor,
 required this.areaColor,
 required this.dataPoints,
 required this.labels,
 this.maxYBuffer = 0,
 });

 final String title;
 final String subtitle;
 final Color lineColor;
 final Color areaColor;
 final List<double> dataPoints;
 final List<String> labels;
 final double maxYBuffer;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(22),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 16,
 offset: const Offset(0, 12),
 ),
 ],
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
 const SizedBox(height: 6),
 Text(
 subtitle,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 ),
 ),
 const SizedBox(height: 24),
 AspectRatio(
 aspectRatio: 1.7,
 child: CustomPaint(
 painter: _TrendLinePainter(
 lineColor: lineColor,
 areaColor: areaColor,
 values: dataPoints,
 maxYBuffer: maxYBuffer,
 ),
 ),
 ),
 const SizedBox(height: 16),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 for (final label in labels)
 Expanded(
 child: Text(
 label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF9CA3AF),
 ),
 textAlign: TextAlign.center,
 ),
 ),
 ],
 ),
 ],
 ),
 );
 }
}

enum _MetricTrend { up, down, neutral }

class _TrendLinePainter extends CustomPainter {
 _TrendLinePainter({
 required this.lineColor,
 required this.areaColor,
 required this.values,
 this.maxYBuffer = 0,
 });

 final Color lineColor;
 final Color areaColor;
 final List<double> values;
 final double maxYBuffer;

 @override
 void paint(Canvas canvas, Size size) {
 if (values.isEmpty) return;

 final minValue = values.reduce((a, b) => a < b ? a : b);
 final maxValue = values.reduce((a, b) => a > b ? a : b) + maxYBuffer;
 final verticalRange =
 (maxValue - minValue).abs() < 0.0001 ? 1 : maxValue - minValue;

 final horizontalStep =
 values.length == 1 ? 0.0 : size.width / (values.length - 1);

 final linePath = Path();
 final areaPath = Path();

 for (int i = 0; i < values.length; i++) {
 final x = horizontalStep * i;
 final normalizedY = (values[i] - minValue) / verticalRange;
 final y = size.height - (normalizedY * size.height);

 if (i == 0) {
 linePath.moveTo(x, y);
 areaPath.moveTo(x, size.height);
 areaPath.lineTo(x, y);
 } else {
 final prevX = horizontalStep * (i - 1);
 final prevNormalizedY = (values[i - 1] - minValue) / verticalRange;
 final prevY = size.height - (prevNormalizedY * size.height);

 final cx = (prevX + x) / 2;
 linePath.cubicTo(cx, prevY, cx, y, x, y);
 areaPath.cubicTo(cx, prevY, cx, y, x, y);
 }
 }

 areaPath.lineTo(size.width, size.height);
 areaPath.close();

 final areaPaint = Paint()
 ..color = areaColor.withOpacity(0.5)
 ..style = PaintingStyle.fill;
 canvas.drawPath(areaPath, areaPaint);

 final linePaint = Paint()
 ..color = lineColor
 ..strokeWidth = 3
 ..style = PaintingStyle.stroke
 ..strokeCap = StrokeCap.round;
 canvas.drawPath(linePath, linePaint);

 final pointPaint = Paint()..color = lineColor;
 for (int i = 0; i < values.length; i++) {
 final x = horizontalStep * i;
 final normalizedY = (values[i] - minValue) / verticalRange;
 final y = size.height - (normalizedY * size.height);
 canvas.drawCircle(Offset(x, y), 4, pointPaint);
 }
 }

 @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) {
  return oldDelegate.values != values ||
  oldDelegate.lineColor != lineColor ||
  oldDelegate.areaColor != areaColor ||
  oldDelegate.maxYBuffer != maxYBuffer;
  }
}

class _CoqView extends StatelessWidget {
  const _CoqView();

  @override
  Widget build(BuildContext context) {
    final data = ProjectDataHelper.getData(context);
    final coq = data.costOfQualityData ?? CostOfQualityData();

    Widget _buildCategoryCard({
      required String title,
      required String amount,
      required IconData icon,
      required Color color,
    }) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 4),
            Text(amount,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cost of Quality Summary',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827))),
          const SizedBox(height: 6),
          const Text(
            'Track prevention, appraisal, and failure costs across the project lifecycle.',
            style:
                TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 240,
                child: _buildCategoryCard(
                  title: 'Prevention Costs',
                  amount: NumberFormat.simpleCurrency(decimalDigits: 0)
                      .format(coq.totalPrevention),
                  icon: Icons.shield_outlined,
                  color: const Color(0xFF059669),
                ),
              ),
              SizedBox(
                width: 240,
                child: _buildCategoryCard(
                  title: 'Appraisal Costs',
                  amount: NumberFormat.simpleCurrency(decimalDigits: 0)
                      .format(coq.totalAppraisal),
                  icon: Icons.search_outlined,
                  color: const Color(0xFFD97706),
                ),
              ),
              SizedBox(
                width: 240,
                child: _buildCategoryCard(
                  title: 'Internal Failure',
                  amount: NumberFormat.simpleCurrency(decimalDigits: 0)
                      .format(coq.totalInternalFailure),
                  icon: Icons.warning_amber_outlined,
                  color: const Color(0xFFD97706),
                ),
              ),
              SizedBox(
                width: 240,
                child: _buildCategoryCard(
                  title: 'External Failure',
                  amount: NumberFormat.simpleCurrency(decimalDigits: 0)
                      .format(coq.totalExternalFailure),
                  icon: Icons.error_outline,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF78350F), Color(0xFF2D5F8A)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    color: Colors.white, size: 32),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Cost of Quality',
                        style: TextStyle(
                            fontSize: 13, color: Colors.white70)),
                    const SizedBox(height: 4),
                    Text(
                      NumberFormat.simpleCurrency(decimalDigits: 0)
                          .format(coq.totalCoq),
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
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
}
