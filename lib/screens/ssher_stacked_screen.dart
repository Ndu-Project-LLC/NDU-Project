import 'package:flutter/material.dart';
import 'package:ndu_project/screens/ssher_add_safety_item_dialog.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/unified_phase_header.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/utils/ssher_export_helper.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/utils/web_utils_stub.dart'
 if (dart.library.html) 'package:ndu_project/utils/web_utils_web.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/widgets/inner_page_navigation_hint.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

enum _SsherCategory { safety, security, health, environment, regulatory }

String _categoryKey(_SsherCategory category) => category.name;

// ── Color Palette (matching HTML design tokens) ──
class _Palette {
 static const Color primary = Color(0xFF005BB3);
 static const Color primaryContainer = Color(0xFF0073DF);
 static const Color tertiaryFixedDim = Color(0xFFFABD00);
 static const Color tertiaryContainer = Color(0xFF946F00);
 static const Color onTertiaryFixed = Color(0xFF261A00);
 static const Color surface = Color(0xFFF7F9FB);
 static const Color surfaceBright = Color(0xFFF7F9FB);
 static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
 static const Color surfaceContainerLow = Color(0xFFF2F4F6);
 static const Color surfaceContainer = Color(0xFFECEEF0);
 static const Color surfaceContainerHigh = Color(0xFFE6E8EA);
 static const Color surfaceVariant = Color(0xFFE0E3E5);
 static const Color surfaceDim = Color(0xFFD8DADC);
 static const Color onBackground = Color(0xFF191C1E);
 static const Color onSurface = Color(0xFF191C1E);
 static const Color onSurfaceVariant = Color(0xFF414754);
 static const Color outline = Color(0xFF717786);
 static const Color outlineVariant = Color(0xFFC0C6D6);
 static const Color error = Color(0xFFBA1A1A);
 static const Color errorContainer = Color(0xFFFFDAD6);
 static const Color onErrorContainer = Color(0xFF93000A);
 static const Color primaryFixed = Color(0xFFD6E3FF);
 static const Color secondaryContainer = Color(0xFFE8DEF8);
 static const Color onSecondaryContainer = Color(0xFF1D192B);
 static const Color headerBg = Color(0xFF1C1B1B);
}

class SsherStackedScreen extends StatefulWidget {
 const SsherStackedScreen({super.key});

 @override
 State<SsherStackedScreen> createState() => _SsherStackedScreenState();
}

