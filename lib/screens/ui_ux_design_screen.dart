import 'package:ndu_project/widgets/voice_text_field.dart';
// ignore_for_file: unused_element

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ndu_project/widgets/csv_table_import_button.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/project_navigation_service.dart';
import 'package:ndu_project/services/activity_log_service.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/screens/backend_design_screen.dart';
import 'package:ndu_project/screens/development_set_up_screen.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/utils/design_planning_document.dart';
import 'package:ndu_project/widgets/execution_phase_ui.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/services/openai_service_secure.dart';

class UiUxDesignScreen extends StatefulWidget {
 const UiUxDesignScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const UiUxDesignScreen()),
 );
 }

 @override
 State<UiUxDesignScreen> createState() => _UiUxDesignScreenState();
}

class _UiUxDesignScreenState extends State<UiUxDesignScreen> {
 final _Debouncer _saveDebouncer = _Debouncer();
 bool _isLoading = false;
 bool _suspendSave = false;
 bool _didSeedDefaults = false;

 // User Journey Register
 List<_JourneyRow> _journeys = [];

 // Interface Architecture Register
 List<_InterfaceRow> _interfaces = [];

 // Design System Tokens Register
 List<_DesignTokenRow> _designTokens = [];

 // Usability & Accessibility Validation Register
 List<_UsabilityRow> _usabilityEntries = [];

 // Design Review Gates
 List<_ReviewGateRow> _reviewGates = [];

 // KAZ AI regeneration tracking
 final Map<String, bool> _kazAiRegenerating = {};
 // KAZ AI field-level generation tracking (for dialogs)
 final Map<String, bool> _kazFieldGenerating = {};

 static const List<String> _journeyStatusOptions = [
 'Mapped',
 'Draft',
 'Planned',
 'In progress',
 'Validated',
 'Deprecated',
 ];

 static const List<String> _interfaceStateOptions = [
 'Wireframe',
 'User flow map',
 'To define',
 'Prototype',
 'Final',
 'Deprecated',
 ];

 static const List<String> _tokenStatusOptions = [
 'Ready',
 'Draft',
 'In review',
 'Planned',
 'Deprecated',
 ];

 static const List<String> _usabilityStatusOptions = [
 'Pass',
 'Fail',
 'In progress',
 'Not tested',
 'Conditional',
 ];

 static const List<String> _reviewGateStatusOptions = [
 'Pending',
 'In Review',
 'Approved',
 'Rejected',
 'Waived',
 ];

 String? get _projectId {
 try {
 final provider = ProjectDataInherited.maybeOf(context);
 return provider?.projectData.projectId;
 } catch (e) {
 return null;
 }
 }

 @override
 void initState() {
 super.initState();
 _journeys = _defaultJourneys();
 _interfaces = _defaultInterfaces();
 _designTokens = _defaultDesignTokens();
 _usabilityEntries = _defaultUsabilityEntries();
 _reviewGates = _defaultReviewGates();
 WidgetsBinding.instance.addPostFrameCallback((_) async {
 final provider = ProjectDataInherited.maybeOf(context);
 final projectId = provider?.projectData.projectId;
 if (projectId != null && projectId.isNotEmpty) {
 await ProjectNavigationService.instance.saveLastPage(
 projectId,
 'ui-ux-design',
 );
 }
 await _loadFromFirestore();
 });
 }

 
 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'UI/UX Design',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['ui_ux_design_screen'] ?? 'No data recorded.'),
 ],
 );
 }