class _SsherStackedScreenState extends State<SsherStackedScreen>
 with SingleTickerProviderStateMixin {
 final Color _safetyAccent = const Color(0xFF34A853);
 final Color _securityAccent = const Color(0xFFEF5350);
 final Color _healthAccent = const Color(0xFF1E88E5);
 final Color _environmentAccent = const Color(0xFF2E7D32);
 final Color _regulatoryAccent = const Color(0xFF8E24AA);

 String _aiPlanSummary = '';
 bool _isGeneratingSummary = false;
 bool _summaryLoaded = false;
 bool _entriesGenerated = false;
 bool _isGeneratingEntries = false;

 late List<SsherEntry> _safetyEntries;
 late List<SsherEntry> _securityEntries;
 late List<SsherEntry> _healthEntries;
 late List<SsherEntry> _environmentEntries;
 late List<SsherEntry> _regulatoryEntries;

 _SsherCategory _selectedCategory = _SsherCategory.safety;
 late TabController _tabController;

 final TextEditingController _notesController = TextEditingController();
 final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

 @override
 void initState() {
 super.initState();
 _safetyEntries = [];
 _securityEntries = [];
 _healthEntries = [];
 _environmentEntries = [];
 _regulatoryEntries = [];
 _tabController = TabController(length: 5, vsync: this);
 _tabController.addListener(() {
 if (!_tabController.indexIsChanging) {
 setState(() {
 _selectedCategory = _SsherCategory.values[_tabController.index];
 });
 }
 });
 WidgetsBinding.instance.addPostFrameCallback((_) {
 _loadSavedEntries();
 _populateSsherSummaryFromAi();
 _loadNotes();
 });
 }

 @override
 void dispose() {
 _tabController.dispose();
 _notesController.dispose();
 super.dispose();
 }

 void _loadNotes() {
 final data = ProjectDataHelper.getData(context);
 final existingNotes = data.ssherData.screen2Data.trim();
 if (existingNotes.isNotEmpty) {
 _notesController.text = existingNotes;
 }
 }

 Future<void> _saveNotes() async {
 final notes = _notesController.text.trim();
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'ssher',
 showSnackbar: false,
 dataUpdater: (data) => data.copyWith(
 ssherData: data.ssherData.copyWith(screen2Data: notes),
 ),
 );
 }

 void _loadSavedEntries() {
 final ssherData = ProjectDataHelper.getData(context).ssherData;
 final entries = ssherData.entries;
 setState(() {
 _safetyEntries = entries
 .where((e) => e.category == _categoryKey(_SsherCategory.safety))
 .toList();
 _securityEntries = entries
 .where((e) => e.category == _categoryKey(_SsherCategory.security))
 .toList();
 _healthEntries = entries
 .where((e) => e.category == _categoryKey(_SsherCategory.health))
 .toList();
 _environmentEntries = entries
 .where((e) => e.category == _categoryKey(_SsherCategory.environment))
 .toList();
 _regulatoryEntries = entries
 .where((e) => e.category == _categoryKey(_SsherCategory.regulatory))
 .toList();
 });
 if (entries.isEmpty) {
 _populateSsherEntriesFromAi();
 } else {
 _entriesGenerated = true;
 }
 }

 Future<void> _populateSsherEntriesFromAi() async {
 if (_entriesGenerated || _isGeneratingEntries) return;
 if (_allEntries().isNotEmpty) {
 _entriesGenerated = true;
 return;
 }

 final projectData = ProjectDataHelper.getData(context);
 final contextText =
 ProjectDataHelper.buildFepContext(projectData, sectionLabel: 'SSHER');
 if (contextText.trim().isEmpty) {
 _entriesGenerated = true;
 return;
 }

 setState(() => _isGeneratingEntries = true);

 List<SsherEntry> generatedEntries = [];
 try {
 generatedEntries = await OpenAiServiceSecure()
 .generateSsherEntries(context: contextText, itemsPerCategory: 2);
 } catch (error) {
 debugPrint('SSHER entries AI call failed: $error');
 }

 if (!mounted) return;

 if (_allEntries().isNotEmpty) {
 setState(() => _isGeneratingEntries = false);
 _entriesGenerated = true;
 return;
 }

 final safety = <SsherEntry>[];
 final security = <SsherEntry>[];
 final health = <SsherEntry>[];
 final environment = <SsherEntry>[];
 final regulatory = <SsherEntry>[];

 for (final entry in generatedEntries) {
 switch (entry.category) {
 case 'safety':
 safety.add(entry);
 break;
 case 'security':
 security.add(entry);
 break;
 case 'health':
 health.add(entry);
 break;
 case 'environment':
 environment.add(entry);
 break;
 case 'regulatory':
 regulatory.add(entry);
 break;
 }
 }

 setState(() {
 _safetyEntries = safety;
 _securityEntries = security;
 _healthEntries = health;
 _environmentEntries = environment;
 _regulatoryEntries = regulatory;
 _isGeneratingEntries = false;
 });
 _entriesGenerated = true;
 await _saveEntries();
 }

 Future<void> _populateSsherSummaryFromAi() async {
 if (_summaryLoaded) return;
 final projectData = ProjectDataHelper.getData(context);
 final existingSummary = projectData.ssherData.screen1Data.trim();
 if (existingSummary.isNotEmpty) {
 setState(() {
 _aiPlanSummary = existingSummary;
 _summaryLoaded = true;
 });
 return;
 }

 final contextText =
 ProjectDataHelper.buildFepContext(projectData, sectionLabel: 'SSHER');
 if (contextText.trim().isEmpty) {
 setState(() => _summaryLoaded = true);
 return;
 }

 setState(() => _isGeneratingSummary = true);

 String summary = '';
 try {
 summary = await OpenAiServiceSecure()
 .generateSsherPlanSummary(context: contextText);
 } catch (error) {
 debugPrint('SSHER summary AI call failed: $error');
 }

 if (!mounted) return;

 final trimmedSummary = summary.trim();
 setState(() {
 _aiPlanSummary = trimmedSummary;
 _isGeneratingSummary = false;
 _summaryLoaded = true;
 });

 if (trimmedSummary.isEmpty) return;
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'ssher',
 showSnackbar: false,
 dataUpdater: (data) => data.copyWith(
 ssherData: data.ssherData.copyWith(screen1Data: trimmedSummary),
 ),
 );
 }

 Future<void> _retrySummaryGeneration() async {
 if (_isGeneratingSummary) return;
 setState(() {
 _summaryLoaded = false;
 _aiPlanSummary = '';
 });
 await _populateSsherSummaryFromAi();
 }

 String _buildSummaryPlaceholderText() {
 final entries = _allEntries();
 if (entries.isEmpty) {
 return 'No AI summary has been generated yet. Add SSHER notes or at least one item in any category, then tap "Try Generate Again".';
 }

 final categoryCoverage = <String>[
 if (_safetyEntries.isNotEmpty) 'Safety (${_safetyEntries.length})',
 if (_securityEntries.isNotEmpty) 'Security (${_securityEntries.length})',
 if (_healthEntries.isNotEmpty) 'Health (${_healthEntries.length})',
 if (_environmentEntries.isNotEmpty)
 'Environment (${_environmentEntries.length})',
 if (_regulatoryEntries.isNotEmpty)
 'Regulatory (${_regulatoryEntries.length})',
 ];

 final highRiskCount = entries
 .where((entry) => entry.riskLevel.trim().toLowerCase() == 'high')
 .length;
 final mediumRiskCount = entries
 .where((entry) => entry.riskLevel.trim().toLowerCase() == 'medium')
 .length;
 final topConcerns = entries
 .map((entry) => entry.concern.trim())
 .where((concern) => concern.isNotEmpty)
 .take(2)
 .toList();
 final coverageText = categoryCoverage.isEmpty
 ? 'tracked SSHER categories'
 : categoryCoverage.join(', ');

 final concernText = topConcerns.isEmpty
 ? ''
 : ' Current concerns: ${topConcerns.join(' | ')}.';

 return 'No AI summary has been generated yet. You currently have ${entries.length} SSHER items across $coverageText with $highRiskCount high-risk and $mediumRiskCount medium-risk entries.$concernText';
 }

 List<SsherEntry> _entriesForCategory(_SsherCategory category) {
 switch (category) {
 case _SsherCategory.safety:
 return _safetyEntries;
 case _SsherCategory.security:
 return _securityEntries;
 case _SsherCategory.health:
 return _healthEntries;
 case _SsherCategory.environment:
 return _environmentEntries;
 case _SsherCategory.regulatory:
 return _regulatoryEntries;
 }
 }

 List<SsherEntry> _allEntries() {
 return [
 ..._safetyEntries,
 ..._securityEntries,
 ..._healthEntries,
 ..._environmentEntries,
 ..._regulatoryEntries,
 ];
 }

 Future<void> _saveEntries() async {
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'ssher',
 dataUpdater: (data) => data.copyWith(
 ssherData: data.ssherData.copyWith(entries: _allEntries()),
 ),
 showSnackbar: false,
 );
 }

 Future<void> _deleteEntry(SsherEntry entry) async {
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Delete Item'),
 content: const Text('Are you sure you want to delete this item?'),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx, false),
 child: const Text('Cancel')),
 TextButton(
 onPressed: () => Navigator.pop(ctx, true),
 child: const Text('Delete', style: TextStyle(color: Colors.red))),
 ],
 ),
 );

 if (confirmed == true) {
 setState(() {
 if (entry.category == 'safety') {
 _safetyEntries.removeWhere((e) => e.id == entry.id);
 }
 if (entry.category == 'security') {
 _securityEntries.removeWhere((e) => e.id == entry.id);
 }
 if (entry.category == 'health') {
 _healthEntries.removeWhere((e) => e.id == entry.id);
 }
 if (entry.category == 'environment') {
 _environmentEntries.removeWhere((e) => e.id == entry.id);
 }
 if (entry.category == 'regulatory') {
 _regulatoryEntries.removeWhere((e) => e.id == entry.id);
 }
 });
 await _saveEntries();
 }
 }

 Future<void> _editEntry(SsherEntry entry) async {
 Color accentColor;
 IconData icon;
 String heading;
 String blurb;
 String concernLabel;

 switch (entry.category) {
 case 'safety':
 accentColor = _safetyAccent;
 icon = Icons.health_and_safety;
 heading = 'Edit Safety Item';
 blurb = 'Update details for the safety record.';
 concernLabel = 'Safety Concern';
 break;
 case 'security':
 accentColor = _securityAccent;
 icon = Icons.shield_outlined;
 heading = 'Edit Security Item';
 blurb = 'Update the security exposure details.';
 concernLabel = 'Security Concern';
 break;
 case 'health':
 accentColor = _healthAccent;
 icon = Icons.volunteer_activism_outlined;
 heading = 'Edit Health Item';
 blurb = 'Update the health-related concern.';
 concernLabel = 'Health Concern';
 break;
 case 'environment':
 accentColor = _environmentAccent;
 icon = Icons.eco_outlined;
 heading = 'Edit Environment Item';
 blurb = 'Update log of environmental impact.';
 concernLabel = 'Environmental Concern';
 break;
 case 'regulatory':
 accentColor = _regulatoryAccent;
 icon = Icons.gavel_outlined;
 heading = 'Edit Regulatory Item';
 blurb = 'Update compliance requirement details.';
 concernLabel = 'Regulatory Requirement';
 break;
 default:
 return;
 }

 final input = await showDialog<SsherItemInput>(
 context: context,
 builder: (ctx) => AddSsherItemDialog(
 accentColor: accentColor,
 icon: icon,
 heading: heading,
 blurb: blurb,
 concernLabel: concernLabel,
 saveButtonLabel: 'Save Changes',
 initialData: SsherItemInput(
 department: entry.department,
 teamMember: entry.teamMember,
 concern: entry.concern,
 riskLevel: entry.riskLevel,
 mitigation: entry.mitigation,
 ),
 ),
 );

 if (input == null) return;

 setState(() {
 entry.department = input.department;
 entry.teamMember = input.teamMember;
 entry.concern = input.concern;
 entry.riskLevel = input.riskLevel;
 entry.mitigation = input.mitigation;
 });
 await _saveEntries();
 }

 Future<void> _addEntry(_SsherCategory category, SsherItemInput input) async {
 final entry = SsherEntry(
 category: _categoryKey(category),
 department: input.department,
 teamMember: input.teamMember,
 concern: input.concern,
 riskLevel: input.riskLevel,
 mitigation: input.mitigation,
 );
 setState(() => _entriesForCategory(category).add(entry));
 await _saveEntries();
 }

 Future<void> _downloadAll() async {
 final isAdmin = await UserService.isCurrentUserAdmin();
 final hostname = getCurrentHostname() ?? '';
 final allowCsv = isAdmin && hostname.startsWith('admin.');

 final map = {
 'SAFETY': _safetyEntries,
 'SECURITY': _securityEntries,
 'HEALTH': _healthEntries,
 'ENVIRONMENT': _environmentEntries,
 'REGULATORY': _regulatoryEntries,
 };

 if (allowCsv) {
 final csv = SsherExportHelper.allEntriesToCsv(map);
 await SsherExportHelper.downloadCsv(csv, 'ssher_all_categories.csv');
 } else {
 await SsherExportHelper.exportAllToPdf(map);
 }
 }

 Color _accentForCategory(_SsherCategory cat) {
 switch (cat) {
 case _SsherCategory.safety:
 return _safetyAccent;
 case _SsherCategory.security:
 return _securityAccent;
 case _SsherCategory.health:
 return _healthAccent;
 case _SsherCategory.environment:
 return _environmentAccent;
 case _SsherCategory.regulatory:
 return _regulatoryAccent;
 }
 }

 IconData _iconForCategory(_SsherCategory cat) {
 switch (cat) {
 case _SsherCategory.safety:
 return Icons.health_and_safety;
 case _SsherCategory.security:
 return Icons.security;
 case _SsherCategory.health:
 return Icons.medical_services;
 case _SsherCategory.environment:
 return Icons.eco;
 case _SsherCategory.regulatory:
 return Icons.gavel;
 }
 }

 String _labelForCategory(_SsherCategory cat) {
 switch (cat) {
 case _SsherCategory.safety:
 return 'Safety';
 case _SsherCategory.security:
 return 'Security';
 case _SsherCategory.health:
 return 'Health';
 case _SsherCategory.environment:
 return 'Environment';
 case _SsherCategory.regulatory:
 return 'Regulatory';
 }
 }

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);

 return Scaffold(
 key: _scaffoldKey,
 backgroundColor: Colors.white,
 drawer: isMobile
 ? Drawer(
 width: AppBreakpoints.sidebarWidth(context),
 child: SafeArea(
 child: InitiationLikeSidebar(
 activeItemLabel: 'SSHER',
 showHeader: true,
 ),
 ),
 )
 : null,
 body: SafeArea(
 child: StreamBuilder<bool>(
 stream: UserService.watchAdminStatus(),
 builder: (context, snapshot) {
 final isAdmin = snapshot.data ?? false;
 final hostname = getCurrentHostname() ?? '';
 final allowCsv = isAdmin && hostname.startsWith('admin.');

 if (!isMobile) {
 return _buildDesktopLayout(allowCsv);
 }
 return _buildMobileLayout(allowCsv);
 }),
 ),
 );
 }

 // ── Desktop Layout ──
 Widget _buildDesktopLayout(bool allowCsv) {
 return Stack(
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(activeItemLabel: 'SSHER'),
 ),
 Expanded(
 child: Column(
 children: [
 PlanningPhaseHeader(
 title: 'SSHER',
 breadcrumbPhase: 'Planning Phase',
 breadcrumbTitle: 'SSHE Planning',
 onBack: () => PlanningPhaseNavigation.goToPrevious(context, 'ssher'),
 onForward: () => PlanningPhaseNavigation.goToNext(context, 'ssher'),
 onExportPdf: _exportPdf,
 ),
 Expanded(child: _buildMainContent(allowCsv)),
 ],
 ),
 ),
 ],
 ),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'SSHER',
 ),
 ),
 const KazAiChatBubble(),
 const AdminEditToggle(),
 ],
 );
 }

 // ── Mobile Layout (matches Risk Mitigation header pattern) ──
 Widget _buildMobileLayout(bool allowCsv) {
 return Column(
 children: [
 PlanningPhaseHeader(
 title: 'SSHER',
 breadcrumbPhase: 'Planning Phase',
 breadcrumbTitle: 'SSHE Planning',
 onBack: () => PlanningPhaseNavigation.goToPrevious(context, 'ssher'),
 onForward: () => PlanningPhaseNavigation.goToNext(context, 'ssher'), onExportPdf: _exportPdf),
 Expanded(child: _buildMainContent(allowCsv)),
 ],
 );
 }

 // ── Shared Main Content ──
 Widget _buildMainContent(bool allowCsv) {
 final isMobile = AppBreakpoints.isMobile(context);

 return SingleChildScrollView(
 padding: isMobile ? EdgeInsets.zero : const EdgeInsets.all(24),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // ── Breadcrumbs ──
 if (isMobile) _buildBreadcrumbs(),

 // ── Context Section (Title + PDF download) ──
 _buildContextSection(allowCsv, isMobile),

 // ── Notes Input ──
 _buildNotesSection(isMobile),

 // ── Phase Navigation (Scrollable Pill Tabs) ──
 _buildPhaseTabs(isMobile),

 // ── Inner Page Navigation Hint ──
 Padding(
 padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 0),
 child: InnerPageNavigationHint(
 pageId: 'ssher_stacked',
 pageTitle: 'SSHE Planning',
 description: 'Navigate between SSHE categories',
 currentSectionId: _selectedCategory.name,
 accentColor: _accentForCategory(_selectedCategory),
 sections: [
 InnerPageSection(id: _SsherCategory.safety.name, label: 'Safety', icon: Icons.health_and_safety, status: _selectedCategory == _SsherCategory.safety ? InnerPageSectionStatus.current : InnerPageSectionStatus.available, stepNumber: 1),
 InnerPageSection(id: _SsherCategory.security.name, label: 'Security', icon: Icons.security, status: _selectedCategory == _SsherCategory.security ? InnerPageSectionStatus.current : InnerPageSectionStatus.available, stepNumber: 2),
 InnerPageSection(id: _SsherCategory.health.name, label: 'Health', icon: Icons.medical_services, status: _selectedCategory == _SsherCategory.health ? InnerPageSectionStatus.current : InnerPageSectionStatus.available, stepNumber: 3),
 InnerPageSection(id: _SsherCategory.environment.name, label: 'Environment', icon: Icons.eco, status: _selectedCategory == _SsherCategory.environment ? InnerPageSectionStatus.current : InnerPageSectionStatus.available, stepNumber: 4),
 InnerPageSection(id: _SsherCategory.regulatory.name, label: 'Regulatory', icon: Icons.gavel, status: _selectedCategory == _SsherCategory.regulatory ? InnerPageSectionStatus.current : InnerPageSectionStatus.available, stepNumber: 5),
 ],
 onSectionTap: (sectionId) {
 final cat = _SsherCategory.values.firstWhere((c) => c.name == sectionId);
 setState(() => _selectedCategory = cat);
 _tabController.animateTo(cat.index);
 },
 ),
 ),

 // ── Data Cards Section ──
 _buildDataCardsSection(isMobile, allowCsv),

 // ── Save & Continue Button ──
 if (isMobile)
 _buildSaveContinueButton()
 else
 Padding(
 padding: const EdgeInsets.all(24),
 child: LaunchPhaseNavigation(
 backLabel: 'Back',
 nextLabel: 'Next',
 onBack: () =>
 PlanningPhaseNavigation.goToPrevious(context, 'ssher'),
 onNext: () =>
 PlanningPhaseNavigation.goToNext(context, 'ssher'),
 ),
 ),

 // Bottom padding for mobile
 if (isMobile) const SizedBox(height: 80),
 ],
 ),
 );
 }

 // ── Breadcrumbs ──
 Widget _buildBreadcrumbs() {
 final projectName =
 ProjectDataHelper.getData(context).projectName.trim();

 return Padding(
 padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
 child: SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: Row(
 children: [
 GestureDetector(
 onTap: () => Navigator.of(context).pop(),
 child: const Text(
 'Projects',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 letterSpacing: 0.05,
 color: _Palette.onSurfaceVariant,
 ),
 ),
 ),
 const Padding(
 padding: EdgeInsets.symmetric(horizontal: 2),
 child: Icon(Icons.chevron_right, size: 14, color: _Palette.onSurfaceVariant),
 ),
 GestureDetector(
 onTap: () => Navigator.of(context).pop(),
 child: Text(
 projectName.isNotEmpty ? projectName : 'Project',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 letterSpacing: 0.05,
 color: _Palette.onSurfaceVariant,
 ),
 ),
 ),
 const Padding(
 padding: EdgeInsets.symmetric(horizontal: 2),
 child: Icon(Icons.chevron_right, size: 14, color: _Palette.onSurfaceVariant),
 ),
 const Text(
 'SSHE Planning',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 letterSpacing: 0.05,
 color: _Palette.onBackground,
 ),
 ),
 ],
 ),
 ),
 );
 }

 // ── Context Section ──
 Widget _buildContextSection(bool allowCsv, bool isMobile) {
 return Padding(
 padding: EdgeInsets.fromLTRB(
 isMobile ? 16 : 0, isMobile ? 16 : 0, isMobile ? 16 : 0, 0),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 Expanded(
 child: Text(
 'SSHE Planning',
 style: TextStyle(
 fontSize: isMobile ? 24 : 28,
 fontWeight: FontWeight.w700,
 color: _Palette.onBackground,
 letterSpacing: isMobile ? -0.02 : 0,
 height: 1.2,
 ),
 ),
 ),
 const SizedBox(width: 12),
 if (isMobile)
 OutlinedButton.icon(
 onPressed: _downloadAll,
 icon: const Icon(Icons.download, size: 16),
 label: const Text('PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.05)),
 style: OutlinedButton.styleFrom(
 foregroundColor: _Palette.onSurface,
 side: const BorderSide(color: _Palette.outlineVariant),
 backgroundColor: _Palette.surfaceContainerLowest,
 padding:
 const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8)),
 minimumSize: Size.zero,
 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
 ),
 )
 else
 ElevatedButton.icon(
 onPressed: _downloadAll,
 icon: Icon(allowCsv
 ? Icons.download_for_offline
 : Icons.picture_as_pdf),
 label: Text(allowCsv
 ? 'Download All (CSV)'
 : 'Download All (PDF)'),
 style: ElevatedButton.styleFrom(
 backgroundColor: _Palette.primary,
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8)),
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 Text(
 'Identify and mitigate Safety, Security, Health, and Environmental risks for this project.',
 style: TextStyle(
 fontSize: isMobile ? 14 : 15,
 color: _Palette.onSurfaceVariant,
 height: 1.5,
 letterSpacing: 0.01,
 ),
 ),
 ],
 ),
 );
 }

 // ── Notes Section ──
 Widget _buildNotesSection(bool isMobile) {
 return Padding(
 padding: EdgeInsets.fromLTRB(
 isMobile ? 16 : 0, isMobile ? 16 : 16, isMobile ? 16 : 0, 0),
 child: Container(
 decoration: BoxDecoration(
 color: _Palette.surfaceContainerLowest,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: _Palette.surfaceVariant),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.05),
 blurRadius: 8,
 offset: const Offset(0, 1),
 ),
 ],
 ),
 child: Padding(
 padding: const EdgeInsets.all(16),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Icon(Icons.notes, size: 16, color: _Palette.outline),
 const SizedBox(width: 6),
 const Text(
 'General Notes',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 letterSpacing: 0.05,
 color: _Palette.onSurfaceVariant,
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 VoiceTextField(
 controller: _notesController,
 maxLines: 2,
 onChanged: (_) => _saveNotes(),
 decoration: InputDecoration(
 filled: true,
 fillColor: _Palette.surfaceBright,
 hintText:
 'Add any overarching safety notes for this project phase...',
 hintStyle: TextStyle(
 color: _Palette.outlineVariant,
 fontSize: 14,
 ),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(8),
 borderSide: BorderSide.none,
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(8),
 borderSide: BorderSide.none,
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(8),
 borderSide:
 const BorderSide(color: _Palette.primaryContainer, width: 1.5),
 ),
 contentPadding:
 const EdgeInsets.all(12),
 ),
 style: const TextStyle(
 fontSize: 14,
 color: _Palette.onSurface,
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }

 // ── Phase Navigation Tabs (Scrollable Pills) ──
 Widget _buildPhaseTabs(bool isMobile) {
 final categories = _SsherCategory.values;

 return Container(
 decoration: isMobile
 ? BoxDecoration(
 color: _Palette.surface,
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.02),
 blurRadius: 12,
 offset: const Offset(0, 4),
 ),
 ],
 )
 : null,
 padding: EdgeInsets.symmetric(
 horizontal: isMobile ? 16 : 0, vertical: isMobile ? 12 : 16),
 child: SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: Row(
 children: categories.map((cat) {
 final isSelected = cat == _selectedCategory;
 final icon = _iconForCategory(cat);
 final label = _labelForCategory(cat);

 return Padding(
 padding: const EdgeInsets.only(right: 8),
 child: Material(
 color: Colors.transparent,
 child: InkWell(
 onTap: () {
 setState(() => _selectedCategory = cat);
 _tabController.animateTo(cat.index);
 },
 borderRadius: BorderRadius.circular(24),
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 200),
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 8),
 decoration: BoxDecoration(
 color: isSelected
 ? _Palette.primaryContainer
 : _Palette.surfaceContainerLowest,
 borderRadius: BorderRadius.circular(24),
 border: isSelected
 ? null
 : Border.all(color: _Palette.outlineVariant),
 boxShadow: isSelected
 ? [
 BoxShadow(
 color:
 _Palette.primaryContainer.withValues(alpha: 0.3),
 blurRadius: 4,
 offset: const Offset(0, 2),
 ),
 ]
 : null,
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(icon,
 size: 16,
 color: isSelected
 ? Colors.white
 : _Palette.onSurfaceVariant,
 fill: isSelected ? 1.0 : 0.0),
 const SizedBox(width: 6),
 Text(
 label,
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: isSelected
 ? Colors.white
 : _Palette.onSurfaceVariant,
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 );
 }).toList(),
 ),
 ),
 );
 }

 // ── Data Cards Section ──
 Widget _buildDataCardsSection(bool isMobile, bool allowCsv) {
 final entries = _entriesForCategory(_selectedCategory);
 final accent = _accentForCategory(_selectedCategory);
 final catLabel = _labelForCategory(_selectedCategory);

 return Padding(
 padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 0, vertical: 8),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Section Header
 _buildSectionHeader(catLabel, entries.length, accent),

 const SizedBox(height: 16),

 // AI Summary (desktop only)
 if (!isMobile) ...[
 _buildAiSummaryDesktop(),
 const SizedBox(height: 16),
 ],

 // Loading state
 if (_isGeneratingEntries)
 _buildLoadingState()
 else if (entries.isEmpty)
 _buildEmptyState(accent, catLabel)
 else
 ...entries.map((entry) => Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: _buildEntryCard(entry, accent, isMobile),
 )),
 ],
 ),
 );
 }

 // ── Section Header ──
 Widget _buildSectionHeader(String label, int count, Color accent) {
 return Container(
 padding: const EdgeInsets.only(bottom: 12),
 decoration: const BoxDecoration(
 border: Border(
 bottom: BorderSide(color: _Palette.surfaceVariant),
 ),
 ),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Row(
 children: [
 Text(
 '$label Items',
 style: const TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: _Palette.onSurface,
 letterSpacing: -0.01,
 ),
 ),
 const SizedBox(width: 8),
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
 decoration: BoxDecoration(
 color: _Palette.surfaceContainerHigh,
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 '$count',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: _Palette.onSurfaceVariant,
 letterSpacing: 0.05,
 ),
 ),
 ),
 ],
 ),
 GestureDetector(
 onTap: () => _handleAddItem(),
 child: Row(
 children: [
 Icon(Icons.add_circle,
 size: 18, color: _Palette.primary),
 const SizedBox(width: 4),
 Text(
 'Add Item',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: _Palette.primary,
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 // ── Entry Card (matches HTML data card) ──
 Widget _buildEntryCard(SsherEntry entry, Color accent, bool isMobile) {
 final riskLevel = entry.riskLevel.trim().toLowerCase();
 final Color accentLineColor;
 final Color riskBadgeBg;
 final Color riskBadgeText;
 final IconData riskIcon;
 final String riskLabel;
 final Color avatarBg;
 final Color avatarText;

 switch (riskLevel) {
 case 'high':
 accentLineColor = _Palette.error;
 riskBadgeBg = _Palette.errorContainer;
 riskBadgeText = _Palette.onErrorContainer;
 riskIcon = Icons.warning;
 riskLabel = 'High Risk';
 avatarBg = _Palette.primaryContainer;
 avatarText = Colors.white;
 break;
 case 'medium':
 accentLineColor = _Palette.tertiaryFixedDim;
 riskBadgeBg = _Palette.tertiaryFixedDim;
 riskBadgeText = _Palette.tertiaryContainer;
 riskIcon = Icons.info;
 riskLabel = 'Medium Risk';
 avatarBg = _Palette.secondaryContainer;
 avatarText = _Palette.onSecondaryContainer;
 break;
 default:
 accentLineColor = _Palette.surfaceVariant;
 riskBadgeBg = _Palette.surfaceContainer;
 riskBadgeText = _Palette.onSurfaceVariant;
 riskIcon = Icons.check_circle;
 riskLabel = 'Low Risk';
 avatarBg = _Palette.surfaceDim;
 avatarText = _Palette.onSurfaceVariant;
 }

 // Get assignee initials
 final assigneeName = entry.teamMember.trim();
 final initials = assigneeName.isEmpty
 ? 'Un'
 : assigneeName
 .split(' ')
 .map((n) => n.isNotEmpty ? n[0].toUpperCase() : '')
 .take(2)
 .join();
 final isUnassigned = assigneeName.isEmpty;

 return Container(
 clipBehavior: Clip.hardEdge,
 decoration: BoxDecoration(
 color: _Palette.surfaceContainerLowest,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: _Palette.surfaceVariant),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.05),
 blurRadius: 12,
 offset: const Offset(0, 2),
 ),
 ],
 ),
 child: Stack(
 children: [
 // Left accent line
 Positioned(
 left: 0,
 top: 0,
 bottom: 0,
 child: Container(
 width: 4,
 decoration: BoxDecoration(
 color: accentLineColor,
 borderRadius: const BorderRadius.only(
 topLeft: Radius.circular(16),
 bottomLeft: Radius.circular(16),
 ),
 ),
 ),
 ),
 // Card content
 Padding(
 padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Top row: badges + more button
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Department + Risk level badges
 Wrap(
 spacing: 8,
 runSpacing: 6,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: _Palette.surfaceVariant,
 borderRadius: BorderRadius.circular(4),
 ),
 child: Text(
 entry.department.toUpperCase(),
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 letterSpacing: 0.08,
 color: _Palette.onSurfaceVariant,
 ),
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: riskBadgeBg,
 borderRadius: BorderRadius.circular(4),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(riskIcon, size: 13, color: riskBadgeText),
 const SizedBox(width: 4),
 Text(
 riskLabel.toUpperCase(),
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 letterSpacing: 0.08,
 color: riskBadgeText,
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 // Concern title
 Text(
 entry.concern.isNotEmpty
 ? entry.concern
 : 'Untitled Concern',
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.bold,
 color: _Palette.onBackground,
 height: 1.3,
 ),
 ),
 ],
 ),
 ),
 PopupMenuButton<String>(
 icon: const Icon(Icons.more_vert, color: _Palette.outline, size: 22),
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(),
 onSelected: (value) {
 if (value == 'edit') _editEntry(entry);
 if (value == 'delete') _deleteEntry(entry);
 },
 itemBuilder: (ctx) => [
 const PopupMenuItem(
 value: 'edit',
 child: Row(children: [
 Icon(Icons.edit_outlined, size: 18),
 SizedBox(width: 8),
 Text('Edit'),
 ])),
 const PopupMenuItem(
 value: 'delete',
 child: Row(children: [
 Icon(Icons.delete_outline,
 size: 18, color: Colors.red),
 SizedBox(width: 8),
 Text('Delete',
 style: TextStyle(color: Colors.red)),
 ])),
 ],
 ),
 ],
 ),

 const SizedBox(height: 14),

 // Mitigation Strategy
 const Text(
 'Mitigation Strategy',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 letterSpacing: 0.05,
 color: _Palette.outline,
 ),
 ),
 const SizedBox(height: 6),
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: _Palette.surfaceBright,
 borderRadius: BorderRadius.circular(8),
 border: Border.all(
 color: _Palette.surfaceVariant.withValues(alpha: 0.3)),
 ),
 child: Text(
 entry.mitigation.isNotEmpty
 ? entry.mitigation
 : 'No mitigation strategy defined.',
 style: TextStyle(
 fontSize: 14,
 color: entry.mitigation.isNotEmpty
 ? _Palette.onSurface
 : _Palette.outline,
 fontStyle: entry.mitigation.isNotEmpty
 ? FontStyle.normal
 : FontStyle.italic,
 height: 1.45,
 ),
 ),
 ),

 const SizedBox(height: 14),

 // Assignee row
 Container(
 padding: const EdgeInsets.only(top: 14),
 decoration: const BoxDecoration(
 border: Border(
 top: BorderSide(
 color: _Palette.surfaceVariant, width: 1.0),
 ),
 ),
 child: Row(
 children: [
 // Avatar circle
 Container(
 width: 32,
 height: 32,
 decoration: BoxDecoration(
 color: isUnassigned
 ? _Palette.surfaceDim
 : avatarBg,
 shape: BoxShape.circle,
 ),
 child: Center(
 child: Text(
 initials,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.bold,
 color: isUnassigned
 ? _Palette.onSurfaceVariant
 : avatarText,
 ),
 ),
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Assignee',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 letterSpacing: 0.05,
 color: _Palette.outline,
 ),
 ),
 const SizedBox(height: 1),
 Text(
 isUnassigned ? 'Unassigned' : assigneeName,
 style: TextStyle(
 fontSize: 13,
 color: isUnassigned
 ? _Palette.outline
 : _Palette.onSurface,
 fontStyle: isUnassigned
 ? FontStyle.italic
 : FontStyle.normal,
 ),
 ),
 ],
 ),
 ),
 if (isUnassigned)
 TextButton(
 onPressed: () => _editEntry(entry),
 style: TextButton.styleFrom(
 foregroundColor: _Palette.primary,
 padding: const EdgeInsets.symmetric(horizontal: 8),
 minimumSize: Size.zero,
 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
 ),
 child: const Text(
 'Assign',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 letterSpacing: 0.05,
 ),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 // ── Loading State ──
 Widget _buildLoadingState() {
 return Center(
 child: Padding(
 padding: const EdgeInsets.all(32),
 child: Column(
 children: [
 const CircularProgressIndicator(strokeWidth: 2),
 const SizedBox(height: 16),
 Text(
 'KAZ AI is generating SSHE entries...',
 style: TextStyle(color: _Palette.primary, fontSize: 14),
 ),
 ],
 ),
 ),
 );
 }

 // ── Empty State ──
 Widget _buildEmptyState(Color accent, String catLabel) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: _Palette.surfaceContainerLowest,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: _Palette.surfaceVariant.withValues(alpha: 0.5)),
 ),
 child: Column(
 children: [
 Icon(Icons.add_circle_outline, size: 40, color: accent.withValues(alpha: 0.5)),
 const SizedBox(height: 12),
 Text(
 'No $catLabel items yet',
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w600,
 color: _Palette.onSurfaceVariant,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 'Tap "Add Item" to create your first $catLabel entry, or let KAZ AI generate suggestions.',
 style: TextStyle(fontSize: 14, color: _Palette.outline),
 textAlign: TextAlign.center,
 ),
 const SizedBox(height: 16),
 ElevatedButton.icon(
 onPressed: () => _handleAddItem(),
 icon: const Icon(Icons.add, size: 18),
 label: Text('Add $catLabel Item'),
 style: ElevatedButton.styleFrom(
 backgroundColor: accent,
 foregroundColor: Colors.white,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8)),
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 12),
 ),
 ),
 ],
 ),
 );
 }

 // ── AI Summary (Desktop version) ──
 Widget _buildAiSummaryDesktop() {
 if (_isGeneratingSummary) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 color: _Palette.primary.withValues(alpha: 0.08),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: _Palette.primary.withValues(alpha: 0.3)),
 ),
 child: const Row(
 children: [
 SizedBox(
 height: 16,
 width: 16,
 child: CircularProgressIndicator(strokeWidth: 2)),
 SizedBox(width: 12),
 Expanded(
 child: Text('KAZ AI is preparing a tailored SSHER summary...',
 style: TextStyle(color: _Palette.primary, fontSize: 13))),
 ],
 ),
 );
 } else if (_aiPlanSummary.isNotEmpty) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 color: _Palette.surfaceContainerLow,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: _Palette.surfaceVariant),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('KAZ AI-generated SSHER Summary',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
 const SizedBox(height: 8),
 Text(_aiPlanSummary,
 style: TextStyle(
 color: _Palette.onSurfaceVariant,
 fontSize: 14,
 height: 1.5)),
 ],
 ),
 );
 } else {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 color: const Color(0xFFFFFBEB),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFFDE68A)),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Icon(Icons.auto_awesome_outlined,
 color: Color(0xFFB45309), size: 18),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'AI-generated SSHER Summary Unavailable',
 style: TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w600,
 color: Color(0xFF92400E)),
 ),
 const SizedBox(height: 6),
 Text(
 _buildSummaryPlaceholderText(),
 style: const TextStyle(
 fontSize: 13,
 height: 1.45,
 color: Color(0xFF92400E),
 ),
 ),
 const SizedBox(height: 12),
 OutlinedButton.icon(
 onPressed: _retrySummaryGeneration,
 icon: const Icon(Icons.refresh, size: 16),
 label: const Text('Try Generate Again'),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF92400E),
 side: const BorderSide(color: Color(0xFFF59E0B)),
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 10),
 textStyle: const TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600),
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

 // ── Save & Continue Button ──
 Widget _buildSaveContinueButton() {
 return Padding(
 padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
 child: SizedBox(
 width: double.infinity,
 height: 56,
 child: _ScaleOnTap(
 onTap: () =>
 PlanningPhaseNavigation.goToNext(context, 'ssher'),
 child: Container(
 decoration: BoxDecoration(
 color: _Palette.tertiaryFixedDim,
 borderRadius: BorderRadius.circular(12),
 boxShadow: [
 BoxShadow(
 color: _Palette.tertiaryFixedDim.withValues(alpha: 0.3),
 blurRadius: 8,
 offset: const Offset(0, 2),
 ),
 ],
 ),
 child: Material(
 color: Colors.transparent,
 borderRadius: BorderRadius.circular(12),
 child: InkWell(
 onTap: () =>
 PlanningPhaseNavigation.goToNext(context, 'ssher'),
 borderRadius: BorderRadius.circular(12),
 child: Center(
 child: Row(
 mainAxisAlignment: MainAxisAlignment.center,
 mainAxisSize: MainAxisSize.min,
 children: [
 const Text(
 'Save & Continue to Next Phase',
 style: TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w600,
 color: _Palette.onTertiaryFixed,
 ),
 ),
 const SizedBox(width: 8),
 const Icon(Icons.arrow_forward,
 size: 20, color: _Palette.onTertiaryFixed),
 ],
 ),
 ),
 ),
 ),
 ),
 ),
 ),
 );
 }

 // ── Handle Add Item ──
 Future<void> _handleAddItem() async {
 Color accentColor;
 IconData icon;
 String heading;
 String blurb;
 String concernLabel;

 switch (_selectedCategory) {
 case _SsherCategory.safety:
 accentColor = _safetyAccent;
 icon = Icons.health_and_safety;
 heading = 'Add Safety Item';
 blurb = 'Provide details for the new safety record.';
 concernLabel = 'Safety Concern';
 break;
 case _SsherCategory.security:
 accentColor = _securityAccent;
 icon = Icons.shield_outlined;
 heading = 'Add Security Item';
 blurb = 'Provide details for the new security record.';
 concernLabel = 'Security Concern';
 break;
 case _SsherCategory.health:
 accentColor = _healthAccent;
 icon = Icons.volunteer_activism_outlined;
 heading = 'Add Health Item';
 blurb = 'Provide details for the new health record.';
 concernLabel = 'Health Concern';
 break;
 case _SsherCategory.environment:
 accentColor = _environmentAccent;
 icon = Icons.eco_outlined;
 heading = 'Add Environment Item';
 blurb = 'Provide details for the new environmental record.';
 concernLabel = 'Environmental Concern';
 break;
 case _SsherCategory.regulatory:
 accentColor = _regulatoryAccent;
 icon = Icons.gavel_outlined;
 heading = 'Add Regulatory Item';
 blurb = 'Provide details for the new compliance record.';
 concernLabel = 'Regulatory Requirement';
 break;
 }

 final result = await showDialog<SsherItemInput>(
 context: context,
 builder: (ctx) => AddSsherItemDialog(
 accentColor: accentColor,
 icon: icon,
 heading: heading,
 blurb: blurb,
 concernLabel: concernLabel,
 ),
 );
 if (result == null) return;
 await _addEntry(_selectedCategory, result);
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'SSHER Stacked',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_ssher_stacked_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

// ── Scale-on-tap widget for press effect ──
class _ScaleOnTap extends StatefulWidget {
 final VoidCallback onTap;
 final Widget child;
 const _ScaleOnTap({required this.onTap, required this.child});
 @override
 State<_ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<_ScaleOnTap>
 with SingleTickerProviderStateMixin {
 late final AnimationController _ctrl;
 late final Animation<double> _scale;

 @override
 void initState() {
 super.initState();
 _ctrl = AnimationController(
 vsync: this, duration: const Duration(milliseconds: 100));
 _scale = Tween<double>(begin: 1.0, end: 0.95).animate(_ctrl);
 }

 @override
 void dispose() {
 _ctrl.dispose();
 super.dispose();
 }

 void _onTapDown(TapDownDetails _) => _ctrl.forward();
 void _onTapUp(TapUpDetails _) => _ctrl.reverse();
 void _onTapCancel() => _ctrl.reverse();

 @override
 Widget build(BuildContext context) {
 return GestureDetector(
 onTapDown: _onTapDown,
 onTapUp: _onTapUp,
 onTapCancel: _onTapCancel,
 onTap: widget.onTap,
 child: ScaleTransition(scale: _scale, child: widget.child),
 );
 }
}