@override
 void dispose() {
 _saveDebouncer.dispose();
 super.dispose();
 }

 DocumentReference<Map<String, dynamic>> _docFor(String projectId) {
 return FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('design_phase_sections')
 .doc('ui_ux_design');
 }

 void _scheduleSave() {
 if (_suspendSave) return;
 _saveDebouncer.run(_saveToFirestore);
 }

 Future<void> _loadFromFirestore() async {
 final provider = ProjectDataInherited.maybeOf(context);
 final projectId = provider?.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;
 if (!mounted) return;
 setState(() => _isLoading = true);
 bool shouldSeedDefaults = false;
 try {
 final doc = await _docFor(projectId).get();
 final data = doc.data() ?? {};
 _suspendSave = true;
 if (!mounted) return;
 final journeys = _JourneyRow.fromList(data['journeys']);
 final interfaces = _InterfaceRow.fromList(data['interfaces']);
 final designTokens = _DesignTokenRow.fromList(data['designTokens']);
 final usabilityEntries = _UsabilityRow.fromList(data['usabilityEntries']);
 final reviewGates = _ReviewGateRow.fromList(data['reviewGates']);
 shouldSeedDefaults = data.isEmpty && !_didSeedDefaults;
 setState(() {
 if (shouldSeedDefaults) {
 _didSeedDefaults = true;
 final planningDoc = DesignPlanningDocument.fromProjectData(
 provider?.projectData ?? ProjectDataModel(),
 );
 _journeys = planningDoc.journeys.isEmpty
 ? _defaultJourneys()
 : planningDoc.journeys
 .map((item) => _JourneyRow(
 id: _newId(),
 title: item.name,
 description: item.purpose,
 touchpoints: 'TBD',
 owner: 'UX Lead',
 priority: 'Medium',
 status: item.status.isEmpty ? 'Planned' : item.status,
 ))
 .toList();
 _interfaces = planningDoc.interfaces.isEmpty
 ? _defaultInterfaces()
 : planningDoc.interfaces
 .map((item) => _InterfaceRow(
 id: _newId(),
 area: item.name,
 purpose: item.purpose,
 fidelity: 'Low',
 owner: 'UI Designer',
 status: item.status.isEmpty ? 'To define' : item.status,
 ))
 .toList();
 _designTokens = _defaultDesignTokens();
 _usabilityEntries = _defaultUsabilityEntries();
 _reviewGates = _defaultReviewGates();
 } else {
 _journeys = data.containsKey('journeys') && journeys.isNotEmpty
 ? journeys
 : _defaultJourneys();
 _interfaces = data.containsKey('interfaces') && interfaces.isNotEmpty
 ? interfaces
 : _defaultInterfaces();
 _designTokens =
 data.containsKey('designTokens') && designTokens.isNotEmpty
 ? designTokens
 : _defaultDesignTokens();
 _usabilityEntries =
 data.containsKey('usabilityEntries') && usabilityEntries.isNotEmpty
 ? usabilityEntries
 : _defaultUsabilityEntries();
 _reviewGates =
 data.containsKey('reviewGates') && reviewGates.isNotEmpty
 ? reviewGates
 : _defaultReviewGates();
 }
 });
 } catch (error) {
 debugPrint('UI/UX design load error: $error');
 } finally {
 _suspendSave = false;
 if (mounted) {
 setState(() => _isLoading = false);
 if (shouldSeedDefaults) _scheduleSave();
 }
 }
 }

 Future<void> _saveToFirestore() async {
 final provider = ProjectDataInherited.maybeOf(context);
 final projectId = provider?.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;
 try {
 await _docFor(projectId).set({
 'journeys': _journeys.map((e) => e.toMap()).toList(),
 'interfaces': _interfaces.map((e) => e.toMap()).toList(),
 'designTokens': _designTokens.map((e) => e.toMap()).toList(),
 'usabilityEntries': _usabilityEntries.map((e) => e.toMap()).toList(),
 'reviewGates': _reviewGates.map((e) => e.toMap()).toList(),
 'updatedAt': FieldValue.serverTimestamp(),
 }, SetOptions(merge: true));
 await ActivityLogService.instance.logActivity(
 projectId: projectId,
 phase: 'Design Phase',
 page: 'UI/UX Design',
 action: 'Updated UI/UX design data',
 );
 } catch (error) {
 debugPrint('UI/UX design save error: $error');
 }
 }

 // ─── Default Data ────────────────────────────────────────────────

 List<_JourneyRow> _defaultJourneys() {
 return [
 _JourneyRow(
 id: _newId(),
 title: 'User onboarding & first-time setup',
 description: 'Guided registration, profile creation, and preference configuration for new users entering the system for the first time.',
 touchpoints: '5 screens, 2 modals',
 owner: 'UX Lead',
 priority: 'Critical',
 status: 'Mapped',
 ),
 _JourneyRow(
 id: _newId(),
 title: 'Core task completion flow',
 description: 'Primary workflow from task initiation through data entry, validation, and successful completion with confirmation feedback.',
 touchpoints: '8 screens, 3 API calls',
 owner: 'Product Designer',
 priority: 'Critical',
 status: 'In progress',
 ),
 _JourneyRow(
 id: _newId(),
 title: 'Error recovery & support escalation',
 description: 'Error state handling, inline validation feedback, help documentation access, and escalation path to live support channels.',
 touchpoints: '4 screens, 1 modal',
 owner: 'UX Researcher',
 priority: 'High',
 status: 'Draft',
 ),
 _JourneyRow(
 id: _newId(),
 title: 'Dashboard navigation & data discovery',
 description: 'Entry point navigation, filter-based search, saved views, and contextual drill-down into detailed records and reports.',
 touchpoints: '6 screens',
 owner: 'UX Lead',
 priority: 'High',
 status: 'Planned',
 ),
 _JourneyRow(
 id: _newId(),
 title: 'Administrative configuration & settings',
 description: 'System settings, user role management, permission configuration, and organizational preference controls for admin users.',
 touchpoints: '7 screens, 2 confirmation dialogs',
 owner: 'Product Designer',
 priority: 'Medium',
 status: 'Planned',
 ),
 ];
 }

 List<_InterfaceRow> _defaultInterfaces() {
 return [
 _InterfaceRow(
 id: _newId(),
 area: 'Web application - Dashboard',
 purpose: 'Primary entry point displaying KPI summaries, recent activity, and navigation shortcuts for authenticated users.',
 fidelity: 'High',
 owner: 'UI Designer',
 status: 'Prototype',
 ),
 _InterfaceRow(
 id: _newId(),
 area: 'Mobile responsive - Task management',
 purpose: 'Touch-optimized task list with swipe actions, pull-to-refresh, and contextual bottom sheets for quick edits.',
 fidelity: 'Medium',
 owner: 'UI Designer',
 status: 'Wireframe',
 ),
 _InterfaceRow(
 id: _newId(),
 area: 'Authentication & authorization screens',
 purpose: 'Login, MFA verification, password reset, and session timeout handling with SSO integration points.',
 fidelity: 'High',
 owner: 'UX Lead',
 status: 'Prototype',
 ),
 _InterfaceRow(
 id: _newId(),
 area: 'Data visualization & reporting module',
 purpose: 'Interactive charts, exportable reports, date range selectors, and comparison views for analytical use cases.',
 fidelity: 'Low',
 owner: 'Product Designer',
 status: 'User flow map',
 ),
 _InterfaceRow(
 id: _newId(),
 area: 'Notification center & alert preferences',
 purpose: 'In-app notification feed, read/unread states, alert configuration, and channel preferences (email, push, in-app).',
 fidelity: 'Low',
 owner: 'UI Designer',
 status: 'To define',
 ),
 ];
 }

 List<_DesignTokenRow> _defaultDesignTokens() {
 return [
 _DesignTokenRow(
 id: _newId(),
 title: 'Color palette - Primary',
 description: 'Brand primary (#0F172A), secondary (#2563EB), accent (#F59E0B), surface (#F8FAFC) with usage rules for dark/light themes.',
 category: 'Colors',
 status: 'Ready',
 owner: 'Design Systems Lead',
 ),
 _DesignTokenRow(
 id: _newId(),
 title: 'Typography scale',
 description: 'Display (48/40/32), headings (24/20/18), body (16/14), caption (12/11). Inter for UI, Satoshi for display. Line heights and letter spacing defined.',
 category: 'Typography',
 status: 'Ready',
 owner: 'Design Systems Lead',
 ),
 _DesignTokenRow(
 id: _newId(),
 title: 'Spacing & grid system',
 description: '4px base unit, 8/12/16/24/32/48/64 spacing scale. 12-column grid with 24px gutters for responsive layouts.',
 category: 'Layout',
 status: 'Ready',
 owner: 'Design Systems Lead',
 ),
 _DesignTokenRow(
 id: _newId(),
 title: 'Elevation & shadow tokens',
 description: '5 elevation levels (0-4) with corresponding box shadows for cards, modals, dropdowns, and floating elements.',
 category: 'Effects',
 status: 'Draft',
 owner: 'UI Designer',
 ),
 _DesignTokenRow(
 id: _newId(),
 title: 'Interaction states & micro-animations',
 description: 'Hover, focus, active, disabled, loading, success, and error states with 200ms transition curves and motion guidelines.',
 category: 'Motion',
 status: 'Draft',
 owner: 'UX Lead',
 ),
 _DesignTokenRow(
 id: _newId(),
 title: 'Iconography system',
 description: '24px grid, 2px stroke, rounded caps. Material Symbols as base with custom overrides for domain-specific actions.',
 category: 'Iconography',
 status: 'In review',
 owner: 'UI Designer',
 ),
 ];
 }

 List<_UsabilityRow> _defaultUsabilityEntries() {
 return [
 _UsabilityRow(
 id: _newId(),
 criteria: 'WCAG 2.1 AA color contrast',
 description: 'All text and interactive elements must maintain minimum 4.5:1 contrast ratio against backgrounds in both light and dark themes.',
 standard: 'WCAG 2.1 AA',
 status: 'Pass',
 owner: 'QA Lead',
 notes: 'Automated check passed; manual verification pending for custom components',
 ),
 _UsabilityRow(
 id: _newId(),
 criteria: 'Keyboard navigation completeness',
 description: 'All interactive elements must be reachable and operable via keyboard alone, following logical tab order with visible focus indicators.',
 standard: 'WCAG 2.1 AA / Section 508',
 status: 'In progress',
 owner: 'UX Researcher',
 notes: 'Main flows covered; modal trap and dropdown keyboard support in progress',
 ),
 _UsabilityRow(
 id: _newId(),
 criteria: 'Screen reader compatibility',
 description: 'All content and interactive elements properly announced by VoiceOver (iOS) and TalkBack (Android) with meaningful labels and roles.',
 standard: 'WCAG 2.1 AA / ARIA',
 status: 'Not tested',
 owner: 'QA Lead',
 notes: 'Scheduled for next sprint after component library finalization',
 ),
 _UsabilityRow(
 id: _newId(),
 criteria: 'Touch target sizing (mobile)',
 description: 'All tappable elements minimum 44x44px with adequate spacing to prevent accidental activation on touch devices.',
 standard: 'WCAG 2.1 AA / iOS HIG / Material',
 status: 'Pass',
 owner: 'UI Designer',
 notes: 'Verified on iOS and Android reference devices',
 ),
 _UsabilityRow(
 id: _newId(),
 criteria: 'Task completion rate (core flow)',
 description: 'Minimum 85% of test participants must complete the primary task flow without assistance within expected time benchmarks.',
 standard: 'NNG Usability Benchmark',
 status: 'Not tested',
 owner: 'UX Researcher',
 notes: 'Unmoderated usability test scheduled for next design review cycle',
 ),
 ];
 }

 List<_ReviewGateRow> _defaultReviewGates() {
 return [
 _ReviewGateRow(
 id: _newId(),
 gate: 'Information Architecture Sign-off',
 description: 'Validate sitemap, navigation hierarchy, user flow maps, and content structure against business requirements and user research findings.',
 approver: 'Product Owner',
 department: 'Product',
 priority: 'Critical',
 status: 'Approved',
 targetDate: 'TBD',
 ),
 _ReviewGateRow(
 id: _newId(),
 gate: 'Wireframe & Low-Fidelity Review',
 description: 'Review wireframes for layout, information hierarchy, interaction patterns, and responsive breakpoint behavior before high-fidelity investment.',
 approver: 'UX Lead',
 department: 'Design',
 priority: 'Critical',
 status: 'In Review',
 targetDate: 'TBD',
 ),
 _ReviewGateRow(
 id: _newId(),
 gate: 'Design System Token Validation',
 description: 'Confirm design tokens (colors, typography, spacing, elevation) meet brand guidelines, accessibility standards, and cross-platform rendering requirements.',
 approver: 'Design Systems Lead',
 department: 'Design',
 priority: 'High',
 status: 'Pending',
 targetDate: 'TBD',
 ),
 _ReviewGateRow(
 id: _newId(),
 gate: 'High-Fidelity Prototype Approval',
 description: 'Review interactive prototypes against requirements, validate animations and transitions, confirm responsive behavior across target devices.',
 approver: 'Product Owner',
 department: 'Product',
 priority: 'High',
 status: 'Pending',
 targetDate: 'TBD',
 ),
 _ReviewGateRow(
 id: _newId(),
 gate: 'Accessibility Compliance Check',
 description: 'Verify WCAG 2.1 AA compliance across all interfaces, including color contrast, keyboard navigation, screen reader support, and touch targets.',
 approver: 'QA Lead',
 department: 'Quality',
 priority: 'Critical',
 status: 'Pending',
 targetDate: 'TBD',
 ),
 _ReviewGateRow(
 id: _newId(),
 gate: 'Design Handoff & Developer Acceptance',
 description: 'Final design handoff with annotated specs, asset exports, interaction documentation, and developer sign-off confirming build feasibility.',
 approver: 'Technical Lead',
 department: 'Engineering',
 priority: 'High',
 status: 'Not Started',
 targetDate: 'TBD',
 ),
 ];
 }

 String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

 // ─── KAZ AI Row Regeneration ─────────────────────────────────────────────

 Future<void> _kazRegenerateJourney(int index) async {
 if (index < 0 || index >= _journeys.length) return;
 final key = 'journey_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'User Journey Register');
 final openai = OpenAiServiceSecure();
 final row = _journeys[index];
 final result = await openai.generateCompletion(
 'Based on this project context, regenerate a user journey entry for the UI/UX design phase.\n\n'
 'Context:\n$ctx\n\n'
 'Current entry title: ${row.title}\n'
 'Return ONLY a valid JSON object with keys: "title", "description", "touchpoints", "owner", "priority", "status".\n'
 'Priority must be Critical, High, Medium, or Low. Status must be Mapped, Draft, Planned, In progress, Validated, or Deprecated.',
 maxTokens: 300,
 temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _journeys[index] = _JourneyRow(
 id: row.id,
 title: (parsed['title'] ?? row.title).toString(),
 description: (parsed['description'] ?? row.description).toString(),
 touchpoints: (parsed['touchpoints'] ?? row.touchpoints).toString(),
 owner: (parsed['owner'] ?? row.owner).toString(),
 priority: (parsed['priority'] ?? row.priority).toString(),
 status: (parsed['status'] ?? row.status).toString(),
 );
 });
 _scheduleSave();
 }
 }
 } catch (e) {
 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KAZ AI failed: $e')));
 } finally {
 if (mounted) setState(() => _kazAiRegenerating[key] = false);
 }
 }

 Future<void> _kazRegenerateInterface(int index) async {
 if (index < 0 || index >= _interfaces.length) return;
 final key = 'interface_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Interface Architecture Register');
 final openai = OpenAiServiceSecure();
 final row = _interfaces[index];
 final result = await openai.generateCompletion(
 'Based on this project context, regenerate an interface architecture entry.\n\n'
 'Context:\n$ctx\n\n'
 'Current entry area: ${row.area}\n'
 'Return ONLY a valid JSON object with keys: "area", "purpose", "fidelity", "owner", "status".\n'
 'Fidelity must be High, Medium, or Low. Status must be Wireframe, User flow map, To define, Prototype, Final, or Deprecated.',
 maxTokens: 300,
 temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _interfaces[index] = _InterfaceRow(
 id: row.id,
 area: (parsed['area'] ?? row.area).toString(),
 purpose: (parsed['purpose'] ?? row.purpose).toString(),
 fidelity: (parsed['fidelity'] ?? row.fidelity).toString(),
 owner: (parsed['owner'] ?? row.owner).toString(),
 status: (parsed['status'] ?? row.status).toString(),
 );
 });
 _scheduleSave();
 }
 }
 } catch (e) {
 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KAZ AI failed: $e')));
 } finally {
 if (mounted) setState(() => _kazAiRegenerating[key] = false);
 }
 }

 Future<void> _kazRegenerateDesignToken(int index) async {
 if (index < 0 || index >= _designTokens.length) return;
 final key = 'token_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Design System Tokens Register');
 final openai = OpenAiServiceSecure();
 final row = _designTokens[index];
 final result = await openai.generateCompletion(
 'Based on this project context, regenerate a design system token entry.\n\n'
 'Context:\n$ctx\n\n'
 'Current token: ${row.title}\n'
 'Return ONLY a valid JSON object with keys: "title", "description", "category", "status", "owner".\n'
 'Category must be Colors, Typography, Layout, Effects, Motion, or Iconography. Status must be Ready, Draft, In review, Planned, or Deprecated.',
 maxTokens: 300,
 temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _designTokens[index] = _DesignTokenRow(
 id: row.id,
 title: (parsed['title'] ?? row.title).toString(),
 description: (parsed['description'] ?? row.description).toString(),
 category: (parsed['category'] ?? row.category).toString(),
 status: (parsed['status'] ?? row.status).toString(),
 owner: (parsed['owner'] ?? row.owner).toString(),
 );
 });
 _scheduleSave();
 }
 }
 } catch (e) {
 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KAZ AI failed: $e')));
 } finally {
 if (mounted) setState(() => _kazAiRegenerating[key] = false);
 }
 }

 Future<void> _kazRegenerateUsability(int index) async {
 if (index < 0 || index >= _usabilityEntries.length) return;
 final key = 'usability_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Usability & Accessibility Validation');
 final openai = OpenAiServiceSecure();
 final row = _usabilityEntries[index];
 final result = await openai.generateCompletion(
 'Based on this project context, regenerate a usability & accessibility validation entry.\n\n'
 'Context:\n$ctx\n\n'
 'Current criteria: ${row.criteria}\n'
 'Return ONLY a valid JSON object with keys: "criteria", "description", "standard", "status", "owner", "notes".\n'
 'Status must be Pass, Fail, In progress, Not tested, or Conditional.',
 maxTokens: 300,
 temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _usabilityEntries[index] = _UsabilityRow(
 id: row.id,
 criteria: (parsed['criteria'] ?? row.criteria).toString(),
 description: (parsed['description'] ?? row.description).toString(),
 standard: (parsed['standard'] ?? row.standard).toString(),
 status: (parsed['status'] ?? row.status).toString(),
 owner: (parsed['owner'] ?? row.owner).toString(),
 notes: (parsed['notes'] ?? row.notes).toString(),
 );
 });
 _scheduleSave();
 }
 }
 } catch (e) {
 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KAZ AI failed: $e')));
 } finally {
 if (mounted) setState(() => _kazAiRegenerating[key] = false);
 }
 }

 Future<void> _kazRegenerateReviewGate(int index) async {
 if (index < 0 || index >= _reviewGates.length) return;
 final key = 'gate_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Design Review Gates');
 final openai = OpenAiServiceSecure();
 final row = _reviewGates[index];
 final result = await openai.generateCompletion(
 'Based on this project context, regenerate a design review gate entry.\n\n'
 'Context:\n$ctx\n\n'
 'Current gate: ${row.gate}\n'
 'Return ONLY a valid JSON object with keys: "gate", "description", "approver", "department", "priority", "status", "targetDate".\n'
 'Priority must be Critical, High, Medium, or Low. Status must be Pending, In Review, Approved, Rejected, or Waived.',
 maxTokens: 300,
 temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _reviewGates[index] = _ReviewGateRow(
 id: row.id,
 gate: (parsed['gate'] ?? row.gate).toString(),
 description: (parsed['description'] ?? row.description).toString(),
 approver: (parsed['approver'] ?? row.approver).toString(),
 department: (parsed['department'] ?? row.department).toString(),
 priority: (parsed['priority'] ?? row.priority).toString(),
 status: (parsed['status'] ?? row.status).toString(),
 targetDate: (parsed['targetDate'] ?? row.targetDate).toString(),
 );
 });
 _scheduleSave();
 }
 }
 } catch (e) {
 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KAZ AI failed: $e')));
 } finally {
 if (mounted) setState(() => _kazAiRegenerating[key] = false);
 }
 }

 // ─── Build ────────────────────────────────────────────────────────

 @override
 Widget build(BuildContext context) {
 final isNarrow = MediaQuery.sizeOf(context).width < 980;
 final padding = AppBreakpoints.pagePadding(context);

 return ResponsiveScaffold(
 activeItemLabel: 'UI/UX Design',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: Column(
 children: [
 PlanningPhaseHeader(
 title: 'UI/UX Design',
showNavigationButtons: false, onExportPdf: _exportPdf),
 Expanded(
 child: SingleChildScrollView(
 padding: EdgeInsets.all(padding),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (_isLoading) const LinearProgressIndicator(minHeight: 2),
 if (_isLoading) const SizedBox(height: 16),
 _buildHeader(isNarrow),
 const SizedBox(height: 16),
 _buildUXFrameworkGuide(),
 const SizedBox(height: 24),
 _buildJourneyRegister(),
 const SizedBox(height: 20),
 _buildInterfaceRegister(),
 const SizedBox(height: 20),
 _buildDesignTokenRegister(),
 const SizedBox(height: 20),
 _buildUsabilityRegister(),
 const SizedBox(height: 20),
 _buildReviewGatesPanel(),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Development Set Up',
 nextLabel: 'Next: Backend Design',
 onBack: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DevelopmentSetUpScreen())),
 onNext: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BackendDesignScreen())),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }

 // ─── Header ────────────────────────────────────────────────────────

 Widget _buildHeader(bool isNarrow) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: const Color(0xFFFFC812),
 borderRadius: BorderRadius.circular(6),
 ),
 child: const Text(
 'EXPERIENCE DESIGN',
 style: TextStyle(
 fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black),
 ),
 ),
 const SizedBox(height: 10),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: const [
 Text(
 'UI/UX Design',
 style: TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 SizedBox(height: 6),
 Text(
 'Manage user journeys, interface architecture, design system tokens, and usability validation for the project. '
 'Aligned with ISO 9241-210 Human-Centred Design, Nielsen Norman Group usability heuristics, '
 'and WCAG 2.1 accessibility standards. This register ensures experience design decisions remain '
 'traceable, testable, and reviewable throughout the design phase.',
 style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 ],
 );
 }

 bool get _showJourneys => true;
 bool get _showInterfaces => true;
 bool get _showDesignTokens => true;
 bool get _showUsability => true;
 bool get _showReviewGates => true;

 // ─── Stats Row ────────────────────────────────────────────────────

 Widget _buildStatsRow(bool isNarrow) {
 final journeyMapped =
 _journeys.where((j) => j.status == 'Mapped' || j.status == 'Validated').length;
 final interfaceFinal =
 _interfaces.where((i) => i.status == 'Final' || i.status == 'Prototype').length;
 final tokenReady =
 _designTokens.where((t) => t.status == 'Ready').length;
 final reviewPending =
 _reviewGates.where((g) => g.status == 'Pending' || g.status == 'In Review').length;

 final stats = [
 _StatCardData(
 '${_journeys.length}',
 'User Journeys',
 '$journeyMapped validated',
 const Color(0xFF0EA5E9),
 ),
 _StatCardData(
 '${_interfaces.length}',
 'Interfaces',
 '$interfaceFinal at prototype+',
 const Color(0xFF10B981),
 ),
 _StatCardData(
 '${_designTokens.length}',
 'Design Tokens',
 '$tokenReady ready',
 const Color(0xFFF97316),
 ),
 _StatCardData(
 '$reviewPending',
 'Pending Reviews',
 reviewPending > 0 ? 'Require attention' : 'All reviewed',
 const Color(0xFF6366F1),
 ),
 ];

 if (isNarrow) {
 return Column(
 children: [
 for (int i = 0; i < stats.length; i++) ...[
 SizedBox(width: double.infinity, child: _buildStatCard(stats[i])),
 if (i < stats.length - 1) const SizedBox(height: 12),
 ],
 ],
 );
 }

 return Row(
 children: [
 for (int i = 0; i < stats.length; i++) ...[
 Expanded(child: _buildStatCard(stats[i])),
 if (i < stats.length - 1) const SizedBox(width: 12),
 ],
 ],
 );
 }

 Widget _buildStatCard(_StatCardData data) {
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(data.value,
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: data.color)),
 const SizedBox(height: 6),
 Text(data.label,
 style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
 const SizedBox(height: 6),
 Text(data.supporting,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: data.color)),
 ],
 ),
 );
 }

 // ─── UX Framework Guide ────────────────────────────────────────────

 Widget _buildUXFrameworkGuide() {
 return ExecutionPanelShell(
 title: 'Experience design framework',
 subtitle:
 'Grounded in ISO 9241-210 Human-Centred Design for Interactive Systems, '
 'Nielsen Norman Group usability heuristics, WCAG 2.1 accessibility guidelines, '
 'and Google Material Design 3 principles.',
 collapsible: true,
 initiallyExpanded: false,
 headerIcon: Icons.auto_awesome_outlined,
 headerIconColor: const Color(0xFF6366F1),
 child: Column(
 children: [
 const Text(
 'Effective experience design ensures '
 'that user needs, task flows, and interaction patterns remain validated, consistent, '
 'and accessible across all touchpoints throughout the project lifecycle.',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 height: 1.5,
 ),
 ),
 const SizedBox(height: 18),
 _buildGuideCard(
 Icons.route_outlined,
 'User Journey Mapping',
 'Define end-to-end user journeys from entry to task completion. Map touchpoints, '
 'decision points, and emotional arcs. Validate journeys against user research '
 'and business objectives before investing in interface design.',
 const Color(0xFF2563EB),
 ),
 const SizedBox(height: 12),
 _buildGuideCard(
 Icons.widgets_outlined,
 'Interface Architecture',
 'Structure screens, navigation patterns, and information hierarchy. Define '
 'fidelity levels from wireframe to final prototype. Ensure consistent '
 'interaction patterns across responsive breakpoints and platforms.',
 const Color(0xFF10B981),
 ),
 const SizedBox(height: 12),
 _buildGuideCard(
 Icons.palette_outlined,
 'Design System & Tokens',
 'Establish shared visual language through design tokens: colors, typography, '
 'spacing, elevation, and motion. Tokens ensure consistency, enable '
 'theme switching, and bridge the design-to-development handoff gap.',
 const Color(0xFFF59E0B),
 ),
 const SizedBox(height: 12),
 _buildGuideCard(
 Icons.accessibility_new_outlined,
 'Usability & Accessibility',
 'Validate interfaces against WCAG 2.1 AA, Section 508, and platform-specific '
 'accessibility guidelines. Conduct usability testing with representative users. '
 'Track compliance status and remediation actions systematically.',
 const Color(0xFFEF4444),
 ),
 ],
 ),
 );
 }

 Widget _buildGuideCard(IconData icon, String title, String description, Color color) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: color.withOpacity(0.04),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: color.withOpacity(0.12)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 padding: const EdgeInsets.all(6),
 decoration: BoxDecoration(
 color: color.withOpacity(0.12),
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

 // ─── Panel Shell ────────────────────────────────────────────────

 Widget _buildPanelShell({
 required String title,
 required String subtitle,
 Widget? trailing,
 required Widget child,
 }) {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 12,
 offset: const Offset(0, 6),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Padding(
 padding: const EdgeInsets.all(20),
 child: Row(
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
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 subtitle,
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
 if (trailing != null) ...[
 const SizedBox(width: 12),
 trailing,
 ],
 ],
 ),
 ),
 const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
 child,
 ],
 ),
 );
 }

 // ─── User Journey Register ──────────────────────────────────────

 Widget _buildJourneyRegister() {
 if (!_showJourneys) return const SizedBox.shrink();
 return _buildPanelShell(
 title: 'User journey register',
 subtitle: 'Track user journeys, touchpoints, owners, and validation status aligned with ISO 9241-210 human-centred design process.',
 trailing: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CsvTableImportButton(
 compact: true,
 tableTitle: 'User Journeys',
 columns: [
 CsvColumnSpec(key: 'title', label: 'JOURNEY', required: true, hint: 'Journey name'),
 CsvColumnSpec(key: 'touchpoints', label: 'TOUCHPOINTS', hint: 'Key touchpoints'),
 CsvColumnSpec(key: 'owner', label: 'OWNER', hint: 'Journey owner'),
 CsvColumnSpec(key: 'priority', label: 'PRIORITY', allowedValues: ['Critical', 'High', 'Medium', 'Low'], defaultValue: 'Medium'),
 CsvColumnSpec(key: 'status', label: 'STATUS', allowedValues: ['Mapped', 'Draft', 'Planned', 'In progress', 'Validated', 'Deprecated'], defaultValue: 'Planned'),
 ],
 onImport: (rows) {
 setState(() {
 for (final row in rows) {
 _journeys.add(_JourneyRow(
 id: _newId(),
 title: row['title'] ?? '',
 description: '',
 touchpoints: row['touchpoints'] ?? '',
 owner: row['owner'] ?? '',
 priority: row['priority'] ?? 'Medium',
 status: row['status'] ?? 'Planned',
 ));
 }
 });
 _scheduleSave();
 },
 ),
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: () => _showJourneyDialog(),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add journey', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF475569),
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ],
 ),
 child: _journeys.isEmpty
 ? const Padding(
 padding: EdgeInsets.all(32),
 child: Center(child: Text('No journeys defined. Add a user journey to start tracking.', style: TextStyle(color: Color(0xFF64748B)))),
 )
 : Column(
 children: [
 _buildTableHeader([
 _ColDef('JOURNEY', flex: 4),
 _ColDef('TOUCHPOINTS', width: 130),
 _ColDef('OWNER', width: 110),
 _ColDef('PRIORITY', width: 90),
 _ColDef('STATUS', width: 100),
 _ColDef('', width: 100),
 ]),
 ...List.generate(_journeys.length, (i) {
 final row = _journeys[i];
 final journeyKey = 'journey_$i';
 final isRegenerating = _kazAiRegenerating[journeyKey] ?? false;
 return _buildTableRow(
 cells: [
 _CellDef(Expanded(
 flex: 4,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(row.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
 const SizedBox(height: 2),
 Text(row.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.4)),
 ],
 ),
 )),
 _CellDef(SizedBox(width: 130, child: Text(row.touchpoints, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))))),
 _CellDef(SizedBox(width: 130, child: Text(row.owner, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))))),
 _CellDef(SizedBox(width: 120, child: _buildPriorityTag(row.priority))),
 _CellDef(SizedBox(width: 130, child: _buildStatusTag(row.status))),
 _CellDef(SizedBox(
 width: 100,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(icon: isRegenerating ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFF59E0B)), tooltip: 'KAZ AI', onPressed: isRegenerating ? null : () => _kazRegenerateJourney(i), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
 const SizedBox(width: 4),
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
 IconButton(icon: const Icon(Icons.edit_outlined, size: 16), onPressed: () => _showJourneyDialog(existing: row), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
 IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)), onPressed: () => _confirmDelete(() => _deleteJourney(row)), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
 ],
 ),
 )),
 ],
 isLast: i == _journeys.length - 1,
 );
 }),
 ],
 ),
 );
 }

 // ─── Interface Architecture Register ─────────────────────────────

 Widget _buildInterfaceRegister() {
 if (!_showInterfaces) return const SizedBox.shrink();
 return _buildPanelShell(
 title: 'Interface architecture register',
 subtitle: 'Track interface areas, fidelity levels, and design states aligned with progressive design maturity from wireframe to production.',
 trailing: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CsvTableImportButton(
 compact: true,
 tableTitle: 'Interface Architecture',
 columns: [
 CsvColumnSpec(key: 'area', label: 'INTERFACE', required: true, hint: 'Interface area name'),
 CsvColumnSpec(key: 'fidelity', label: 'FIDELITY', allowedValues: ['Low-fi', 'Mid-fi', 'High-fi', 'Prototype', 'Production'], defaultValue: 'Low-fi'),
 CsvColumnSpec(key: 'owner', label: 'OWNER', hint: 'Interface owner'),
 CsvColumnSpec(key: 'status', label: 'STATE', allowedValues: ['Low-fi', 'Mid-fi', 'High-fi', 'Prototype', 'Production'], defaultValue: 'To define'),
 ],
 onImport: (rows) {
 setState(() {
 for (final row in rows) {
 _interfaces.add(_InterfaceRow(
 id: _newId(),
 area: row['area'] ?? '',
 purpose: '',
 fidelity: row['fidelity'] ?? 'Low',
 owner: row['owner'] ?? '',
 status: row['status'] ?? 'To define',
 ));
 }
 });
 _scheduleSave();
 },
 ),
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: () => _showInterfaceDialog(),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add interface', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF475569),
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ],
 ),
 child: _interfaces.isEmpty
 ? const Padding(
 padding: EdgeInsets.all(32),
 child: Center(child: Text('No interfaces defined. Add an interface area to start tracking.', style: TextStyle(color: Color(0xFF64748B)))),
 )
 : Column(
 children: [
 _buildTableHeader([
 _ColDef('INTERFACE', flex: 4),
 _ColDef('FIDELITY', width: 90),
 _ColDef('OWNER', width: 110),
 _ColDef('STATE', width: 110),
 _ColDef('', width: 100),
 ]),
 ...List.generate(_interfaces.length, (i) {
 final row = _interfaces[i];
 final interfaceKey = 'interface_$i';
 final isRegenerating = _kazAiRegenerating[interfaceKey] ?? false;
 return _buildTableRow(
 cells: [
 _CellDef(Expanded(
 flex: 4,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(row.area, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
 const SizedBox(height: 2),
 Text(row.purpose, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.4)),
 ],
 ),
 )),
 _CellDef(SizedBox(width: 120, child: _buildFidelityTag(row.fidelity))),
 _CellDef(SizedBox(width: 130, child: Text(row.owner, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))))),
 _CellDef(SizedBox(width: 130, child: _buildInterfaceStateTag(row.status))),
 _CellDef(SizedBox(
 width: 100,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(icon: isRegenerating ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFF59E0B)), tooltip: 'KAZ AI', onPressed: isRegenerating ? null : () => _kazRegenerateInterface(i), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
 const SizedBox(width: 4),
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
 IconButton(icon: const Icon(Icons.edit_outlined, size: 16), onPressed: () => _showInterfaceDialog(existing: row), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
 IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)), onPressed: () => _confirmDelete(() => _deleteInterface(row)), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
 ],
 ),
 )),
 ],
 isLast: i == _interfaces.length - 1,
 );
 }),
 ],
 ),
 );
 }

 // ─── Design System Tokens Register ────────────────────────────────

 Widget _buildDesignTokenRegister() {
 if (!_showDesignTokens) return const SizedBox.shrink();
 return _buildPanelShell(
 title: 'Design system tokens register',
 subtitle: 'Track design tokens, categories, and readiness status to maintain visual consistency and enable efficient design-to-development handoff.',
 trailing: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CsvTableImportButton(
 compact: true,
 tableTitle: 'Design System Tokens',
 columns: [
 CsvColumnSpec(key: 'title', label: 'TOKEN', required: true, hint: 'Token name'),
 CsvColumnSpec(key: 'category', label: 'CATEGORY', allowedValues: ['Color', 'Typography', 'Spacing', 'Elevation', 'Motion', 'Icon'], defaultValue: 'Color'),
 CsvColumnSpec(key: 'status', label: 'STATUS', allowedValues: ['Ready', 'Draft', 'In review', 'Planned', 'Deprecated'], defaultValue: 'Draft'),
 CsvColumnSpec(key: 'owner', label: 'OWNER', hint: 'Token owner'),
 ],
 onImport: (rows) {
 setState(() {
 for (final row in rows) {
 _designTokens.add(_DesignTokenRow(
 id: _newId(),
 title: row['title'] ?? '',
 description: '',
 category: row['category'] ?? 'Colors',
 status: row['status'] ?? 'Draft',
 owner: row['owner'] ?? '',
 ));
 }
 });
 _scheduleSave();
 },
 ),
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: () => _showDesignTokenDialog(),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add token', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF475569),
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ],
 ),
 child: _designTokens.isEmpty
 ? const Padding(
 padding: EdgeInsets.all(32),
 child: Center(child: Text('No design tokens defined. Add a token to start tracking.', style: TextStyle(color: Color(0xFF64748B)))),
 )
 : Column(
 children: [
 _buildTableHeader([
 _ColDef('TOKEN', flex: 4),
 _ColDef('CATEGORY', width: 110),
 _ColDef('OWNER', width: 130),
 _ColDef('STATUS', width: 90),
 _ColDef('', width: 100),
 ]),
 ...List.generate(_designTokens.length, (i) {
 final row = _designTokens[i];
 final tokenKey = 'token_$i';
 final isRegenerating = _kazAiRegenerating[tokenKey] ?? false;
 return _buildTableRow(
 cells: [
 _CellDef(Expanded(
 flex: 4,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(row.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
 const SizedBox(height: 2),
 Text(row.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.4)),
 ],
 ),
 )),
 _CellDef(SizedBox(width: 130, child: _buildCategoryTag(row.category))),
 _CellDef(SizedBox(width: 130, child: Text(row.owner, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))))),
 _CellDef(SizedBox(width: 120, child: _buildTokenStatusTag(row.status))),
 _CellDef(SizedBox(
 width: 100,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(icon: isRegenerating ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFF59E0B)), tooltip: 'KAZ AI', onPressed: isRegenerating ? null : () => _kazRegenerateDesignToken(i), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
 const SizedBox(width: 4),
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
 IconButton(icon: const Icon(Icons.edit_outlined, size: 16), onPressed: () => _showDesignTokenDialog(existing: row), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
 IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)), onPressed: () => _confirmDelete(() => _deleteDesignToken(row)), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
 ],
 ),
 )),
 ],
 isLast: i == _designTokens.length - 1,
 );
 }),
 ],
 ),
 );
 }

 // ─── Usability & Accessibility Register ─────────────────────────

 Widget _buildUsabilityRegister() {
 if (!_showUsability) return const SizedBox.shrink();
 return _buildPanelShell(
 title: 'Usability & accessibility validation',
 subtitle: 'Track WCAG compliance, usability benchmarks, and accessibility testing status aligned with ISO 9241 and Section 508 requirements.',
 trailing: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CsvTableImportButton(
 compact: true,
 tableTitle: 'Usability & Accessibility',
 columns: [
 CsvColumnSpec(key: 'criteria', label: 'CRITERIA', required: true, hint: 'Validation criteria'),
 CsvColumnSpec(key: 'description', label: 'DESCRIPTION', hint: 'Detailed description'),
 CsvColumnSpec(key: 'standard', label: 'STANDARD', hint: 'e.g. WCAG 2.1 AA'),
 CsvColumnSpec(key: 'status', label: 'STATUS', allowedValues: ['Pass', 'Fail', 'In progress', 'Not tested', 'Conditional'], defaultValue: 'Not tested'),
 CsvColumnSpec(key: 'owner', label: 'OWNER', hint: 'Criteria owner'),
 ],
 onImport: (rows) {
 setState(() {
 for (final row in rows) {
 _usabilityEntries.add(_UsabilityRow(
 id: _newId(),
 criteria: row['criteria'] ?? '',
 description: row['description'] ?? '',
 standard: row['standard'] ?? '',
 status: row['status'] ?? 'Not tested',
 owner: row['owner'] ?? '',
 notes: '',
 ));
 }
 });
 _scheduleSave();
 },
 ),
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: () => _showUsabilityDialog(),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add criteria', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF475569),
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ],
 ),
 child: _usabilityEntries.isEmpty
 ? const Padding(
 padding: EdgeInsets.all(32),
 child: Center(child: Text('No validation criteria defined. Add criteria to start tracking.', style: TextStyle(color: Color(0xFF64748B)))),
 )
 : Column(
 children: [
 _buildTableHeader([
 _ColDef('CRITERIA', flex: 4),
 _ColDef('STANDARD', width: 120),
 _ColDef('OWNER', width: 100),
 _ColDef('STATUS', width: 100),
 _ColDef('', width: 100),
 ]),
 ...List.generate(_usabilityEntries.length, (i) {
 final row = _usabilityEntries[i];
 final usabilityKey = 'usability_$i';
 final isRegenerating = _kazAiRegenerating[usabilityKey] ?? false;
 return _buildTableRow(
 cells: [
 _CellDef(Expanded(
 flex: 4,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(row.criteria, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
 const SizedBox(height: 2),
 Text(row.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.4)),
 ],
 ),
 )),
 _CellDef(SizedBox(width: 120, child: Text(row.standard, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))))),
 _CellDef(SizedBox(width: 130, child: Text(row.owner, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))))),
 _CellDef(SizedBox(width: 130, child: _buildUsabilityStatusTag(row.status))),
 _CellDef(SizedBox(
 width: 100,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(icon: isRegenerating ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFF59E0B)), tooltip: 'KAZ AI', onPressed: isRegenerating ? null : () => _kazRegenerateUsability(i), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
 const SizedBox(width: 4),
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
 IconButton(icon: const Icon(Icons.edit_outlined, size: 16), onPressed: () => _showUsabilityDialog(existing: row), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
 IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)), onPressed: () => _confirmDelete(() => _deleteUsability(row)), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
 ],
 ),
 )),
 ],
 isLast: i == _usabilityEntries.length - 1,
 );
 }),
 ],
 ),
 );
 }

 // ─── Design Review Gates ────────────────────────────────────────

 Widget _buildReviewGatesPanel() {
 if (!_showReviewGates) return const SizedBox.shrink();
 return _buildPanelShell(
 title: 'Design review gates',
 subtitle: 'Approval checkpoints aligned with ISO 9241-210 design review cycles. Each gate must be cleared before proceeding to the next design maturity level.',
 trailing: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CsvTableImportButton(
 compact: true,
 tableTitle: 'Review Gates',
 columns: [
 CsvColumnSpec(key: 'gate', label: 'GATE', required: true, hint: 'Gate name'),
 CsvColumnSpec(key: 'description', label: 'DESCRIPTION', hint: 'Gate description'),
 CsvColumnSpec(key: 'approver', label: 'APPROVER', hint: 'Gate approver'),
 CsvColumnSpec(key: 'department', label: 'DEPT', hint: 'Department'),
 CsvColumnSpec(key: 'priority', label: 'PRIORITY', allowedValues: ['Critical', 'High', 'Medium', 'Low'], defaultValue: 'High'),
 CsvColumnSpec(key: 'status', label: 'STATUS', allowedValues: ['Pending', 'In Review', 'Approved', 'Rejected', 'Waived'], defaultValue: 'Pending'),
 CsvColumnSpec(key: 'targetDate', label: 'TARGET DATE', hint: 'Target date', defaultValue: 'TBD'),
 ],
 onImport: (rows) {
 setState(() {
 for (final row in rows) {
 _reviewGates.add(_ReviewGateRow(
 id: _newId(),
 gate: row['gate'] ?? '',
 description: row['description'] ?? '',
 approver: row['approver'] ?? '',
 department: row['department'] ?? '',
 priority: row['priority'] ?? 'High',
 status: row['status'] ?? 'Pending',
 targetDate: row['targetDate'] ?? 'TBD',
 ));
 }
 });
 _scheduleSave();
 },
 ),
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: () => _showReviewGateDialog(),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add gate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF475569),
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ],
 ),
 child: _reviewGates.isEmpty
 ? const Padding(
 padding: EdgeInsets.all(32),
 child: Center(child: Text('No review gates defined. Add a gate to start tracking design reviews.', style: TextStyle(color: Color(0xFF64748B)))),
 )
 : Column(
 children: [
 _buildTableHeader([
 _ColDef('GATE', flex: 4),
 _ColDef('APPROVER', width: 120),
 _ColDef('PRIORITY', width: 80),
 _ColDef('STATUS', width: 100),
 _ColDef('', width: 100),
 ]),
 ...List.generate(_reviewGates.length, (i) {
 final row = _reviewGates[i];
 final gateKey = 'gate_$i';
 final isRegenerating = _kazAiRegenerating[gateKey] ?? false;
 return _buildTableRow(
 cells: [
 _CellDef(Expanded(
 flex: 4,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(row.gate, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
 const SizedBox(height: 2),
 Text(row.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.4)),
 ],
 ),
 )),
 _CellDef(SizedBox(width: 120, child: Text(row.approver, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))))),
 _CellDef(SizedBox(width: 110, child: _buildPriorityTag(row.priority))),
 _CellDef(SizedBox(width: 130, child: _buildReviewGateStatusTag(row.status))),
 _CellDef(SizedBox(
 width: 100,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(icon: isRegenerating ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFF59E0B)), tooltip: 'KAZ AI', onPressed: isRegenerating ? null : () => _kazRegenerateReviewGate(i), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
 const SizedBox(width: 4),
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
 IconButton(icon: const Icon(Icons.edit_outlined, size: 16), onPressed: () => _showReviewGateDialog(existing: row), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
 IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)), onPressed: () => _confirmDelete(() => _deleteReviewGate(row)), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
 ],
 ),
 )),
 ],
 isLast: i == _reviewGates.length - 1,
 );
 }),
 ],
 ),
 );
 }

 // ─── Table Building Helpers ────────────────────────────────────────

 Widget _buildTableHeader(List<_ColDef> columns) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
 child: Row(
 children: columns.map((col) {
 if (col.flex != null) {
 return Expanded(
 flex: col.flex!,
 child: Text(col.label,
 style: const TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8)),
 );
 }
 return SizedBox(
 width: col.width,
 child: Text(col.label,
 style: const TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center),
 );
 }).toList(),
 ),
 );
 }

 Widget _buildTableRow({required List<_CellDef> cells, required bool isLast}) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: BoxDecoration(
 border: isLast
 ? null
 : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: cells.map((cell) => cell.child).toList(),
 ),
 );
 }

 // ─── Status / Tag Builders ──────────────────────────────────────

 Widget _buildPriorityTag(String priority) {
 Color color;
 switch (priority) {
 case 'Critical':
 color = const Color(0xFFEF4444);
 break;
 case 'High':
 color = const Color(0xFFF97316);
 break;
 case 'Medium':
 color = const Color(0xFFF59E0B);
 break;
 default:
 color = const Color(0xFF6B7280);
 }
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: color.withOpacity(0.1),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(priority,
 style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
 );
 }

 Widget _buildStatusTag(String status) {
 Color color;
 switch (status) {
 case 'Mapped':
 case 'Validated':
 color = const Color(0xFF10B981);
 break;
 case 'In progress':
 color = const Color(0xFF0EA5E9);
 break;
 case 'Draft':
 color = const Color(0xFFF59E0B);
 break;
 case 'Deprecated':
 color = const Color(0xFF9CA3AF);
 break;
 default:
 color = const Color(0xFF6B7280);
 }
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: color.withOpacity(0.1),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(status,
 style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
 );
 }

 Widget _buildFidelityTag(String fidelity) {
 Color color;
 switch (fidelity) {
 case 'High':
 color = const Color(0xFF10B981);
 break;
 case 'Medium':
 color = const Color(0xFF0EA5E9);
 break;
 case 'Low':
 color = const Color(0xFFF59E0B);
 break;
 default:
 color = const Color(0xFF6B7280);
 }
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: color.withOpacity(0.1),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(fidelity,
 style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
 );
 }

 Widget _buildInterfaceStateTag(String state) {
 Color color;
 switch (state) {
 case 'Final':
 color = const Color(0xFF10B981);
 break;
 case 'Prototype':
 color = const Color(0xFF0EA5E9);
 break;
 case 'User flow map':
 color = const Color(0xFF8B5CF6);
 break;
 case 'Wireframe':
 color = const Color(0xFFF59E0B);
 break;
 case 'To define':
 color = const Color(0xFF9CA3AF);
 break;
 case 'Deprecated':
 color = const Color(0xFFEF4444);
 break;
 default:
 color = const Color(0xFF6B7280);
 }
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: color.withOpacity(0.1),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(state,
 style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
 );
 }

 Widget _buildCategoryTag(String category) {
 Color color;
 switch (category) {
 case 'Colors':
 color = const Color(0xFF8B5CF6);
 break;
 case 'Typography':
 color = const Color(0xFF2563EB);
 break;
 case 'Layout':
 color = const Color(0xFF10B981);
 break;
 case 'Effects':
 color = const Color(0xFFF59E0B);
 break;
 case 'Motion':
 color = const Color(0xFF0EA5E9);
 break;
 case 'Iconography':
 color = const Color(0xFFEF4444);
 break;
 default:
 color = const Color(0xFF6B7280);
 }
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: color.withOpacity(0.1),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(category,
 style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
 );
 }

 Widget _buildTokenStatusTag(String status) {
 Color color;
 switch (status) {
 case 'Ready':
 color = const Color(0xFF10B981);
 break;
 case 'In review':
 color = const Color(0xFF0EA5E9);
 break;
 case 'Draft':
 color = const Color(0xFFF59E0B);
 break;
 case 'Planned':
 color = const Color(0xFF8B5CF6);
 break;
 case 'Deprecated':
 color = const Color(0xFF9CA3AF);
 break;
 default:
 color = const Color(0xFF6B7280);
 }
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: color.withOpacity(0.1),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(status,
 style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
 );
 }

 Widget _buildUsabilityStatusTag(String status) {
 Color color;
 switch (status) {
 case 'Pass':
 color = const Color(0xFF10B981);
 break;
 case 'Fail':
 color = const Color(0xFFEF4444);
 break;
 case 'In progress':
 color = const Color(0xFF0EA5E9);
 break;
 case 'Conditional':
 color = const Color(0xFFF59E0B);
 break;
 case 'Not tested':
 color = const Color(0xFF9CA3AF);
 break;
 default:
 color = const Color(0xFF6B7280);
 }
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: color.withOpacity(0.1),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(status,
 style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
 );
 }

 Widget _buildReviewGateStatusTag(String status) {
 Color color;
 switch (status) {
 case 'Approved':
 color = const Color(0xFF10B981);
 break;
 case 'In Review':
 color = const Color(0xFF0EA5E9);
 break;
 case 'Pending':
 color = const Color(0xFFF59E0B);
 break;
 case 'Rejected':
 color = const Color(0xFFEF4444);
 break;
 case 'Waived':
 color = const Color(0xFF8B5CF6);
 break;
 case 'Not Started':
 color = const Color(0xFF9CA3AF);
 break;
 default:
 color = const Color(0xFF6B7280);
 }
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: color.withOpacity(0.1),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(status,
 style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
 );
 }

 // ─── CRUD Dialogs ─────────────────────────────────────────────────

 Future<void> _showJourneyDialog({_JourneyRow? existing}) async {
 final titleController = TextEditingController(text: existing?.title ?? '');
 final descController = TextEditingController(text: existing?.description ?? '');
 final touchpointsController = TextEditingController(text: existing?.touchpoints ?? '');
 final ownerController = TextEditingController(text: existing?.owner ?? '');
 String priority = existing?.priority ?? 'Medium';
 String status = existing?.status ?? 'Planned';

 final saved = await showDialog<bool>(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (context, setModalState) => AlertDialog(
 title: Text(existing == null ? 'Add user journey' : 'Edit user journey'),
 content: SizedBox(
 width: 560,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 _buildKazAiTextField(
 controller: titleController,
 labelText: 'Journey title',
 aiHint: 'user journey title',
 ),
 const SizedBox(height: 12),
 _buildKazAiTextField(
 controller: descController,
 labelText: 'Description',
 aiHint: 'user journey description',
 minLines: 2,
 maxLines: 4,
 ),
 const SizedBox(height: 12),
 _buildKazAiTextField(
 controller: touchpointsController,
 labelText: 'Touchpoints',
 aiHint: 'key touchpoints for this journey',
 ),
 const SizedBox(height: 12),
 _buildKazAiTextField(
 controller: ownerController,
 labelText: 'Owner',
 aiHint: 'journey owner role',
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(child: DropdownButtonFormField<String>(
 value: priority,
 items: ['Critical', 'High', 'Medium', 'Low'].map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
 onChanged: (v) { if (v != null) setModalState(() => priority = v); },
 decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
 )),
 const SizedBox(width: 12),
 Expanded(child: DropdownButtonFormField<String>(
 value: status,
 items: _journeyStatusOptions.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
 onChanged: (v) { if (v != null) setModalState(() => status = v); },
 decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
 )),
 ],
 ),
 ],
 ),
 ),
 actions: [
 TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
 ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(existing == null ? 'Add journey' : 'Save')),
 ],
 ),
 ),
 );
 if (saved != true) return;
 setState(() {
 if (existing == null) {
 _journeys.add(_JourneyRow(id: _newId(), title: titleController.text.trim(), description: descController.text.trim(), touchpoints: touchpointsController.text.trim(), owner: ownerController.text.trim(), priority: priority, status: status));
 } else {
 existing.title = titleController.text.trim();
 existing.description = descController.text.trim();
 existing.touchpoints = touchpointsController.text.trim();
 existing.owner = ownerController.text.trim();
 existing.priority = priority;
 existing.status = status;
 }
 });
 _scheduleSave();
 }

 void _deleteJourney(_JourneyRow row) {
 setState(() => _journeys.removeWhere((j) => j.id == row.id));
 _scheduleSave();
 }

 Future<void> _showInterfaceDialog({_InterfaceRow? existing}) async {
 final areaController = TextEditingController(text: existing?.area ?? '');
 final purposeController = TextEditingController(text: existing?.purpose ?? '');
 final ownerController = TextEditingController(text: existing?.owner ?? '');
 String fidelity = existing?.fidelity ?? 'Low';
 String status = existing?.status ?? 'To define';

 final saved = await showDialog<bool>(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (context, setModalState) => AlertDialog(
 title: Text(existing == null ? 'Add interface area' : 'Edit interface area'),
 content: SizedBox(
 width: 560,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 _buildKazAiTextField(
 controller: areaController,
 labelText: 'Area / screen name',
 aiHint: 'interface area name',
 ),
 const SizedBox(height: 12),
 _buildKazAiTextField(
 controller: purposeController,
 labelText: 'Purpose',
 aiHint: 'interface purpose',
 minLines: 2,
 maxLines: 4,
 ),
 const SizedBox(height: 12),
 _buildKazAiTextField(
 controller: ownerController,
 labelText: 'Owner',
 aiHint: 'interface owner role',
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(child: DropdownButtonFormField<String>(
 value: fidelity,
 items: ['High', 'Medium', 'Low'].map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
 onChanged: (v) { if (v != null) setModalState(() => fidelity = v); },
 decoration: const InputDecoration(labelText: 'Fidelity', border: OutlineInputBorder()),
 )),
 const SizedBox(width: 12),
 Expanded(child: DropdownButtonFormField<String>(
 value: status,
 items: _interfaceStateOptions.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
 onChanged: (v) { if (v != null) setModalState(() => status = v); },
 decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()),
 )),
 ],
 ),
 ],
 ),
 ),
 actions: [
 TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
 ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(existing == null ? 'Add interface' : 'Save')),
 ],
 ),
 ),
 );
 if (saved != true) return;
 setState(() {
 if (existing == null) {
 _interfaces.add(_InterfaceRow(id: _newId(), area: areaController.text.trim(), purpose: purposeController.text.trim(), owner: ownerController.text.trim(), fidelity: fidelity, status: status));
 } else {
 existing.area = areaController.text.trim();
 existing.purpose = purposeController.text.trim();
 existing.owner = ownerController.text.trim();
 existing.fidelity = fidelity;
 existing.status = status;
 }
 });
 _scheduleSave();
 }

 void _deleteInterface(_InterfaceRow row) {
 setState(() => _interfaces.removeWhere((i) => i.id == row.id));
 _scheduleSave();
 }

 Future<void> _showDesignTokenDialog({_DesignTokenRow? existing}) async {
 final titleController = TextEditingController(text: existing?.title ?? '');
 final descController = TextEditingController(text: existing?.description ?? '');
 final ownerController = TextEditingController(text: existing?.owner ?? '');
 String category = existing?.category ?? 'Colors';
 String status = existing?.status ?? 'Draft';

 final saved = await showDialog<bool>(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (context, setModalState) => AlertDialog(
 title: Text(existing == null ? 'Add design token' : 'Edit design token'),
 content: SizedBox(
 width: 560,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 _buildKazAiTextField(
 controller: titleController,
 labelText: 'Token name',
 aiHint: 'design token name',
 ),
 const SizedBox(height: 12),
 _buildKazAiTextField(
 controller: descController,
 labelText: 'Description / value',
 aiHint: 'design token description',
 minLines: 2,
 maxLines: 4,
 ),
 const SizedBox(height: 12),
 _buildKazAiTextField(
 controller: ownerController,
 labelText: 'Owner',
 aiHint: 'token owner role',
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(child: DropdownButtonFormField<String>(
 value: category,
 items: ['Colors', 'Typography', 'Layout', 'Effects', 'Motion', 'Iconography'].map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
 onChanged: (v) { if (v != null) setModalState(() => category = v); },
 decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
 )),
 const SizedBox(width: 12),
 Expanded(child: DropdownButtonFormField<String>(
 value: status,
 items: _tokenStatusOptions.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
 onChanged: (v) { if (v != null) setModalState(() => status = v); },
 decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
 )),
 ],
 ),
 ],
 ),
 ),
 actions: [
 TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
 ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(existing == null ? 'Add token' : 'Save')),
 ],
 ),
 ),
 );
 if (saved != true) return;
 setState(() {
 if (existing == null) {
 _designTokens.add(_DesignTokenRow(id: _newId(), title: titleController.text.trim(), description: descController.text.trim(), category: category, status: status, owner: ownerController.text.trim()));
 } else {
 existing.title = titleController.text.trim();
 existing.description = descController.text.trim();
 existing.category = category;
 existing.status = status;
 existing.owner = ownerController.text.trim();
 }
 });
 _scheduleSave();
 }

 void _deleteDesignToken(_DesignTokenRow row) {
 setState(() => _designTokens.removeWhere((t) => t.id == row.id));
 _scheduleSave();
 }

 Future<void> _showUsabilityDialog({_UsabilityRow? existing}) async {
 final criteriaController = TextEditingController(text: existing?.criteria ?? '');
 final descController = TextEditingController(text: existing?.description ?? '');
 final standardController = TextEditingController(text: existing?.standard ?? '');
 final ownerController = TextEditingController(text: existing?.owner ?? '');
 final notesController = TextEditingController(text: existing?.notes ?? '');
 String status = existing?.status ?? 'Not tested';

 final saved = await showDialog<bool>(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (context, setModalState) => AlertDialog(
 title: Text(existing == null ? 'Add validation criteria' : 'Edit validation criteria'),
 content: SizedBox(
 width: 560,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 _buildKazAiTextField(
 controller: criteriaController,
 labelText: 'Criteria',
 aiHint: 'usability criteria',
 ),
 const SizedBox(height: 12),
 _buildKazAiTextField(
 controller: descController,
 labelText: 'Description',
 aiHint: 'criteria description',
 minLines: 2,
 maxLines: 4,
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(child: _buildKazAiTextField(controller: standardController, labelText: 'Standard', aiHint: 'e.g. WCAG 2.1 AA')), 
 const SizedBox(width: 12),
 Expanded(child: DropdownButtonFormField<String>(
 value: status,
 items: _usabilityStatusOptions.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
 onChanged: (v) { if (v != null) setModalState(() => status = v); },
 decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
 )),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(child: _buildKazAiTextField(controller: ownerController, labelText: 'Owner', aiHint: 'criteria owner')), 
 ],
 ),
 const SizedBox(height: 12),
 _buildKazAiTextField(
 controller: notesController,
 labelText: 'Notes',
 aiHint: 'additional notes',
 minLines: 2,
 maxLines: 3,
 ),
 ],
 ),
 ),
 actions: [
 TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
 ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(existing == null ? 'Add criteria' : 'Save')),
 ],
 ),
 ),
 );
 if (saved != true) return;
 setState(() {
 if (existing == null) {
 _usabilityEntries.add(_UsabilityRow(id: _newId(), criteria: criteriaController.text.trim(), description: descController.text.trim(), standard: standardController.text.trim(), status: status, owner: ownerController.text.trim(), notes: notesController.text.trim()));
 } else {
 existing.criteria = criteriaController.text.trim();
 existing.description = descController.text.trim();
 existing.standard = standardController.text.trim();
 existing.status = status;
 existing.owner = ownerController.text.trim();
 existing.notes = notesController.text.trim();
 }
 });
 _scheduleSave();
 }

 void _deleteUsability(_UsabilityRow row) {
 setState(() => _usabilityEntries.removeWhere((u) => u.id == row.id));
 _scheduleSave();
 }

 Future<void> _showReviewGateDialog({_ReviewGateRow? existing}) async {
 final gateController = TextEditingController(text: existing?.gate ?? '');
 final descController = TextEditingController(text: existing?.description ?? '');
 final approverController = TextEditingController(text: existing?.approver ?? '');
 final deptController = TextEditingController(text: existing?.department ?? '');
 String priority = existing?.priority ?? 'High';
 String status = existing?.status ?? 'Pending';

 final saved = await showDialog<bool>(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (context, setModalState) => AlertDialog(
 title: Text(existing == null ? 'Add review gate' : 'Edit review gate'),
 content: SizedBox(
 width: 560,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 _buildKazAiTextField(
 controller: gateController,
 labelText: 'Gate name',
 aiHint: 'review gate name',
 ),
 const SizedBox(height: 12),
 _buildKazAiTextField(
 controller: descController,
 labelText: 'Description',
 aiHint: 'gate description',
 minLines: 2,
 maxLines: 4,
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(child: _buildKazAiTextField(controller: approverController, labelText: 'Approver', aiHint: 'approver role')),
 const SizedBox(width: 12),
 Expanded(child: _buildKazAiTextField(controller: deptController, labelText: 'Department', aiHint: 'department name')),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(child: DropdownButtonFormField<String>(
 value: priority,
 items: ['Critical', 'High', 'Medium', 'Low'].map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
 onChanged: (v) { if (v != null) setModalState(() => priority = v); },
 decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
 )),
 const SizedBox(width: 12),
 Expanded(child: DropdownButtonFormField<String>(
 value: status,
 items: _reviewGateStatusOptions.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
 onChanged: (v) { if (v != null) setModalState(() => status = v); },
 decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
 )),
 ],
 ),
 ],
 ),
 ),
 actions: [
 TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
 ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(existing == null ? 'Add gate' : 'Save')),
 ],
 ),
 ),
 );
 if (saved != true) return;
 setState(() {
 if (existing == null) {
 _reviewGates.add(_ReviewGateRow(id: _newId(), gate: gateController.text.trim(), description: descController.text.trim(), approver: approverController.text.trim(), department: deptController.text.trim(), priority: priority, status: status, targetDate: 'TBD'));
 } else {
 existing.gate = gateController.text.trim();
 existing.description = descController.text.trim();
 existing.approver = approverController.text.trim();
 existing.department = deptController.text.trim();
 existing.priority = priority;
 existing.status = status;
 }
 });
 _scheduleSave();
 }

 void _deleteReviewGate(_ReviewGateRow row) {
 setState(() => _reviewGates.removeWhere((g) => g.id == row.id));
 _scheduleSave();
 }

 // ─── KAZ AI TextField Builder for Dialogs ──────────────────────────────

 Widget _buildKazAiTextField({
 required TextEditingController controller,
 required String labelText,
 required String aiHint,
 int minLines = 1,
 int maxLines = 1,
 }) {
 final isGeneratingNotifier = ValueNotifier<bool>(false);
 return StatefulBuilder(
 builder: (context, setFieldState) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(labelText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
 ValueListenableBuilder<bool>(
 valueListenable: isGeneratingNotifier,
 builder: (_, isGen, __) => TextButton.icon(
 onPressed: isGen
 ? null
 : () async {
 isGeneratingNotifier.value = true;
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: labelText);
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, generate a "$aiHint" for the UI/UX design phase.\n\n'
 'Context:\n$ctx\n\n'
 'Provide 1-2 concise, specific sentences. Return ONLY the text content (no JSON, no markdown).',
 maxTokens: 200,
 temperature: 0.6,
 );
 final cleaned = result.trim();
 if (cleaned.isNotEmpty) {
 controller.text = cleaned;
 controller.selection = TextSelection.fromPosition(TextPosition(offset: cleaned.length));
 }
 } catch (e) {
 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KAZ AI failed: $e')));
 }
 isGeneratingNotifier.value = false;
 },
 icon: isGen
 ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
 : const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFF59E0B)),
 label: Text(isGen ? 'Generating...' : 'KAZ AI', style: const TextStyle(fontSize: 11, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600)),
 style: TextButton.styleFrom(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 minimumSize: Size.zero,
 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 4),
 VoiceTextField(
 controller: controller,
 minLines: minLines,
 maxLines: maxLines,
 decoration: const InputDecoration(
 border: OutlineInputBorder(),
 contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 ),
 ),
 ],
 );
 },
 );
 }

 void _confirmDelete(VoidCallback onDelete) {
 showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Confirm delete'),
 content: const Text('Are you sure you want to delete this item? This action cannot be undone.'),
 actions: [
 TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
 ElevatedButton(
 style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
 onPressed: () { Navigator.of(ctx).pop(); onDelete(); },
 child: const Text('Delete'),
 ),
 ],
 ),
 );
 }
}

// ─── Data Models ──────────────────────────────────────────────────────

class _JourneyRow {
 String id;
 String title;
 String description;
 String touchpoints;
 String owner;
 String priority;
 String status;

 _JourneyRow({
 required this.id,
 required this.title,
 required this.description,
 required this.touchpoints,
 required this.owner,
 required this.priority,
 required this.status,
 });

 Map<String, dynamic> toMap() => {
 'id': id, 'title': title, 'description': description,
 'touchpoints': touchpoints, 'owner': owner,
 'priority': priority, 'status': status,
 };

 static List<_JourneyRow> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((e) {
 final m = e as Map<String, dynamic>;
 return _JourneyRow(
 id: m['id'] ?? '', title: m['title'] ?? '',
 description: m['description'] ?? '', touchpoints: m['touchpoints'] ?? '',
 owner: m['owner'] ?? '', priority: m['priority'] ?? 'Medium',
 status: m['status'] ?? 'Planned',
 );
 }).toList();
 }
}

class _InterfaceRow {
 String id;
 String area;
 String purpose;
 String fidelity;
 String owner;
 String status;

 _InterfaceRow({
 required this.id, required this.area, required this.purpose,
 required this.fidelity, required this.owner, required this.status,
 });

 Map<String, dynamic> toMap() => {
 'id': id, 'area': area, 'purpose': purpose,
 'fidelity': fidelity, 'owner': owner, 'status': status,
 };

 static List<_InterfaceRow> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((e) {
 final m = e as Map<String, dynamic>;
 return _InterfaceRow(
 id: m['id'] ?? '', area: m['area'] ?? '',
 purpose: m['purpose'] ?? '', fidelity: m['fidelity'] ?? 'Low',
 owner: m['owner'] ?? '', status: m['status'] ?? 'To define',
 );
 }).toList();
 }
}

class _DesignTokenRow {
 String id;
 String title;
 String description;
 String category;
 String status;
 String owner;

 _DesignTokenRow({
 required this.id, required this.title, required this.description,
 required this.category, required this.status, required this.owner,
 });

 Map<String, dynamic> toMap() => {
 'id': id, 'title': title, 'description': description,
 'category': category, 'status': status, 'owner': owner,
 };

 static List<_DesignTokenRow> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((e) {
 final m = e as Map<String, dynamic>;
 return _DesignTokenRow(
 id: m['id'] ?? '', title: m['title'] ?? '',
 description: m['description'] ?? '', category: m['category'] ?? 'Colors',
 status: m['status'] ?? 'Draft', owner: m['owner'] ?? '',
 );
 }).toList();
 }
}

class _UsabilityRow {
 String id;
 String criteria;
 String description;
 String standard;
 String status;
 String owner;
 String notes;

 _UsabilityRow({
 required this.id, required this.criteria, required this.description,
 required this.standard, required this.status, required this.owner,
 required this.notes,
 });

 Map<String, dynamic> toMap() => {
 'id': id, 'criteria': criteria, 'description': description,
 'standard': standard, 'status': status, 'owner': owner, 'notes': notes,
 };

 static List<_UsabilityRow> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((e) {
 final m = e as Map<String, dynamic>;
 return _UsabilityRow(
 id: m['id'] ?? '', criteria: m['criteria'] ?? '',
 description: m['description'] ?? '', standard: m['standard'] ?? '',
 status: m['status'] ?? 'Not tested', owner: m['owner'] ?? '',
 notes: m['notes'] ?? '',
 );
 }).toList();
 }
}

class _ReviewGateRow {
 String id;
 String gate;
 String description;
 String approver;
 String department;
 String priority;
 String status;
 String targetDate;

 _ReviewGateRow({
 required this.id, required this.gate, required this.description,
 required this.approver, required this.department, required this.priority,
 required this.status, required this.targetDate,
 });

 Map<String, dynamic> toMap() => {
 'id': id, 'gate': gate, 'description': description,
 'approver': approver, 'department': department,
 'priority': priority, 'status': status, 'targetDate': targetDate,
 };

 static List<_ReviewGateRow> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((e) {
 final m = e as Map<String, dynamic>;
 return _ReviewGateRow(
 id: m['id'] ?? '', gate: m['gate'] ?? '',
 description: m['description'] ?? '', approver: m['approver'] ?? '',
 department: m['department'] ?? '', priority: m['priority'] ?? 'High',
 status: m['status'] ?? 'Pending', targetDate: m['targetDate'] ?? 'TBD',
 );
 }).toList();
 }
}

// ─── Utility Classes ──────────────────────────────────────────────────

class _StatCardData {
 final String value;
 final String label;
 final String supporting;
 final Color color;
 _StatCardData(this.value, this.label, this.supporting, this.color);
}

class _ColDef {
 final String label;
 final int? flex;
 final double? width;
 _ColDef(this.label, {this.flex, this.width});
}

class _CellDef {
 final Widget child;
 _CellDef(this.child);
}

class _Debouncer {
 Timer? _timer;
 void run(VoidCallback action) {
 _timer?.cancel();
 _timer = Timer(const Duration(milliseconds: 600), action);
 }
 void dispose() => _timer?.cancel();
}
