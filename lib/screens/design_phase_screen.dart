import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/screens/development_set_up_screen.dart';
import 'package:ndu_project/screens/requirements_implementation_screen.dart';
import 'package:ndu_project/screens/technical_alignment_screen.dart';
import 'package:ndu_project/screens/ui_ux_design_screen.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/widgets/architecture_canvas.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/architecture_service.dart';
import 'package:ndu_project/services/project_navigation_service.dart';
import 'package:ndu_project/utils/rich_text_editing_controller.dart';
import 'package:ndu_project/widgets/planning_ai_notes_card.dart';
import 'package:ndu_project/utils/phase_transition_helper.dart';
import 'package:ndu_project/widgets/whiteboard_canvas.dart';
import 'package:ndu_project/widgets/chart_builder_workspace.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';
import 'package:ndu_project/widgets/design_governance_dashboard.dart';
import 'package:ndu_project/services/design_phase_service.dart';
import 'package:ndu_project/models/design_phase_models.dart';
import 'package:ndu_project/widgets/design_readiness_card.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/web_utils.dart';
import 'package:ndu_project/utils/file_upload_helper.dart';
import 'package:ndu_project/widgets/design_phase_stable_shell.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';
class DesignPhaseScreen extends StatefulWidget {
 const DesignPhaseScreen(
 {super.key, this.activeItemLabel = 'Design Management'});

 final String activeItemLabel;

 static void open(
 BuildContext context, {
 String activeItemLabel = 'Design Management',
 String destinationCheckpoint = 'design_management',
 }) {
 PhaseTransitionHelper.pushPhaseAware(
 context: context,
 builder: (_) => DesignPhaseScreen(activeItemLabel: activeItemLabel),
 destinationCheckpoint: destinationCheckpoint,
 );
 }

 @override
 State<DesignPhaseScreen> createState() => _DesignPhaseScreenState();
}

enum DesignTool {
 architecture,
 whiteboard,
 chartBuilder,
 richText,
}

class _DesignPhaseScreenState extends State<DesignPhaseScreen> {
 // Dynamic Output Documents list
 final List<_DocItem> _outputDocs = [];

 // Architecture canvas state
 final List<ArchitectureNode> _nodes = [];
 final List<ArchitectureEdge> _edges = [];
 int _nodeCounter = 0;

 // Persistence state
 String? _projectId;
 bool _isSaving = false;
 DateTime? _lastSavedAt;
 Timer? _saveDebounce;

 // UI state
 bool _showProgressCard = true;

 DesignTool _activeTool = DesignTool.architecture;
 late final TextEditingController _richTextController;

 // Component Library for dragging into Output Docs OR directly onto canvas
 final List<_PaletteItem> _library = const [
 _PaletteItem('Service', Icons.settings_suggest, type: ArchitectureNodeType.service),
 _PaletteItem('API Gateway', Icons.cloud_sync_outlined, type: ArchitectureNodeType.api),
 _PaletteItem('Database', Icons.storage, type: ArchitectureNodeType.database),
 _PaletteItem('Message Queue', Icons.sync_alt, type: ArchitectureNodeType.queue),
 _PaletteItem('Cache', Icons.memory, type: ArchitectureNodeType.cache),
 _PaletteItem('Auth Service', Icons.verified_user, type: ArchitectureNodeType.auth),
 _PaletteItem('Mobile App', Icons.phone_android, type: ArchitectureNodeType.mobileApp),
 _PaletteItem('Web App', Icons.language, type: ArchitectureNodeType.webApp),
 _PaletteItem('Admin Portal', Icons.admin_panel_settings, type: ArchitectureNodeType.adminPortal),
 _PaletteItem('3rd-Party', Icons.link, type: ArchitectureNodeType.thirdParty),
 _PaletteItem('Load Balancer', Icons.shuffle, type: ArchitectureNodeType.loadBalancer),
 _PaletteItem('CDN', Icons.cloud_queue, type: ArchitectureNodeType.cdn),
 _PaletteItem('Object Storage', Icons.folder_outlined, type: ArchitectureNodeType.storage),
 _PaletteItem('Container', Icons.widgets, type: ArchitectureNodeType.container),
 _PaletteItem('IoT Device', Icons.device_hub, type: ArchitectureNodeType.iotDevice),
 ];

 ArchitectureNode _createNodeFromDrop(Offset pos, dynamic payload) {
 final label = payload is ArchitectureDragPayload
 ? payload.label
 : payload is _DocItem
 ? payload.title
 : payload.toString();
 final icon = payload is ArchitectureDragPayload
 ? payload.icon
 : payload is _DocItem
 ? payload.icon
 : null;
 final nodeType = payload is ArchitectureDragPayload
 ? payload.nodeType ?? ArchitectureNodeType.custom
 : ArchitectureNodeType.custom;
 return ArchitectureNode(
 id: 'n_${_nodeCounter++}',
 label: label,
 position: pos,
 nodeType: nodeType,
 icon: icon ?? nodeType.icon,
 );
 }

 DesignPhaseProgress? _progress;

 @override
 void initState() {
 super.initState();
 _richTextController = RichTextEditingController(
 text:
 '### Design Notes\n\nStart drafting your design narrative here. Use the toolbar above for quick formatting.',
 );
 WidgetsBinding.instance.addPostFrameCallback((_) async {
 final provider = ProjectDataInherited.maybeOf(context);
 final pid = provider?.projectData.projectId;
 if (pid != null && pid.isNotEmpty) {
 if (!mounted) return;
 setState(() => _projectId = pid);
 _loadPersisted(pid);
 _loadProgress(pid);
 // Save this page as the last visited page for the project
 await ProjectNavigationService.instance.saveLastPage(pid, 'design');
 }
 });
 }

 
 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Design Phase',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['design_phase_screen'] ?? 'No data recorded.'),
 ],
 );
 }
Future<void> _loadProgress(String projectId) async {
 try {
 final progress =
 await DesignPhaseService.instance.getDesignProgress(projectId);
 if (mounted) setState(() => _progress = progress);
 } catch (e) {
 debugPrint('Error loading design progress: $e');
 }
 }

 Widget _buildDesignDashboard(double padding) {
 if (_progress == null) return const SizedBox.shrink();

 // Use the new Readiness Card
 // Note: _progress is technically DesignPhaseProgress (typedef for DesignReadinessModel)
 return Padding(
 padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
 child: DesignReadinessCard(readiness: _progress!),
 );
 }

 @override
 void dispose() {
 _saveDebounce?.cancel();
 _richTextController.dispose();
 super.dispose();
 }

 Future<void> _loadPersisted(String projectId) async {
 final data = await ArchitectureService.load(projectId);
 if (data == null) return;
 if (!mounted) return;
 try {
 final docs = (data['outputDocs'] as List?) ?? const [];
 final nodes = (data['nodes'] as List?) ?? const [];
 final edges = (data['edges'] as List?) ?? const [];

 setState(() {
 _outputDocs
 ..clear()
 ..addAll(docs.map((e) {
 final m = Map<String, dynamic>.from(e as Map);
 return _DocItem(
 m['title']?.toString() ?? 'Untitled',
 icon: _iconFromCode(
 m['iconCode'] as int?, m['iconFont']?.toString()),
 color: _colorFromHex(m['color']?.toString()),
 );
 }));

 _nodes
 ..clear()
 ..addAll(nodes.map((e) {
 final m = Map<String, dynamic>.from(e as Map);
 final id = m['id']?.toString() ?? 'n_${_nodeCounter++}';
 final dx = (m['x'] is num) ? (m['x'] as num).toDouble() : 0.0;
 final dy = (m['y'] is num) ? (m['y'] as num).toDouble() : 0.0;
 return ArchitectureNode(
 id: id,
 label: m['label']?.toString() ?? 'Node',
 position: Offset(dx, dy),
 color: _colorFromHex(m['color']?.toString()) ?? Colors.white,
 icon: _iconFromCode(
 m['iconCode'] as int?, m['iconFont']?.toString()),
 );
 }));
 _nodeCounter = _nodes.fold<int>(0, (acc, n) {
 final parts = n.id.split('_');
 final maybe = int.tryParse(parts.isNotEmpty ? parts.last : '');
 return maybe != null && maybe > acc ? maybe : acc;
 }) +
 1;

 _edges
 ..clear()
 ..addAll(edges.map((e) {
 final m = Map<String, dynamic>.from(e as Map);
 return ArchitectureEdge(
 fromId: m['from']?.toString() ?? '',
 toId: m['to']?.toString() ?? '',
 label: m['label']?.toString() ?? '',
 );
 }));
 });
 } catch (e, st) {
 debugPrint('⚠️ Failed to parse architecture doc: $e\n$st');
 }
 }

 void _scheduleSave() {
 if (_projectId == null || _projectId!.isEmpty) return;
 _saveDebounce?.cancel();
 setState(() => _isSaving = true);
 _saveDebounce = Timer(const Duration(milliseconds: 600), () async {
 try {
 final payload = {
 'outputDocs': _outputDocs
 .map((d) => {
 'title': d.title,
 'iconCode': d.icon?.codePoint,
 'iconFont': d.icon?.fontFamily,
 'color': _hexFromColor(d.color),
 })
 .toList(),
 'nodes': _nodes
 .map((n) => {
 'id': n.id,
 'label': n.label,
 'x': n.position.dx,
 'y': n.position.dy,
 'iconCode': n.icon?.codePoint,
 'iconFont': n.icon?.fontFamily,
 'color': _hexFromColor(n.color),
 })
 .toList(),
 'edges': _edges
 .map((e) => {
 'from': e.fromId,
 'to': e.toId,
 'label': e.label,
 })
 .toList(),
 };
 await ArchitectureService.save(_projectId!, payload);
 if (mounted) {
 setState(() {
 _isSaving = false;
 _lastSavedAt = DateTime.now();
 });
 }
 } catch (e, st) {
 debugPrint('❌ Failed to save architecture: $e\n$st');
 if (mounted) setState(() => _isSaving = false);
 }
 });
 }

 static Color? _colorFromHex(String? hex) {
 if (hex == null || hex.isEmpty) return null;
 try {
 final buffer = StringBuffer();
 var value = hex.replaceFirst('#', '').toUpperCase();
 if (value.length == 6) buffer.write('FF');
 buffer.write(value);
 final intColor = int.parse(buffer.toString(), radix: 16);
 return Color(intColor);
 } catch (e) {
 debugPrint('Color parse error: $e');
 return null;
 }
 }

 static String? _hexFromColor(Color? c) {
 if (c == null) return null;
 final argb = c.toARGB32();
 return '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
 }

 // Keep icon resolution to a known set so web builds can tree-shake icons safely.
 static final Map<int, IconData> _iconLookup = <int, IconData>{
 Icons.settings_suggest.codePoint: Icons.settings_suggest,
 Icons.cloud_sync_outlined.codePoint: Icons.cloud_sync_outlined,
 Icons.storage.codePoint: Icons.storage,
 Icons.sync_alt.codePoint: Icons.sync_alt,
 Icons.memory.codePoint: Icons.memory,
 Icons.verified_user.codePoint: Icons.verified_user,
 Icons.phone_android.codePoint: Icons.phone_android,
 Icons.language.codePoint: Icons.language,
 Icons.admin_panel_settings.codePoint: Icons.admin_panel_settings,
 Icons.link.codePoint: Icons.link,
 Icons.insert_drive_file_outlined.codePoint:
 Icons.insert_drive_file_outlined,
 Icons.widgets_outlined.codePoint: Icons.widgets_outlined,
 };

 static IconData? _iconFromCode(int? codePoint, String? fontFamily) {
 if (codePoint == null) return null;
 if (fontFamily != null && fontFamily != 'MaterialIcons') return null;
 return _iconLookup[codePoint];
 }

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 final padding = isMobile ? 16.0 : 24.0;
 if (widget.activeItemLabel == 'Design Management') {
 return _buildStableManagementScreen(padding);
 }
 if (kIsWeb) {
 return _buildMinimalWebScreen(padding);
 }

 return ResponsiveScaffold(
 activeItemLabel: widget.activeItemLabel,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: Column(
 children: [
 PlanningPhaseHeader(
 title: 'Design Planning', onExportPdf: _exportPdf),
 Expanded(
 child: SingleChildScrollView(
 padding: EdgeInsets.all(padding),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Move Design Dashboard inside scroll view
 if (_projectId != null) ...[
 _buildDesignDashboard(padding),
 const SizedBox(height: 16),
 ],
 const PlanningAiNotesCard(
 title: 'Notes',
 sectionLabel: 'Design',
 noteKey: 'planning_design_notes',
 checkpoint: 'design',
 description:
 'Summarize design goals, artifacts, and key decisions.',
 ),
 const SizedBox(height: 24),

 Text(
 'Collaborative workspace for Waterfall design and documentation',
 style: TextStyle(fontSize: 14, color: Colors.grey[600]),
 ),
 const SizedBox(height: 24),
 if (isMobile)
 Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 const Text(
 'Design Management',
 style: TextStyle(
 fontSize: 18, fontWeight: FontWeight.bold),
 ),
 const Text(
 'Develop project design documentation',
 style: TextStyle(fontSize: 12, color: Colors.grey),
 ),
 const SizedBox(height: 16),
 _buildStrategySection(),
 const SizedBox(height: 24),
 _buildManagementCards(),
 const SizedBox(height: 24),
 _buildEditorSection(),
 ],
 )
 else
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Design Management',
 style: TextStyle(
 fontSize: 18, fontWeight: FontWeight.bold),
 ),
 const Text(
 'Develop project design documentation',
 style: TextStyle(fontSize: 12, color: Colors.grey),
 ),
 const SizedBox(height: 16),
 _buildStrategySection(),
 const SizedBox(height: 24),
 _buildManagementCards(),
 const SizedBox(height: 24),
 _buildEditorSection(),
 ],
 ),
 ],
 ),
 ),
 ),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Design overview',
 nextLabel: 'Next: Requirements Implementation',
 onBack: () => Navigator.of(context).maybePop(),
 onNext: () => Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const RequirementsImplementationScreen()),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildStableManagementScreen(double padding) {
 return DesignPhaseStableShell(
 activeLabel: 'Design Management',
 breadcrumbPhase: 'Design Phase',
 breadcrumbTitle: 'Design Management',
 onItemSelected: _openStableDesignItem,
 child: Container(
 color: const Color(0xFFF7F9FB),
 child: ListView(
 padding: EdgeInsets.all(padding),
 children: [
 // ── 1. Design Readiness Progress Card ──────────────────────────
 if (_showProgressCard) _buildReadinessProgressCard(),
 if (_showProgressCard) const SizedBox(height: 20),

 // ── 2. Notes Section ───────────────────────────────────────────
 _buildStableNotesCard(),
 const SizedBox(height: 24),

 // ── 3. Design Management Heading ───────────────────────────────
 const Text(
 'Design Management',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 'Develop project design documentation',
 style: TextStyle(fontSize: 13, color: Colors.grey[600]),
 ),
 const SizedBox(height: 20),

 // ── 4. Design Strategy & Governance ────────────────────────────
 _buildStableStrategySection(),
 const SizedBox(height: 24),

 // ── 5. Two-Column Cards: Design Documents + Design Tools ───────
 _buildStableDocumentToolCards(),
 const SizedBox(height: 24),

 // ── 6. System Architecture Section ─────────────────────────────
 _buildStableSystemArchitecture(),
 const SizedBox(height: 24),

 // ── 7. Design Tools & Rich Text Editor ─────────────────────────
 _buildStableDesignToolsEditor(),
 const SizedBox(height: 24),

 // ── 7.5 Collaborators Section ──────────────────────────────────
 _buildStableCollaboratorsCard(),
 const SizedBox(height: 24),

 // ── 8. Navigation Buttons ──────────────────────────────────────
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
 onPressed: () => Navigator.of(context).maybePop(),
 child: const Text('Back: Design overview'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) =>
 const RequirementsImplementationScreen(),
 ),
 ),
 child: const Text('Next: Requirements Implementation'),
 ),
 ],
 ),
 ),
 ],
 ),
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

 // ── 1. Design Readiness Progress Card ──────────────────────────────────
 Widget _buildReadinessProgressCard() {
 final provider = ProjectDataInherited.maybeOf(context);
 final projectData = provider?.projectData ?? ProjectDataModel();
 final data = _resolvedManagementData(projectData);
 final readiness = _progress ?? data.readiness;
 final score = (readiness.overallScore * 100).toInt();
 final scoreColor = score >= 80
 ? const Color(0xFF16A34A)
 : score >= 50
 ? const Color(0xFFD97706)
 : const Color(0xFFDC2626);
 final label = score >= 90
 ? 'Ready for Execution'
 : score >= 70
 ? 'Nearing Completion'
 : score >= 40
 ? 'In Progress'
 : 'Early Stages';

 return Stack(
 children: [
 Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: const Color(0xFFFEF2F2),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFFECACA)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'PROJECT PROGRESS',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Colors.grey[600],
 letterSpacing: 0.8,
 ),
 ),
 const SizedBox(height: 6),
 Row(
 crossAxisAlignment: CrossAxisAlignment.end,
 children: [
 Text(
 '$score%',
 style: TextStyle(
 fontSize: 40,
 fontWeight: FontWeight.w900,
 color: scoreColor,
 height: 1.0,
 ),
 ),
 const SizedBox(width: 12),
 Padding(
 padding: const EdgeInsets.only(bottom: 6),
 child: Text(
 label,
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: scoreColor,
 ),
 ),
 ),
 ],
 ),
 ],
 ),
 Container(
 width: 80,
 height: 80,
 decoration: BoxDecoration(
 color: Colors.white,
 shape: BoxShape.circle,
 border: Border.all(color: const Color(0xFFFECACA), width: 3),
 ),
 child: Stack(
 alignment: Alignment.center,
 children: [
 SizedBox(
 width: 80,
 height: 80,
 child: CircularProgressIndicator(
 value: readiness.overallScore,
 strokeWidth: 6,
 backgroundColor: const Color(0xFFFEE2E2),
 valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
 ),
 ),
 Icon(
 score >= 90
 ? Icons.rocket_launch_rounded
 : score >= 70
 ? Icons.check_circle_outline_rounded
 : score >= 40
 ? Icons.construction_rounded
 : Icons.design_services_rounded,
 size: 28,
 color: scoreColor,
 ),
 ],
 ),
 ),
 ],
 ),
 if (readiness.missingItems.isNotEmpty) ...[
 const SizedBox(height: 14),
 Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFFECACA)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Icon(Icons.warning_amber_rounded,
 size: 16, color: Colors.red[700]),
 const SizedBox(width: 8),
 Text(
 'Blocking items',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Colors.red[800],
 ),
 ),
 ],
 ),
 const SizedBox(height: 6),
 ...readiness.missingItems.take(3).map((item) => Padding(
 padding: const EdgeInsets.only(bottom: 2),
 child: Text(
 '- $item',
 style: TextStyle(
 fontSize: 12, color: Colors.red[800]),
 ),
 )),
 if (readiness.missingItems.length > 3)
 Text(
 '+ ${readiness.missingItems.length - 3} more items',
 style: TextStyle(
 fontSize: 11,
 color: Colors.red[600],
 fontStyle: FontStyle.italic),
 ),
 ],
 ),
 ),
 ],
 ],
 ),
 ),
 // Close button in top-right corner
 Positioned(
 top: 8,
 right: 8,
 child: Material(
 color: Colors.transparent,
 child: InkWell(
 onTap: () => setState(() => _showProgressCard = false),
 borderRadius: BorderRadius.circular(16),
 child: Container(
 width: 28,
 height: 28,
 decoration: BoxDecoration(
 color: Colors.white.withOpacity(0.8),
 shape: BoxShape.circle,
 ),
 child: Icon(
 Icons.close,
 size: 16,
 color: Colors.grey[600],
 ),
 ),
 ),
 ),
 ),
 ],
 );
 }

 // ── 4. Design Strategy & Governance (desktop 3-column) ─────────────────
 Widget _buildStableStrategySection() {
 final provider = ProjectDataInherited.maybeOf(context);
 if (provider == null) return const SizedBox.shrink();

 final projectData = provider.projectData;
 final managementData = _resolvedManagementData(projectData);

 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: AppSemanticColors.border),
 boxShadow: const [
 BoxShadow(
 color: Color(0x08000000),
 blurRadius: 12,
 offset: Offset(0, 4),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 const Text(
 'Design Strategy & Governance',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7E6),
 borderRadius: BorderRadius.circular(6),
 ),
 child: const Text(
 'Required',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFFD97706),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 4),
 Text(
 'Define the methodology, industry, and execution approach for your project.',
 style: TextStyle(fontSize: 12, color: Colors.grey[600]),
 ),
 const SizedBox(height: 20),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: _buildStableDropdownBlock<ProjectMethodology>(
 label: 'Methodology',
 value: managementData.methodology,
 items: ProjectMethodology.values
 .map((m) => DropdownMenuItem(
 value: m,
 child: Text(m.name.toUpperCase(),
 style: const TextStyle(fontSize: 13)),
 ))
 .toList(),
 onChanged: (v) {
 if (v != null) _updateMethodology(v);
 },
 helper: _getMethodologyDescription(managementData.methodology),
 ),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: _buildStableDropdownBlock<ProjectIndustry>(
 label: 'Industry',
 value: managementData.industry,
 items: ProjectIndustry.values
 .map((i) => DropdownMenuItem(
 value: i,
 child: Text(
 i.name.substring(0, 1).toUpperCase() +
 i.name.substring(1),
 style: const TextStyle(fontSize: 13),
 ),
 ))
 .toList(),
 onChanged: (v) {
 if (v != null) _updateIndustry(v);
 },
 ),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: _buildStableDropdownBlock<ExecutionStrategy>(
 label: 'Execution Strategy',
 value: managementData.executionStrategy,
 items: ExecutionStrategy.values
 .map((s) => DropdownMenuItem(
 value: s,
 child: Text(
 s.name
 .replaceAll(RegExp(r'(?<!^)(?=[A-Z])'), ' ')
 .toUpperCase(),
 style: const TextStyle(fontSize: 13),
 ),
 ))
 .toList(),
 onChanged: (v) {
 if (v != null) _updateStrategy(v);
 },
 ),
 ),
 ],
 ),
 ],
 ),
 );
 }

 Widget _buildStableDropdownBlock<T>({
 required String label,
 required T value,
 required List<DropdownMenuItem<T>> items,
 required ValueChanged<T?> onChanged,
 String? helper,
 }) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Colors.grey[700],
 ),
 ),
 const SizedBox(height: 8),
 DropdownButtonFormField<T>(
 value: value,
 decoration: InputDecoration(
 isDense: true,
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
 border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: BorderSide(color: Colors.grey.shade300),
 ),
 ),
 items: items,
 onChanged: onChanged,
 ),
 if (helper != null) ...[
 const SizedBox(height: 6),
 Text(
 helper,
 style: TextStyle(fontSize: 11, color: Colors.grey[500]),
 ),
 ],
 ],
 );
 }

 // ── 5. Two-Column Cards: Design Documents + Design Tools ───────────────
 Widget _buildStableDocumentToolCards() {
 final provider = ProjectDataInherited.maybeOf(context);
 final documents = provider?.projectData.designManagementData?.documents ?? [];
 final tools = provider?.projectData.designManagementData?.tools ?? [];

 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Design Documents Card
 Expanded(
 child: Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7E6),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFBFDBFE)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x08000000),
 blurRadius: 12,
 offset: Offset(0, 4),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7E6),
 borderRadius: BorderRadius.circular(10),
 ),
 child: const Icon(
 Icons.insert_drive_file_outlined,
 size: 20,
 color: Color(0xFFB45309),
 ),
 ),
 const SizedBox(width: 10),
 const Expanded(
 child: Text(
 'Design Documents',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ),
 if (documents.isNotEmpty)
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
 decoration: BoxDecoration(
 color: const Color(0xFFB45309).withOpacity(0.12),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Text(
 '${documents.length}',
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFFB45309),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 if (documents.isEmpty)
 Center(
 child: Padding(
 padding: const EdgeInsets.symmetric(vertical: 16),
 child: Column(
 children: [
 Icon(
 Icons.folder_open_outlined,
 size: 48,
 color: const Color(0xFFB45309).withOpacity(0.3),
 ),
 const SizedBox(height: 12),
 Text(
 'No documents added',
 style: TextStyle(
 fontSize: 13,
 color: const Color(0xFFB45309).withOpacity(0.6),
 fontWeight: FontWeight.w500,
 ),
 ),
 ],
 ),
 ),
 )
 else
 ...documents.map((doc) => Container(
 margin: const EdgeInsets.only(bottom: 8),
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFBFDBFE)),
 ),
 child: Row(
 children: [
 Container(
 width: 32,
 height: 32,
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7E6),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Icon(
 doc.hasUploadedFile
 ? Icons.attach_file
 : Icons.description_outlined,
 size: 16,
 color: const Color(0xFFB45309),
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 doc.title,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827),
 ),
 overflow: TextOverflow.ellipsis,
 ),
 Row(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(
 color: const Color(0xFFB45309).withOpacity(0.1),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(
 doc.type,
 style: const TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w600,
 color: Color(0xFFB45309),
 ),
 ),
 ),
 if (doc.hasUploadedFile) ...[
 const SizedBox(width: 6),
 Text(
 doc.uploadedFileName!,
 style: TextStyle(
 fontSize: 10,
 color: Colors.grey.shade500,
 ),
 overflow: TextOverflow.ellipsis,
 ),
 ],
 ],
 ),
 ],
 ),
 ),
 if (doc.url != null && doc.url!.isNotEmpty)
 IconButton(
 icon: const Icon(Icons.open_in_new,
 size: 16, color: Color(0xFFB45309)),
 onPressed: () {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Opening ${doc.url}')),
 );
 },
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline,
 size: 16, color: Color(0xFFEF4444)),
 onPressed: () {
 final currentData =
 provider?.projectData.designManagementData ??
 DesignManagementData();
 currentData.documents.removeWhere((d) => d.id == doc.id);
 provider?.updateProjectData(
 provider.projectData
 .copyWith(designManagementData: currentData),
 );
 FileUploadHelper.deleteUploadedFile(doc.uploadedStoragePath);
 },
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 ),
 ],
 ),
 )),
 const SizedBox(height: 12),
 SizedBox(
 width: double.infinity,
 child: ElevatedButton.icon(
 onPressed: _addOutputDoc,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFB45309),
 foregroundColor: Colors.white,
 elevation: 0,
 padding: const EdgeInsets.symmetric(vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(10),
 ),
 ),
 icon: const Icon(Icons.add, size: 18),
 label: const Text(
 'Add Document',
 style: TextStyle(
 fontSize: 13, fontWeight: FontWeight.w600),
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 const SizedBox(width: 20),
 // Design Tools Card
 Expanded(
 child: Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7E6),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFBFDBFE)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x08000000),
 blurRadius: 12,
 offset: Offset(0, 4),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7E6),
 borderRadius: BorderRadius.circular(10),
 ),
 child: const Icon(
 Icons.build_outlined,
 size: 20,
 color: Color(0xFFB45309),
 ),
 ),
 const SizedBox(width: 10),
 const Expanded(
 child: Text(
 'Design Tools',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ),
 if (tools.isNotEmpty)
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
 decoration: BoxDecoration(
 color: const Color(0xFFB45309).withOpacity(0.12),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Text(
 '${tools.length}',
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFFB45309),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 if (tools.isEmpty)
 Center(
 child: Padding(
 padding: const EdgeInsets.symmetric(vertical: 16),
 child: Column(
 children: [
 Icon(
 Icons.handyman_outlined,
 size: 48,
 color: const Color(0xFFB45309).withOpacity(0.3),
 ),
 const SizedBox(height: 12),
 Text(
 'No tools configured',
 style: TextStyle(
 fontSize: 13,
 color: const Color(0xFFB45309).withOpacity(0.6),
 fontWeight: FontWeight.w500,
 ),
 ),
 ],
 ),
 ),
 )
 else
 ...tools.map((tool) => Container(
 margin: const EdgeInsets.only(bottom: 8),
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFBFDBFE)),
 ),
 child: Row(
 children: [
 Container(
 width: 32,
 height: 32,
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7E6),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Icon(
 tool.hasUploadedFile
 ? Icons.attach_file
 : (tool.isInternal ? Icons.dns : Icons.public),
 size: 16,
 color: const Color(0xFFB45309),
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 tool.name,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827),
 ),
 overflow: TextOverflow.ellipsis,
 ),
 Row(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(
 color: const Color(0xFFB45309).withOpacity(0.1),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(
 tool.isInternal ? 'Internal' : 'External',
 style: const TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w600,
 color: Color(0xFFB45309),
 ),
 ),
 ),
 if (tool.hasUploadedFile) ...[
 const SizedBox(width: 6),
 Text(
 tool.uploadedFileName!,
 style: TextStyle(
 fontSize: 10,
 color: Colors.grey.shade500,
 ),
 overflow: TextOverflow.ellipsis,
 ),
 ],
 ],
 ),
 ],
 ),
 ),
 if (tool.url.isNotEmpty)
 IconButton(
 icon: const Icon(Icons.open_in_new,
 size: 16, color: Color(0xFFB45309)),
 onPressed: () {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Opening ${tool.url}')),
 );
 },
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline,
 size: 16, color: Color(0xFFEF4444)),
 onPressed: () {
 final currentData =
 provider?.projectData.designManagementData ??
 DesignManagementData();
 currentData.tools.removeWhere((t) => t.id == tool.id);
 provider?.updateProjectData(
 provider.projectData
 .copyWith(designManagementData: currentData),
 );
 FileUploadHelper.deleteUploadedFile(tool.uploadedStoragePath);
 },
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 ),
 ],
 ),
 )),
 const SizedBox(height: 12),
 SizedBox(
 width: double.infinity,
 child: ElevatedButton.icon(
 onPressed: _showAddToolUploadDialog,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFB45309),
 foregroundColor: Colors.white,
 elevation: 0,
 padding: const EdgeInsets.symmetric(vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(10),
 ),
 ),
 icon: const Icon(Icons.add, size: 18),
 label: const Text(
 'Add Tool',
 style: TextStyle(
 fontSize: 13, fontWeight: FontWeight.w600),
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 ],
 );
 }

 // ── 6. System Architecture Section ─────────────────────────────────────
 Widget _buildStableSystemArchitecture() {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: AppSemanticColors.border),
 boxShadow: const [
 BoxShadow(
 color: Color(0x08000000),
 blurRadius: 12,
 offset: Offset(0, 4),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // ── Header Bar ──
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
 border: Border(bottom: BorderSide(color: const Color(0xFFE4E7EC))),
 ),
 child: Row(
 children: [
 Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7E6),
 borderRadius: BorderRadius.circular(10),
 ),
 child: const Icon(
 Icons.account_tree_outlined,
 size: 20,
 color: Color(0xFFD97706),
 ),
 ),
 const SizedBox(width: 10),
 const Text(
 'System Architecture',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(width: 10),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: const Color(0xFFF0FDF4),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(
 '${_nodes.length} nodes',
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFF16A34A),
 ),
 ),
 ),
 const SizedBox(width: 6),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7E6),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(
 '${_edges.length} connections',
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFFD97706),
 ),
 ),
 ),
 const Spacer(),
 // Save status
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: _isSaving
 ? const Color(0xFFFFFBEB)
 : _lastSavedAt != null
 ? const Color(0xFFF0FDF4)
 : const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(
 _isSaving
 ? Icons.sync_rounded
 : _lastSavedAt != null
 ? Icons.check_circle_outline
 : Icons.cloud_outlined,
 size: 13,
 color: _isSaving
 ? const Color(0xFFD97706)
 : _lastSavedAt != null
 ? const Color(0xFF16A34A)
 : Colors.grey[500],
 ),
 const SizedBox(width: 4),
 Text(
 _isSaving
 ? 'Saving...'
 : _lastSavedAt != null
 ? 'Saved'
 : 'Ready',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: _isSaving
 ? const Color(0xFFD97706)
 : _lastSavedAt != null
 ? const Color(0xFF16A34A)
 : Colors.grey[500],
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 // Action buttons
 _archHeaderButton(
 icon: Icons.auto_fix_high,
 label: 'Auto Layout',
 onTap: _autoLayoutNodes,
 ),
 const SizedBox(width: 6),
 _archHeaderButton(
 icon: Icons.layers_clear_outlined,
 label: 'Clear',
 color: const Color(0xFFEF4444),
 onTap: _nodes.isEmpty ? null : _clearArchitectureCanvas,
 ),
 ],
 ),
 ),

 // ── Main Editor Area: Component Library + Canvas ──
 SizedBox(
 height: 520,
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 // ── Left: Component Library Sidebar ──
 Container(
 width: 210,
 decoration: BoxDecoration(
 color: const Color(0xFFFAFBFD),
 border: Border(right: BorderSide(color: const Color(0xFFE4E7EC))),
 borderRadius: const BorderRadius.only(
 bottomLeft: Radius.circular(16),
 ),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Library header
 Padding(
 padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
 child: Row(
 children: [
 Icon(Icons.widgets_outlined, size: 16, color: Colors.grey[700]),
 const SizedBox(width: 6),
 Text(
 'Component Library',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Colors.grey[800],
 ),
 ),
 ],
 ),
 ),
 // Search hint
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 14),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: const Color(0xFFE4E7EC)),
 ),
 child: Row(
 children: [
 Icon(Icons.search, size: 14, color: Colors.grey[400]),
 const SizedBox(width: 6),
 Text(
 'Drag or click + to add',
 style: TextStyle(fontSize: 11, color: Colors.grey[400]),
 ),
 ],
 ),
 ),
 ),
 const SizedBox(height: 8),
 // Component list
 Expanded(
 child: ListView.builder(
 padding: const EdgeInsets.symmetric(horizontal: 8),
 itemCount: _library.length,
 itemBuilder: (context, i) {
 final item = _library[i];
 final payload = ArchitectureDragPayload(
 item.label,
 icon: item.icon,
 color: item.type.bgColor,
 nodeType: item.type,
 );
 return LongPressDraggable<ArchitectureDragPayload>(
 data: payload,
 dragAnchorStrategy: pointerDragAnchorStrategy,
 feedback: Material(
 color: Colors.transparent,
 child: _componentTile(item, isDragging: true, showAddButton: false),
 ),
 child: _componentTile(
 item,
 showAddButton: true,
 onAddToCanvas: () {
 final centerPos = Offset(
 200 + (_nodes.length * 40).toDouble(),
 200 + (_nodes.length * 40).toDouble(),
 );
 final newNode = ArchitectureNode(
 id: 'n_${_nodeCounter++}',
 label: item.label,
 position: centerPos,
 nodeType: item.type,
 icon: item.icon,
 );
 setState(() => _nodes.add(newNode));
 _scheduleSave();
 },
 ),
 );
 },
 ),
 ),
 // Tips
 Container(
 padding: const EdgeInsets.all(10),
 margin: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7E6),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Icon(Icons.lightbulb_outline, size: 14, color: const Color(0xFFD97706)),
 const SizedBox(width: 6),
 Expanded(
 child: Text(
 'Drag components to canvas. Use Connect mode to draw arrows between nodes.',
 style: TextStyle(fontSize: 10, color: const Color(0xFFD97706).withOpacity(0.8), height: 1.4),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),

 // ── Right: Architecture Canvas ──
 Expanded(
 child: ClipRRect(
 borderRadius: const BorderRadius.only(
 bottomRight: Radius.circular(16),
 ),
 child: ArchitectureCanvas(
 nodes: _nodes,
 edges: _edges,
 onNodesChanged: (n) => setState(() {
 _nodes
 ..clear()
 ..addAll(n);
 _scheduleSave();
 }),
 onEdgesChanged: (e) => setState(() {
 _edges
 ..clear()
 ..addAll(e);
 _scheduleSave();
 }),
 onRequestAddNodeFromDrop: (pos, payload) {
 return _createNodeFromDrop(pos, payload);
 },
 ),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 Widget _archHeaderButton({
 required IconData icon,
 required String label,
 required VoidCallback? onTap,
 Color? color,
 }) {
 final effectiveColor = color ?? const Color(0xFF374151);
 return Tooltip(
 message: label,
 waitDuration: const Duration(milliseconds: 400),
 child: Material(
 color: Colors.transparent,
 child: InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(8),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 border: Border.all(color: effectiveColor.withOpacity(0.25)),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(icon, size: 15, color: effectiveColor),
 const SizedBox(width: 4),
 Text(
 label,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: effectiveColor,
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 );
 }

 void _autoLayoutNodes() {
 if (_nodes.isEmpty) return;
 final nodes = List<ArchitectureNode>.from(_nodes);
 const double spacingX = 240;
 const double spacingY = 120;
 final cols = (nodes.length / 3).ceil().clamp(1, nodes.length);
 for (int i = 0; i < nodes.length; i++) {
 final row = i ~/ cols;
 final col = i % cols;
 nodes[i].position = Offset(80 + col * spacingX, 60 + row * spacingY);
 }
 setState(() {
 _nodes
 ..clear()
 ..addAll(nodes);
 });
 _scheduleSave();
 }

 // ── 7. Design Tools & Rich Text Editor ─────────────────────────────────
 Widget _buildStableDesignToolsEditor() {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: AppSemanticColors.border),
 boxShadow: const [
 BoxShadow(
 color: Color(0x08000000),
 blurRadius: 12,
 offset: Offset(0, 4),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Header row
 Row(
 children: [
 Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7E6),
 borderRadius: BorderRadius.circular(10),
 ),
 child: const Icon(
 Icons.design_services_outlined,
 size: 20,
 color: Color(0xFFB45309),
 ),
 ),
 const SizedBox(width: 10),
 const Text(
 'Design Tools',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 const Spacer(),
 // Tool selector chips
 _buildToolChip(
 'Rich Text Editor',
 Icons.edit_note_outlined,
 _activeTool == DesignTool.richText,
 onTap: () =>
 setState(() => _activeTool = DesignTool.richText),
 ),
 const SizedBox(width: 8),
 _buildToolChip(
 'Draw.io',
 Icons.account_tree_outlined,
 _activeTool == DesignTool.architecture,
 onTap: () =>
 setState(() => _activeTool = DesignTool.architecture),
 ),
 ],
 ),
 const SizedBox(height: 16),
 // Formatting toolbar
 const SizedBox(height: 12),
 // Text area
 Container(
 constraints: const BoxConstraints(minHeight: 240),
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: AppSemanticColors.border),
 ),
 child: VoiceTextField(
 controller: _richTextController,
 minLines: 8,
 maxLines: 14,
 decoration: const InputDecoration.collapsed(
 hintText:
 'Start drafting your design narrative here. Use the toolbar above for quick formatting.',
 ),
 style: const TextStyle(height: 1.6, fontSize: 14),
 ),
 ),
 const SizedBox(height: 16),
 // Status row
 Row(
 children: [
 Icon(Icons.check_circle_outline,
 size: 14,
 color: _isSaving
 ? Colors.orange
 : const Color(0xFFB45309)),
 const SizedBox(width: 6),
 Text(
 _isSaving
 ? 'Saving...'
 : _lastSavedAt != null
 ? 'Saved'
 : 'Ready',
 style: TextStyle(
 fontSize: 12,
 color: _isSaving
 ? Colors.orange
 : const Color(0xFFB45309),
 fontWeight: FontWeight.w600,
 ),
 ),
 const Spacer(),
 _buildGovernanceMetric(
 'Nodes',
 '${_nodes.length}',
 const Color(0xFF7C3AED),
 ),
 const SizedBox(width: 12),
 _buildGovernanceMetric(
 'Edges',
 '${_edges.length}',
 const Color(0xFFD97706),
 ),
 ],
 ),
 ],
 ),
 );
 }

 // ── 7.5 Collaborators Card ──────────────────────────────────────────────
 Widget _buildStableCollaboratorsCard() {
 final provider = ProjectDataInherited.maybeOf(context);
 final teamMembers = provider?.projectData.teamMembers ?? [];
 final hasMembers = teamMembers.isNotEmpty;

 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: AppSemanticColors.border),
 boxShadow: const [
 BoxShadow(
 color: Color(0x08000000),
 blurRadius: 12,
 offset: Offset(0, 4),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: const Color(0xFFFAF5FF),
 borderRadius: BorderRadius.circular(10),
 ),
 child: const Icon(
 Icons.people_outline,
 size: 20,
 color: Color(0xFF7C3AED),
 ),
 ),
 const SizedBox(width: 10),
 const Text(
 'Collaborators',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 ],
 ),
 const SizedBox(height: 4),
 Text(
 'Manage team members and external collaborators for the design phase.',
 style: TextStyle(fontSize: 12, color: Colors.grey[600]),
 ),
 const SizedBox(height: 20),
 if (!hasMembers)
 Center(
 child: Column(
 children: [
 Icon(
 Icons.people_outline_rounded,
 size: 48,
 color: Colors.grey.shade300,
 ),
 const SizedBox(height: 12),
 Text(
 'No collaborators added',
 style: TextStyle(
 fontSize: 13,
 color: Colors.grey[500],
 ),
 ),
 ],
 ),
 )
 else
 ...teamMembers.take(5).map((member) {
 final trimmedName = member.name.trim();
 final trimmedRole = member.role.trim();
 final displayName = trimmedName.isNotEmpty
 ? trimmedName
 : trimmedRole.isNotEmpty
 ? trimmedRole
 : 'Unassigned team member';
 final displayRole =
 trimmedRole.isNotEmpty ? trimmedRole : 'Team Member';
 final initials = _getInitials(displayName);
 final color = _getColorForMember(displayName);
 return _buildCollaboratorItem(
 displayName,
 displayRole,
 initials,
 color,
 );
 }),
 const SizedBox(height: 20),
 SizedBox(
 width: double.infinity,
 child: ElevatedButton.icon(
 onPressed: () {
 // Open collaborator dialog
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF7C3AED),
 foregroundColor: Colors.white,
 elevation: 0,
 padding: const EdgeInsets.symmetric(vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(10),
 ),
 ),
 icon: const Icon(Icons.add, size: 18),
 label: const Text(
 'Add Collaborator',
 style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildToolChip(
 String label, IconData icon, bool isSelected, {VoidCallback? onTap}) {
 return GestureDetector(
 onTap: onTap,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 color: isSelected
 ? const Color(0xFFFFF7E6)
 : const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(
 color: isSelected
 ? const Color(0xFFD97706)
 : const Color(0xFFE2E8F0),
 ),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(icon,
 size: 16,
 color: isSelected
 ? const Color(0xFFD97706)
 : const Color(0xFF64748B)),
 const SizedBox(width: 6),
 Text(
 label,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: isSelected
 ? const Color(0xFFD97706)
 : const Color(0xFF64748B),
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildStableNotesCard() {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: AppSemanticColors.border),
 boxShadow: const [
 BoxShadow(
 color: Color(0x12000000),
 blurRadius: 18,
 offset: Offset(0, 10),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 24,
 height: 24,
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7D6),
 borderRadius: BorderRadius.circular(999),
 ),
 child: const Icon(
 Icons.sticky_note_2_outlined,
 size: 14,
 color: Color(0xFFF4B400),
 ),
 ),
 const SizedBox(width: 8),
 const Text(
 'Notes',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ],
 ),
 const SizedBox(height: 8),
 Text(
 'Summarize design goals, artifacts, and key decisions.',
 style: TextStyle(
 fontSize: 12,
 color: Colors.grey[600],
 ),
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.format_shapes_outlined,
 size: 14, color: Colors.grey[600]),
 const SizedBox(width: 6),
 Text(
 'Format',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Colors.grey[700],
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 8),
 ],
 ),
 const SizedBox(height: 12),
 Container(
 constraints: const BoxConstraints(minHeight: 120),
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: AppSemanticColors.border),
 ),
 child: VoiceTextField(
 controller: _richTextController,
 minLines: 4,
 maxLines: 6,
 decoration: const InputDecoration.collapsed(
 hintText:
 'Capture the key decisions and details for this section...',
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildMinimalWebScreen(double padding) {
 return Scaffold(
 backgroundColor: Theme.of(context).scaffoldBackgroundColor,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: SafeArea(
 child: Center(
 child: Padding(
 padding: EdgeInsets.all(padding),
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 720),
 child: Container(
 width: double.infinity,
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: AppSemanticColors.border),
 boxShadow: const [
 BoxShadow(
 color: Color(0x12000000),
 blurRadius: 18,
 offset: Offset(0, 10),
 ),
 ],
 ),
 child: const Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Design Management',
 style: TextStyle(
 fontSize: 28,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 SizedBox(height: 12),
 Text(
 'Web diagnostic mode is active.',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w600,
 ),
 ),
 SizedBox(height: 12),
 Text(
 'If this placeholder renders, the previous layout failure was inside the Design Management widget tree. If it still crashes, the failure is outside this screen and in a shared app wrapper.',
 style: TextStyle(
 fontSize: 14,
 height: 1.5,
 color: Color(0xFF4B5563),
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 ),
 ),
 );
 }

 // ignore: unused_element
 Widget _buildWebSafeNavigationCard() {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: AppSemanticColors.border),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Next Step',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 8),
 Text(
 'Continue to requirements implementation once the strategy and notes are updated.',
 style: TextStyle(
 fontSize: 13,
 color: Colors.grey[600],
 height: 1.5,
 ),
 ),
 const SizedBox(height: 16),
 Wrap(
 spacing: 12,
 runSpacing: 12,
 children: [
 OutlinedButton(
 onPressed: () => Navigator.of(context).maybePop(),
 child: const Text('Back'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const RequirementsImplementationScreen(),
 ),
 ),
 child: const Text('Requirements Implementation'),
 ),
 ],
 ),
 ],
 ),
 );
 }

 // ignore: unused_element
 Widget _buildWebSafeStrategySection() {
 final provider = ProjectDataInherited.maybeOf(context);
 if (provider == null) return const SizedBox.shrink();

 final projectData = provider.projectData;
 final managementData = _resolvedManagementData(projectData);

 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: AppSemanticColors.border),
 boxShadow: const [
 BoxShadow(
 color: Color(0x12000000),
 blurRadius: 18,
 offset: Offset(0, 10),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Design Strategy & Governance',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 6),
 Text(
 'The web layout uses a simplified single-column strategy form to keep the screen stable.',
 style: TextStyle(
 fontSize: 12,
 color: Colors.grey[600],
 height: 1.4,
 ),
 ),
 const SizedBox(height: 18),
 _buildWebSafeDropdownBlock<ProjectMethodology>(
 label: 'Methodology',
 value: managementData.methodology,
 items: ProjectMethodology.values
 .map(
 (methodology) => DropdownMenuItem(
 value: methodology,
 child: Text(
 methodology.name.toUpperCase(),
 style: const TextStyle(fontSize: 13),
 ),
 ),
 )
 .toList(),
 onChanged: (value) {
 if (value != null) _updateMethodology(value);
 },
 helper: _getMethodologyDescription(managementData.methodology),
 ),
 const SizedBox(height: 16),
 _buildWebSafeDropdownBlock<ProjectIndustry>(
 label: 'Industry',
 value: managementData.industry,
 items: ProjectIndustry.values
 .map(
 (industry) => DropdownMenuItem(
 value: industry,
 child: Text(
 industry.name.substring(0, 1).toUpperCase() +
 industry.name.substring(1),
 style: const TextStyle(fontSize: 13),
 ),
 ),
 )
 .toList(),
 onChanged: (value) {
 if (value != null) _updateIndustry(value);
 },
 ),
 const SizedBox(height: 16),
 _buildWebSafeDropdownBlock<ExecutionStrategy>(
 label: 'Execution Strategy',
 value: managementData.executionStrategy,
 items: ExecutionStrategy.values
 .map(
 (strategy) => DropdownMenuItem(
 value: strategy,
 child: Text(
 strategy.name
 .replaceAll(RegExp(r'(?<!^)(?=[A-Z])'), ' ')
 .toUpperCase(),
 style: const TextStyle(fontSize: 13),
 ),
 ),
 )
 .toList(),
 onChanged: (value) {
 if (value != null) _updateStrategy(value);
 },
 ),
 ],
 ),
 );
 }

 Widget _buildWebSafeDropdownBlock<T>({
 required String label,
 required T value,
 required List<DropdownMenuItem<T>> items,
 required ValueChanged<T?> onChanged,
 String? helper,
 }) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: TextStyle(fontSize: 12, color: Colors.grey[700]),
 ),
 const SizedBox(height: 8),
 DropdownButtonFormField<T>(
 value: value,
 decoration: InputDecoration(
 isDense: true,
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
 border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
 ),
 items: items,
 onChanged: onChanged,
 ),
 if (helper != null) ...[
 const SizedBox(height: 6),
 Text(
 helper,
 style: TextStyle(fontSize: 11, color: Colors.grey[500]),
 ),
 ],
 ],
 );
 }

 // ignore: unused_element
 Widget _buildWebGovernanceSummary() {
 final provider = ProjectDataInherited.maybeOf(context);
 final projectData = provider?.projectData ?? ProjectDataModel();
 final data = _resolvedManagementData(projectData);
 final readiness = _progress ?? data.readiness;

 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: AppSemanticColors.border),
 boxShadow: const [
 BoxShadow(
 color: Color(0x12000000),
 blurRadius: 18,
 offset: Offset(0, 10),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 42,
 height: 42,
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7E6),
 borderRadius: BorderRadius.circular(12),
 ),
 child: const Icon(
 Icons.admin_panel_settings_outlined,
 color: Color(0xFFD97706),
 ),
 ),
 const SizedBox(height: 12),
 const Text(
 'Governance Snapshot',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 16),
 Wrap(
 spacing: 12,
 runSpacing: 12,
 children: [
 _buildGovernanceMetric(
 'Readiness',
 '${(readiness.overallScore * 100).toInt()}%',
 const Color(0xFFD97706),
 ),
 _buildGovernanceMetric(
 'Team Members',
 '${projectData.teamMembers.length}',
 const Color(0xFF0F766E),
 ),
 _buildGovernanceMetric(
 'Requirements',
 '${projectData.frontEndPlanningData.requirements.length}',
 const Color(0xFFB45309),
 ),
 _buildGovernanceMetric(
 'Architecture Nodes',
 '${_nodes.length}',
 const Color(0xFF7C3AED),
 ),
 ],
 ),
 const SizedBox(height: 16),
 const Text(
 'Web-safe mode is active for this screen. Core design strategy, governance summary, and editor tools remain available while the heavier visual workspace is simplified for reliable rendering.',
 style: TextStyle(
 fontSize: 13,
 color: Color(0xFF6B7280),
 height: 1.5,
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildGovernanceMetric(String label, String value, Color color) {
 return Container(
 width: 180,
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: AppSemanticColors.border),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label,
 style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
 const SizedBox(height: 6),
 Text(
 value,
 style: TextStyle(
 fontSize: 22,
 fontWeight: FontWeight.w700,
 color: color,
 ),
 ),
 ],
 ),
 );
 }

 // ignore: unused_element
 Widget _buildWebEditorSummary() {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: AppSemanticColors.border),
 boxShadow: const [
 BoxShadow(
 color: Color(0x12000000),
 blurRadius: 18,
 offset: Offset(0, 10),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 42,
 height: 42,
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7E6),
 borderRadius: BorderRadius.circular(12),
 ),
 child:
 const Icon(Icons.edit_note_outlined, color: Color(0xFFD97706)),
 ),
 const SizedBox(height: 12),
 const Text(
 'Design Editor Summary',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 'The full interactive editor stack is simplified on web to avoid layout failures while keeping core design documentation accessible.',
 style: TextStyle(
 fontSize: 12,
 color: Colors.grey[600],
 height: 1.4,
 ),
 ),
 const SizedBox(height: 18),
 const SizedBox(height: 12),
 Container(
 constraints: const BoxConstraints(minHeight: 320),
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: AppSemanticColors.border),
 ),
 child: VoiceTextField(
 controller: _richTextController,
 minLines: 12,
 maxLines: 18,
 decoration: const InputDecoration.collapsed(
 hintText: 'Start typing your design notes...',
 ),
 style: const TextStyle(height: 1.5),
 ),
 ),
 const SizedBox(height: 16),
 Wrap(
 spacing: 12,
 runSpacing: 12,
 children: [
 _buildGovernanceMetric(
 'Nodes',
 '${_nodes.length}',
 const Color(0xFF7C3AED),
 ),
 _buildGovernanceMetric(
 'Edges',
 '${_edges.length}',
 const Color(0xFFD97706),
 ),
 _buildGovernanceMetric(
 'Status',
 _isSaving ? 'Saving' : 'Ready',
 const Color(0xFF0F766E),
 ),
 ],
 ),
 ],
 ),
 );
 }

 Widget _buildDesignToolsSidebarSection() {
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: Colors.grey.shade200),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 const Text('Design Tools',
 style: TextStyle(fontWeight: FontWeight.w600)),
 const Icon(Icons.add, size: 16),
 ],
 ),
 const SizedBox(height: 8),
 Text('Select to use',
 style: TextStyle(fontSize: 12, color: Colors.grey[500])),
 const SizedBox(height: 12),
 SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: Row(
 children: [
 _buildToolItem(
 'Draw.io',
 Icons.account_tree,
 isSelected: _activeTool == DesignTool.architecture,
 onTap: () =>
 setState(() => _activeTool = DesignTool.architecture),
 ),
 const SizedBox(width: 8),
 _buildToolItem(
 'Miro',
 Icons.dashboard_outlined,
 onTap: () =>
 _openToolWebView('Miro', 'https://miro.com/login/'),
 showExternalIcon: true,
 ),
 const SizedBox(width: 8),
 _buildToolItem(
 'Figma',
 Icons.design_services,
 onTap: () =>
 _openToolWebView('Figma', 'https://www.figma.com/'),
 showExternalIcon: true,
 ),
 const SizedBox(width: 8),
 _buildToolItem(
 'Rich Text Editor',
 Icons.text_fields,
 isSelected: _activeTool == DesignTool.richText,
 onTap: () =>
 setState(() => _activeTool = DesignTool.richText),
 ),
 const SizedBox(width: 8),
 _buildToolItem(
 'Whiteboard',
 Icons.brush,
 isSelected: _activeTool == DesignTool.whiteboard,
 onTap: () =>
 setState(() => _activeTool = DesignTool.whiteboard),
 ),
 const SizedBox(width: 8),
 _buildToolItem(
 'Chart Builder',
 Icons.bar_chart,
 isSelected: _activeTool == DesignTool.chartBuilder,
 onTap: () =>
 setState(() => _activeTool = DesignTool.chartBuilder),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildToolItem(
 String title,
 IconData icon, {
 bool isSelected = false,
 VoidCallback? onTap,
 bool showExternalIcon = false,
 }) {
 final backgroundColor = isSelected
 ? Colors.blue.withOpacity(0.1)
 : Colors.grey.withOpacity(0.06);
 return Material(
 color: Colors.transparent,
 child: InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(6),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 color: backgroundColor,
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: Colors.grey.shade200),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(icon,
 size: 18, color: isSelected ? const Color(0xFFD97706) : Colors.grey[700]),
 const SizedBox(width: 12),
 Text(
 title,
 style: TextStyle(
 fontSize: 13,
 color: isSelected ? const Color(0xFFD97706) : Colors.black87,
 fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
 ),
 ),
 if (showExternalIcon)
 Icon(Icons.open_in_new, size: 14, color: Colors.grey[400]),
 ],
 ),
 ),
 ),
 );
 }

 Widget _buildCollaboratorsSection() {
 final provider = ProjectDataInherited.maybeOf(context);
 final teamMembers = provider?.projectData.teamMembers ?? [];
 final collaborators = teamMembers.map((member) {
 final trimmedName = member.name.trim();
 final trimmedRole = member.role.trim();
 final displayName = trimmedName.isNotEmpty
 ? trimmedName
 : trimmedRole.isNotEmpty
 ? trimmedRole
 : 'Unassigned team member';
 final displayRole = trimmedRole.isNotEmpty ? trimmedRole : 'Team Member';
 return (displayName, displayRole);
 }).toList();

 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: Colors.grey.shade200),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 const Text('Collaborators',
 style: TextStyle(fontWeight: FontWeight.w600)),
 const Icon(Icons.add, size: 16),
 ],
 ),
 const SizedBox(height: 8),
 Text('${collaborators.length} members',
 style: TextStyle(fontSize: 12, color: Colors.grey[500])),
 const SizedBox(height: 12),
 if (collaborators.isEmpty)
 Padding(
 padding: const EdgeInsets.symmetric(vertical: 8),
 child: Text(
 'No team members yet. Add team members in Team Management.',
 style: TextStyle(
 fontSize: 12,
 color: Colors.grey[600],
 fontStyle: FontStyle.italic),
 ),
 )
 else
 ...collaborators.map((member) {
 final displayName = member.$1;
 final displayRole = member.$2;
 final initials = _getInitials(displayName);
 final color = _getColorForMember(displayName);
 return _buildCollaboratorItem(
 displayName,
 displayRole,
 initials,
 color,
 );
 }),
 ],
 ),
 );
 }

 String _getInitials(String name) {
 final normalized = name.trim();
 if (normalized.isEmpty) return '?';

 final parts = normalized
 .split(RegExp(r'\s+'))
 .where((part) => part.isNotEmpty)
 .toList();
 if (parts.isEmpty) return '?';
 if (parts.length == 1) {
 return parts[0].substring(0, 1).toUpperCase();
 }
 return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'
 .toUpperCase();
 }

 Color _getColorForMember(String name) {
 final colors = [
 const Color(0xFFD97706),
 Colors.purple,
 Colors.orange,
 Colors.teal,
 Colors.pink,
 const Color(0xFFD97706),
 Colors.cyan,
 Colors.amber
 ];
 final hash = name.hashCode.abs();
 return colors[hash % colors.length];
 }

 Widget _buildCollaboratorItem(
 String name, String role, String initials, Color color,
 {bool isOnline = false, Color? statusColor}) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: Row(
 children: [
 CircleAvatar(
 radius: 16,
 backgroundColor: color.withOpacity(0.2),
 child: Text(initials,
 style: TextStyle(
 fontSize: 12, color: color, fontWeight: FontWeight.bold)),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(name,
 style: const TextStyle(
 fontSize: 13, fontWeight: FontWeight.w500)),
 Text(role,
 style: TextStyle(fontSize: 11, color: Colors.grey[500])),
 ],
 ),
 ),
 if (statusColor != null)
 Container(
 width: 8,
 height: 8,
 decoration: BoxDecoration(
 color: statusColor,
 shape: BoxShape.circle,
 ),
 )
 else if (isOnline)
 Container(
 width: 8,
 height: 8,
 decoration: const BoxDecoration(
 color: Colors.green,
 shape: BoxShape.circle,
 ),
 ),
 ],
 ),
 );
 }

 void _openToolWebView(String title, String url) {
 // For web platform, open in new tab since WebView is not supported
 if (kIsWeb) {
 // Open in new tab
 openUrlInNewWindow(url);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Opening $title in new tab'),
 duration: const Duration(seconds: 2),
 ),
 );
 return;
 }

 // For mobile/desktop, use modal with WebView
 showDialog(
 context: context,
 builder: (context) => Dialog(
 backgroundColor: Colors.transparent,
 insetPadding: const EdgeInsets.all(24),
 child: Container(
 width: MediaQuery.of(context).size.width * 0.85,
 height: MediaQuery.of(context).size.height * 0.85,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.2),
 blurRadius: 20,
 offset: const Offset(0, 10),
 ),
 ],
 ),
 child: Column(
 children: [
 // Header
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.grey.shade50,
 borderRadius: const BorderRadius.only(
 topLeft: Radius.circular(16),
 topRight: Radius.circular(16),
 ),
 border: Border(
 bottom: BorderSide(color: Colors.grey.shade200),
 ),
 ),
 child: Row(
 children: [
 Icon(Icons.public, color: Colors.grey.shade700, size: 20),
 const SizedBox(width: 12),
 Expanded(
 child: Text(
 title,
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w600,
 color: Colors.black87,
 ),
 ),
 ),
 IconButton(
 icon: const Icon(Icons.close),
 onPressed: () => Navigator.of(context).pop(),
 tooltip: 'Close',
 ),
 ],
 ),
 ),
 // WebView Content
 Expanded(
 child: ClipRRect(
 borderRadius: const BorderRadius.only(
 bottomLeft: Radius.circular(16),
 bottomRight: Radius.circular(16),
 ),
 child: WebViewWidget(
 controller: WebViewController()
 ..setJavaScriptMode(JavaScriptMode.unrestricted)
 ..loadRequest(Uri.parse(url)),
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }

 Widget _buildStrategySection() {
 final provider = ProjectDataInherited.maybeOf(context);
 if (provider == null) return const SizedBox.shrink();

 final projectData = provider.projectData;
 final DesignManagementData managementData =
 _resolvedManagementData(projectData);
 final methodology = managementData.methodology;
 final strategy = managementData.executionStrategy;
 final industry = managementData.industry;

 return Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: Colors.grey.shade200),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 const Text('Design Strategy & Governance',
 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: Colors.blue.withOpacity(0.1),
 borderRadius: BorderRadius.circular(4),
 ),
 child: const Text('Required',
 style: TextStyle(fontSize: 11, color: const Color(0xFFD97706))),
 ),
 ],
 ),
 const SizedBox(height: 24),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Methodology',
 style:
 TextStyle(fontSize: 12, color: Colors.grey[600])),
 const SizedBox(height: 8),
 DropdownButtonFormField<ProjectMethodology>(
 value: methodology,
 decoration: InputDecoration(
 isDense: true,
 contentPadding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 12),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(8)),
 ),
 items: ProjectMethodology.values.map((m) {
 return DropdownMenuItem(
 value: m,
 child: Text(m.name.toUpperCase(),
 style: const TextStyle(fontSize: 13)),
 );
 }).toList(),
 onChanged: (val) {
 if (val != null) _updateMethodology(val);
 },
 ),
 const SizedBox(height: 4),
 Text(
 _getMethodologyDescription(methodology),
 style: TextStyle(fontSize: 11, color: Colors.grey[500]),
 ),
 ],
 ),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Industry',
 style:
 TextStyle(fontSize: 12, color: Colors.grey[600])),
 const SizedBox(height: 8),
 DropdownButtonFormField<ProjectIndustry>(
 value: industry,
 decoration: InputDecoration(
 isDense: true,
 contentPadding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 12),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(8)),
 ),
 items: ProjectIndustry.values.map((i) {
 return DropdownMenuItem(
 value: i,
 child: Text(
 i.name.substring(0, 1).toUpperCase() +
 i.name.substring(1),
 style: const TextStyle(fontSize: 13)),
 );
 }).toList(),
 onChanged: (val) {
 if (val != null) _updateIndustry(val);
 },
 ),
 ],
 ),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Execution Strategy',
 style:
 TextStyle(fontSize: 12, color: Colors.grey[600])),
 const SizedBox(height: 8),
 DropdownButtonFormField<ExecutionStrategy>(
 value: strategy,
 decoration: InputDecoration(
 isDense: true,
 contentPadding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 12),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(8)),
 ),
 items: ExecutionStrategy.values.map((s) {
 return DropdownMenuItem(
 value: s,
 child: Text(
 s.name
 .replaceAll(RegExp(r'(?<!^)(?=[A-Z])'), ' ')
 .toUpperCase(),
 style: const TextStyle(fontSize: 13)),
 );
 }).toList(),
 onChanged: (val) {
 if (val != null) _updateStrategy(val);
 },
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

 String _getMethodologyDescription(ProjectMethodology m) {
 switch (m) {
 case ProjectMethodology.waterfall:
 return 'Sequential phases, strict requirements';
 case ProjectMethodology.agile:
 return 'Iterative sprints, flexible scope';
 case ProjectMethodology.hybrid:
 return 'Mixed approach for optimal control';
 }
 }

 DesignManagementData _resolvedManagementData(ProjectDataModel projectData) {
 final existing = projectData.designManagementData;
 if (existing != null) return existing;
 final mapped = ProjectDataHelper.projectMethodologyFromOverallFramework(
 projectData.overallFramework,
 ) ??
 ProjectMethodology.waterfall;
 return DesignManagementData(methodology: mapped);
 }

 void _updateMethodology(ProjectMethodology val) {
 final provider = ProjectDataInherited.maybeOf(context);
 provider?.updateField((ProjectDataModel p) {
 final dm = p.designManagementData ?? DesignManagementData();
 return p.copyWith(
 designManagementData: dm.copyWith(methodology: val),
 overallFramework:
 ProjectDataHelper.overallFrameworkFromMethodology(val),
 );
 });
 }

 void _updateIndustry(ProjectIndustry val) {
 final provider = ProjectDataInherited.maybeOf(context);
 provider?.updateField((ProjectDataModel p) {
 final dm = p.designManagementData ?? DesignManagementData();
 return p.copyWith(designManagementData: dm.copyWith(industry: val));
 });
 }

 void _updateStrategy(ExecutionStrategy val) {
 final provider = ProjectDataInherited.maybeOf(context);
 provider?.updateField((ProjectDataModel p) {
 final dm = p.designManagementData ?? DesignManagementData();
 return p.copyWith(
 designManagementData: dm.copyWith(executionStrategy: val));
 });
 }

 Widget _buildManagementCards() {
 final ProjectDataProvider? provider = ProjectDataInherited.maybeOf(context);
 final projectData = provider?.projectData ?? ProjectDataModel();
 final data = _resolvedManagementData(projectData);

 return DesignGovernanceDashboard(
 projectData: projectData,
 managementData: data,
 readiness: _progress,
 architectureNodeCount: _nodes.length,
 );
 }

 Widget _buildEditorSection() {
 final cs = Theme.of(context).colorScheme;
 return Container(
 height: 680,
 decoration: BoxDecoration(
 color: cs.surface,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: AppSemanticColors.border),
 boxShadow: const [
 BoxShadow(
 color: Color(0x12000000), blurRadius: 18, offset: Offset(0, 10)),
 ],
 ),
 child: Column(
 children: [
 // Editor Header
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: BoxDecoration(
 border:
 Border(bottom: BorderSide(color: AppSemanticColors.border)),
 ),
 child: Row(
 children: [
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('System Architecture',
 style: TextStyle(fontWeight: FontWeight.w700)),
 const SizedBox(height: 2),
 Text('Design Editor · Output Document',
 style:
 TextStyle(fontSize: 12, color: Colors.grey[600])),
 ],
 ),
 const SizedBox(width: 12),
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7E6),
 borderRadius: BorderRadius.circular(999),
 ),
 child: const Text('Live canvas',
 style:
 TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
 ),
 const Spacer(),
 OutlinedButton.icon(
 onPressed: _addArchitectureNode,
 style: OutlinedButton.styleFrom(
 foregroundColor: Colors.black87,
 side: const BorderSide(color: Color(0xFFE5E7EB)),
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add node',
 style:
 TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 ),
 if (_nodes.isNotEmpty) ...[
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: _deleteLastArchitectureNode,
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFFB42318),
 side: const BorderSide(color: Color(0xFFFECACA)),
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 icon: const Icon(Icons.delete_outline, size: 16),
 label: const Text(
 'Delete last',
 style:
 TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
 ),
 ),
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: _clearArchitectureCanvas,
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF7A0916),
 side: const BorderSide(color: Color(0xFFFDA4AF)),
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 icon: const Icon(Icons.layers_clear_outlined, size: 16),
 label: const Text(
 'Clear canvas',
 style:
 TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
 ),
 ),
 ],
 const SizedBox(width: 12),
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: AppSemanticColors.successSurface,
 borderRadius: BorderRadius.circular(4),
 ),
 child: Row(
 children: [
 const Icon(Icons.check_circle_outline,
 size: 14, color: AppSemanticColors.success),
 const SizedBox(width: 4),
 Text(
 _isSaving
 ? 'Saving…'
 : _lastSavedAt != null
 ? 'Saved'
 : 'Ready',
 style: const TextStyle(
 fontSize: 11, color: AppSemanticColors.success),
 ),
 ],
 ),
 ),
 const SizedBox(width: 16),
 const Icon(Icons.fullscreen, size: 20, color: Colors.grey),
 const SizedBox(width: 12),
 const Icon(Icons.chat_bubble_outline,
 size: 18, color: Colors.grey),
 const SizedBox(width: 12),
 const Icon(Icons.more_horiz, size: 20, color: Colors.grey),
 ],
 ),
 ),
 Padding(
 padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
 child: LayoutBuilder(
 builder: (context, constraints) {
 final isNarrow = constraints.maxWidth < 860;
 if (isNarrow) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 _buildDesignToolsSidebarSection(),
 const SizedBox(height: 16),
 _buildCollaboratorsSection(),
 ],
 );
 }
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(child: _buildDesignToolsSidebarSection()),
 const SizedBox(width: 16),
 Expanded(child: _buildCollaboratorsSection()),
 ],
 );
 },
 ),
 ),
 // Editor Body
 Expanded(
 child: Row(
 children: [
 _buildToolSidePanel(),

 // Canvas
 Expanded(
 child: Padding(
 padding: const EdgeInsets.all(12.0),
 child: _buildActiveCanvas(),
 ),
 ),
 ],
 ),
 ),
 // Footer
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
 decoration: BoxDecoration(
 border: Border(top: BorderSide(color: AppSemanticColors.border)),
 ),
 child: Row(
 children: [
 const Icon(Icons.check_circle_outline,
 size: 16, color: AppSemanticColors.success),
 const SizedBox(width: 24),
 Icon(Icons.access_time, size: 16, color: Colors.grey[500]),
 const SizedBox(width: 8),
 Text(
 _isSaving
 ? 'Saving…'
 : _lastSavedAt != null
 ? 'Saved ${TimeOfDay.fromDateTime(_lastSavedAt!).format(context)}'
 : 'No changes yet',
 style: TextStyle(fontSize: 12, color: Colors.grey[500]),
 ),
 const Spacer(),
 Text(_toolFooterLabel(),
 style: TextStyle(fontSize: 12, color: Colors.grey[600])),
 ],
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildToolSidePanel() {
 if (_activeTool != DesignTool.architecture) {
 return Container(
 width: 220,
 decoration: BoxDecoration(
 border: Border(right: BorderSide(color: AppSemanticColors.border)),
 ),
 child: _buildToolSidebarContent(),
 );
 }
 return Container(
 width: 220,
 decoration: BoxDecoration(
 border: Border(right: BorderSide(color: AppSemanticColors.border)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const SizedBox(height: 12),
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 12.0),
 child: Text('Component Library',
 style: TextStyle(
 color: Colors.grey[800], fontWeight: FontWeight.w700)),
 ),
 const SizedBox(height: 8),
 Expanded(
 child: ListView.builder(
 padding: const EdgeInsets.symmetric(horizontal: 8),
 itemCount: _library.length,
 itemBuilder: (context, i) {
 final item = _library[i];
 final payload = ArchitectureDragPayload(item.label,
 icon: item.icon, color: item.type.bgColor, nodeType: item.type);
 return LongPressDraggable<ArchitectureDragPayload>(
 data: payload,
 dragAnchorStrategy: pointerDragAnchorStrategy,
 feedback: Material(
 color: Colors.transparent,
 child: _componentTile(item,
 isDragging: true, showAddButton: false),
 ),
 child: _componentTile(
 item,
 showAddButton: true,
 onAddToCanvas: () {
 // Add node to center of visible canvas
 final centerPos = Offset(
 200 + (_nodes.length * 40).toDouble(),
 200 + (_nodes.length * 40).toDouble());
 final newNode = ArchitectureNode(
 id: 'n_${_nodeCounter++}',
 label: item.label,
 position: centerPos,
 nodeType: item.type,
 icon: item.icon,
 );
 setState(() {
 _nodes.add(newNode);
 });
 _scheduleSave();
 },
 ),
 );
 },
 ),
 ),
 Padding(
 padding: const EdgeInsets.all(12.0),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Tip: Click + to add to canvas, or drag to position.',
 style: TextStyle(fontSize: 11, color: Colors.grey[600]),
 ),
 const SizedBox(height: 4),
 Text(
 'Use "Connect" mode to draw workflow arrows between components.',
 style: TextStyle(fontSize: 11, color: Colors.grey[600]),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildToolSidebarContent() {
 switch (_activeTool) {
 case DesignTool.whiteboard:
 return _toolSidebarCard(
 title: 'Whiteboard Tips',
 lines: const [
 'Draw freely with pen or marker.',
 'Use the eraser to clean sections.',
 'Undo restores the last stroke.',
 'Clear removes everything instantly.',
 ],
 );
 case DesignTool.chartBuilder:
 return _toolSidebarCard(
 title: 'Chart Builder',
 lines: const [
 'Switch chart types in the header.',
 'Edit labels and values on the right.',
 'Add points to grow the chart.',
 'Use colors to group meaning.',
 ],
 );
 case DesignTool.richText:
 return _toolSidebarCard(
 title: 'Rich Text Editor',
 lines: const [
 'Draft narratives beside diagrams.',
 'Use headings for quick scannability.',
 'Keep key decisions highlighted.',
 ],
 );
 case DesignTool.architecture:
 return const SizedBox.shrink();
 }
 }

 Widget _toolSidebarCard(
 {required String title, required List<String> lines}) {
 return Padding(
 padding: const EdgeInsets.all(12.0),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(title,
 style: TextStyle(
 color: Colors.grey[800], fontWeight: FontWeight.w700)),
 const SizedBox(height: 12),
 ...lines.map(
 (line) => Padding(
 padding: const EdgeInsets.only(bottom: 8),
 child: Text(line,
 style: TextStyle(fontSize: 12, color: Colors.grey[600])),
 ),
 ),
 const Spacer(),
 Container(
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(
 color: Colors.grey.withOpacity(0.06),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: Colors.grey.shade200),
 ),
 child: Row(
 children: [
 Icon(Icons.auto_awesome, size: 16, color: Colors.amber[700]),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 'Pro tip: switch tools any time - your work stays here.',
 style: TextStyle(fontSize: 11, color: Colors.grey[600]),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildActiveCanvas() {
 switch (_activeTool) {
 case DesignTool.whiteboard:
 return const WhiteboardCanvas();
 case DesignTool.chartBuilder:
 return const ChartBuilderWorkspace();
 case DesignTool.richText:
 return _buildRichTextPlaceholder();
 case DesignTool.architecture:
 return ArchitectureCanvas(
 nodes: _nodes,
 edges: _edges,
 onNodesChanged: (n) => setState(() {
 _nodes
 ..clear()
 ..addAll(n);
 _scheduleSave();
 }),
 onEdgesChanged: (e) => setState(() {
 _edges
 ..clear()
 ..addAll(e);
 _scheduleSave();
 }),
 onRequestAddNodeFromDrop: (pos, payload) {
 final node = _createNodeFromDrop(pos, payload);
 return node;
 },
 );
 }
 }

 Widget _buildWebArchitectureFallback() {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: AppSemanticColors.border),
 ),
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 42,
 height: 42,
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7E6),
 borderRadius: BorderRadius.circular(12),
 ),
 child: const Icon(Icons.account_tree_outlined,
 color: Color(0xFFD97706)),
 ),
 const SizedBox(width: 12),
 const Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Architecture Workspace',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 SizedBox(height: 4),
 Text(
 'Web-safe summary mode is active to keep the Design Management screen stable and visible.',
 style: TextStyle(
 fontSize: 12,
 color: Color(0xFF6B7280),
 height: 1.4,
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 20),
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: AppSemanticColors.border),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 '${_nodes.length} architecture nodes captured',
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 8),
 Text(
 _nodes.isEmpty
 ? 'No architecture nodes have been added yet. Use the Rich Text Editor or add nodes from a non-web environment if you need the full interactive canvas.'
 : _nodes.take(6).map((n) => '• ${n.label}').join('\n'),
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF4B5563),
 height: 1.5,
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 16),
 OutlinedButton.icon(
 onPressed: () => setState(() => _activeTool = DesignTool.richText),
 icon: const Icon(Icons.text_fields, size: 18),
 label: const Text('Switch to Rich Text Editor'),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF111827),
 side: const BorderSide(color: Color(0xFFE5E7EB)),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 ),
 ),
 const SizedBox(height: 20),
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: AppSemanticColors.border),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Expanded(
 child: Text(
 'Manual node register',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ),
 TextButton.icon(
 onPressed: _addArchitectureNode,
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add node'),
 ),
 ],
 ),
 const SizedBox(height: 12),
 if (_nodes.isEmpty)
 Text(
 'No nodes yet. Add one manually to keep the architecture model editable on web.',
 style: TextStyle(fontSize: 12, color: Colors.grey[600]),
 )
 else
 ..._nodes.map(_buildWebNodeEditor),
 ],
 ),
 ),
 ],
 ),
 );
 }

 void _addOutputDoc() {
 _showAddDocumentUploadDialog();
 }

 Future<void> _showAddDocumentUploadDialog() async {
 final titleController = TextEditingController();
 String docType = 'Output';
 String? uploadedFileName;
 String? uploadedFileUrl;
 String? uploadedStoragePath;
 bool isUploading = false;

 await showDialog(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (context, setDialogState) => AlertDialog(
 title: Row(
 children: [
 Container(
 width: 32,
 height: 32,
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7E6),
 borderRadius: BorderRadius.circular(8),
 ),
 child: const Icon(Icons.insert_drive_file_outlined,
 size: 18, color: Color(0xFFB45309)),
 ),
 const SizedBox(width: 10),
 const Text('Add Document',
 style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
 ],
 ),
 content: SizedBox(
 width: 480,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 TextField(
 controller: titleController,
 decoration: const InputDecoration(
 labelText: 'Document Title',
 border: OutlineInputBorder(),
 isDense: true,
 ),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: docType,
 decoration: const InputDecoration(
 labelText: 'Type',
 border: OutlineInputBorder(),
 isDense: true,
 ),
 items: ['Input', 'Output', 'Reference']
 .map((t) => DropdownMenuItem(value: t, child: Text(t)))
 .toList(),
 onChanged: (val) => setDialogState(() => docType = val!),
 ),
 const SizedBox(height: 16),
 // File upload area
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(
 color: uploadedFileName != null
 ? const Color(0xFFB45309)
 : const Color(0xFFE2E8F0),
 ),
 ),
 child: Column(
 children: [
 if (uploadedFileName != null) ...[
 Row(
 children: [
 const Icon(Icons.check_circle,
 size: 20, color: Color(0xFFB45309)),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 uploadedFileName!,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827),
 ),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 IconButton(
 icon: const Icon(Icons.close,
 size: 16, color: Color(0xFFEF4444)),
 onPressed: () => setDialogState(() {
 uploadedFileName = null;
 uploadedFileUrl = null;
 uploadedStoragePath = null;
 }),
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(
 minWidth: 28, minHeight: 28),
 ),
 ],
 ),
 ] else ...[
 Icon(Icons.cloud_upload_outlined,
 size: 36, color: Colors.grey.shade400),
 const SizedBox(height: 8),
 Text(
 'Click to upload a document',
 style: TextStyle(
 fontSize: 13, color: Colors.grey.shade600),
 ),
 const SizedBox(height: 4),
 Text(
 'PDF, DOC, DOCX, XLS, XLSX, PPT, PPTX, TXT, CSV, PNG, JPG',
 style: TextStyle(
 fontSize: 11, color: Colors.grey.shade500),
 ),
 ],
 const SizedBox(height: 12),
 SizedBox(
 width: double.infinity,
 child: OutlinedButton.icon(
 onPressed: isUploading
 ? null
 : () async {
 setDialogState(
 () => isUploading = true);
 final pid = _projectId ??
 ProjectDataHelper.getData(context)
 .projectId;
 if (pid == null || pid.isEmpty) {
 setDialogState(
 () => isUploading = false);
 return;
 }
 final result =
 await FileUploadHelper.pickAndUpload(
 folder: 'design-documents',
 projectId: pid,
 allowedExtensions:
 FileUploadHelper.documentExtensions,
 );
 if (result != null) {
 setDialogState(() {
 uploadedFileName = result.fileName;
 uploadedFileUrl = result.downloadUrl;
 uploadedStoragePath =
 result.storagePath;
 isUploading = false;
 });
 } else {
 setDialogState(
 () => isUploading = false);
 }
 },
 icon: isUploading
 ? const SizedBox(
 width: 16,
 height: 16,
 child: CircularProgressIndicator(
 strokeWidth: 2),
 )
 : const Icon(Icons.attach_file, size: 18),
 label: Text(
 isUploading ? 'Uploading...' : 'Choose File'),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFFB45309),
 side: const BorderSide(color: Color(0xFFB45309)),
 padding: const EdgeInsets.symmetric(vertical: 10),
 ),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(dialogContext),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () {
 if (titleController.text.trim().isEmpty &&
 uploadedFileName == null) return;

 final provider = ProjectDataInherited.maybeOf(context);
 if (provider == null) return;

 final newDoc = DesignDocument(
 title: titleController.text.trim().isEmpty
 ? uploadedFileName ?? 'Untitled'
 : titleController.text.trim(),
 type: docType,
 url: uploadedFileUrl,
 uploadedFileName: uploadedFileName,
 uploadedStoragePath: uploadedStoragePath,
 );

 final currentData =
 provider.projectData.designManagementData ??
 DesignManagementData();
 currentData.documents.add(newDoc);
 provider.updateProjectData(
 provider.projectData
 .copyWith(designManagementData: currentData),
 );

 // Also add to outputDocs for canvas display
 setState(() {
 _outputDocs.add(_DocItem(
 newDoc.title,
 icon: Icons.insert_drive_file_outlined,
 color: Colors.white,
 ));
 });
 _scheduleSave();
 Navigator.pop(dialogContext);
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFB45309),
 foregroundColor: Colors.white,
 ),
 child: const Text('Add Document'),
 ),
 ],
 ),
 ),
 );
 }

 Future<void> _showAddToolUploadDialog() async {
 final nameController = TextEditingController();
 final urlController = TextEditingController();
 bool isInternal = false;
 String? uploadedFileName;
 String? uploadedFileUrl;
 String? uploadedStoragePath;
 bool isUploading = false;

 await showDialog(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (context, setDialogState) => AlertDialog(
 title: Row(
 children: [
 Container(
 width: 32,
 height: 32,
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7E6),
 borderRadius: BorderRadius.circular(8),
 ),
 child: const Icon(Icons.build_outlined,
 size: 18, color: Color(0xFFB45309)),
 ),
 const SizedBox(width: 10),
 const Text('Add Design Tool',
 style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
 ],
 ),
 content: SizedBox(
 width: 480,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 TextField(
 controller: nameController,
 decoration: const InputDecoration(
 labelText: 'Tool Name',
 border: OutlineInputBorder(),
 isDense: true,
 ),
 ),
 const SizedBox(height: 12),
 TextField(
 controller: urlController,
 decoration: const InputDecoration(
 labelText: 'URL (Optional)',
 border: OutlineInputBorder(),
 isDense: true,
 ),
 ),
 const SizedBox(height: 12),
 CheckboxListTile(
 title: const Text('Internal Tool'),
 value: isInternal,
 onChanged: (val) =>
 setDialogState(() => isInternal = val ?? false),
 controlAffinity: ListTileControlAffinity.leading,
 contentPadding: EdgeInsets.zero,
 ),
 const SizedBox(height: 8),
 // File upload area
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7E6),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(
 color: uploadedFileName != null
 ? const Color(0xFFB45309)
 : const Color(0xFFE2E8F0),
 ),
 ),
 child: Column(
 children: [
 if (uploadedFileName != null) ...[
 Row(
 children: [
 const Icon(Icons.check_circle,
 size: 20, color: Color(0xFFB45309)),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 uploadedFileName!,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827),
 ),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 IconButton(
 icon: const Icon(Icons.close,
 size: 16, color: Color(0xFFEF4444)),
 onPressed: () => setDialogState(() {
 uploadedFileName = null;
 uploadedFileUrl = null;
 uploadedStoragePath = null;
 }),
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(
 minWidth: 28, minHeight: 28),
 ),
 ],
 ),
 ] else ...[
 Icon(Icons.cloud_upload_outlined,
 size: 36, color: Colors.grey.shade400),
 const SizedBox(height: 8),
 Text(
 'Upload design documents or tool files',
 style: TextStyle(
 fontSize: 13, color: Colors.grey.shade600),
 ),
 const SizedBox(height: 4),
 Text(
 'PDF, DOC, DOCX, FIG, SKETCH, XD, PNG, JPG, ZIP',
 style: TextStyle(
 fontSize: 11, color: Colors.grey.shade500),
 ),
 ],
 const SizedBox(height: 12),
 SizedBox(
 width: double.infinity,
 child: OutlinedButton.icon(
 onPressed: isUploading
 ? null
 : () async {
 setDialogState(
 () => isUploading = true);
 final pid = _projectId ??
 ProjectDataHelper.getData(context)
 .projectId;
 if (pid == null || pid.isEmpty) {
 setDialogState(
 () => isUploading = false);
 return;
 }
 final result =
 await FileUploadHelper.pickAndUpload(
 folder: 'design-tools',
 projectId: pid,
 allowedExtensions:
 FileUploadHelper.toolExtensions,
 );
 if (result != null) {
 setDialogState(() {
 uploadedFileName = result.fileName;
 uploadedFileUrl = result.downloadUrl;
 uploadedStoragePath =
 result.storagePath;
 isUploading = false;
 });
 } else {
 setDialogState(
 () => isUploading = false);
 }
 },
 icon: isUploading
 ? const SizedBox(
 width: 16,
 height: 16,
 child: CircularProgressIndicator(
 strokeWidth: 2),
 )
 : const Icon(Icons.attach_file, size: 18),
 label: Text(
 isUploading ? 'Uploading...' : 'Choose File'),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFFB45309),
 side: const BorderSide(color: Color(0xFFB45309)),
 padding: const EdgeInsets.symmetric(vertical: 10),
 ),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(dialogContext),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () {
 if (nameController.text.trim().isEmpty &&
 uploadedFileName == null) return;

 final provider = ProjectDataInherited.maybeOf(context);
 if (provider == null) return;

 final newTool = DesignToolLink(
 name: nameController.text.trim().isEmpty
 ? uploadedFileName ?? 'Untitled Tool'
 : nameController.text.trim(),
 url: urlController.text.trim().isEmpty
 ? (uploadedFileUrl ?? '')
 : urlController.text.trim(),
 isInternal: isInternal,
 uploadedFileName: uploadedFileName,
 uploadedStoragePath: uploadedStoragePath,
 );

 final currentData =
 provider.projectData.designManagementData ??
 DesignManagementData();
 currentData.tools.add(newTool);
 provider.updateProjectData(
 provider.projectData
 .copyWith(designManagementData: currentData),
 );

 _scheduleSave();
 Navigator.pop(dialogContext);
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFB45309),
 foregroundColor: Colors.white,
 ),
 child: const Text('Add Tool'),
 ),
 ],
 ),
 ),
 );
 }

 void _addArchitectureNode() {
 final node = ArchitectureNode(
 id: 'n_${_nodeCounter++}',
 label: 'New Component',
 nodeType: ArchitectureNodeType.service,
 position: Offset(
 220 + (_nodes.length * 24).toDouble(),
 160 + (_nodes.length * 24).toDouble(),
 ),
 icon: ArchitectureNodeType.service.icon,
 );
 setState(() => _nodes.add(node));
 _scheduleSave();
 }

 void _deleteLastArchitectureNode() {
 if (_nodes.isEmpty) return;
 final id = _nodes.last.id;
 _deleteArchitectureNode(id);
 }

 Future<void> _deleteArchitectureNode(String id) async {
  final confirmed = await showDeleteConfirmationDialog(
    context,
    title: 'Delete Architecture Node',
    message: 'Delete this architecture node? This action cannot be undone.',
  );
  if (!confirmed) return;
  setState(() {
  _nodes.removeWhere((node) => node.id == id);
  _edges.removeWhere((edge) => edge.fromId == id || edge.toId == id);
  });
  _scheduleSave();
  }

 void _clearArchitectureCanvas() {
 setState(() {
 _nodes.clear();
 _edges.clear();
 });
 _scheduleSave();
 }

 Widget _buildWebNodeEditor(ArchitectureNode node) {
 return Container(
 margin: const EdgeInsets.only(bottom: 10),
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: AppSemanticColors.border),
 ),
 child: Row(
 children: [
 Icon(node.icon ?? Icons.widgets_outlined,
 size: 18, color: const Color(0xFF475467)),
 const SizedBox(width: 10),
 Expanded(
 child: VoiceTextFormField(
 key: ValueKey('web-node-${node.id}'),
 initialValue: node.label,
 decoration: const InputDecoration(
 isDense: true,
 hintText: 'Node label',
 border: OutlineInputBorder(),
 ),
 onChanged: (value) {
 node.label = value;
 _scheduleSave();
 },
 ),
 ),
 const SizedBox(width: 8),
 IconButton(
 tooltip: 'Delete node',
 onPressed: () => _deleteArchitectureNode(node.id),
 icon: const Icon(Icons.delete_outline, color: Color(0xFFB42318)),
 ),
 ],
 ),
 );
 }

 Widget _buildRichTextPlaceholder() {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: AppSemanticColors.border),
 ),
 child: Column(
 children: [
 Padding(
 padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
 child: Row(
 children: [
 Text('Rich Text Editor',
 style: TextStyle(
 fontWeight: FontWeight.w700, color: Colors.grey[800])),
 ],
 ),
 ),
 const SizedBox(height: 12),
 Expanded(
 child: Padding(
 padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
 child: Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: Colors.grey.shade200),
 ),
 child: VoiceTextField(
 controller: _richTextController,
 expands: true,
 maxLines: null,
 minLines: null,
 decoration: const InputDecoration.collapsed(
 hintText: 'Start typing your design notes...',
 ),
 style: const TextStyle(height: 1.5),
 ),
 ),
 ),
 ),
 ],
 ),
 );
 }

 String _toolFooterLabel() {
 switch (_activeTool) {
 case DesignTool.whiteboard:
 return 'Whiteboard ready for freehand sketching';
 case DesignTool.chartBuilder:
 return 'Chart builder active';
 case DesignTool.richText:
 return 'Rich text workspace ready';
 case DesignTool.architecture:
 return '${_nodes.length} elements on canvas';
 }
 }

 Widget _componentTile(_PaletteItem item,
 {bool isDragging = false,
 bool showAddButton = false,
 VoidCallback? onAddToCanvas}) {
 final accent = item.type.accentColor;
 return Container(
 margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
 decoration: BoxDecoration(
 color: isDragging
 ? accent.withOpacity(0.12)
 : item.type.bgColor,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(
 color: isDragging ? accent : const Color(0xFFE4E7EC),
 width: isDragging ? 1.5 : 1,
 ),
 ),
 child: Row(
 children: [
 Container(
 width: 28,
 height: 28,
 decoration: BoxDecoration(
 color: accent.withOpacity(0.12),
 borderRadius: BorderRadius.circular(7),
 ),
 child: Icon(item.icon, size: 15, color: accent),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Text(item.label,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: accent.withOpacity(0.85),
 )),
 ),
 if (showAddButton && onAddToCanvas != null) ...[
 InkWell(
 onTap: onAddToCanvas,
 borderRadius: BorderRadius.circular(6),
 child: Container(
 padding: const EdgeInsets.all(4),
 child: Icon(Icons.add_circle_outline,
 size: 16, color: accent),
 ),
 ),
 const SizedBox(width: 2),
 ],
 Icon(Icons.drag_indicator, size: 14, color: Colors.grey[400]),
 ],
 ),
 );
 }
}

class _DocItem {
 _DocItem(this.title, {this.icon, this.color});
 final String title;
 final IconData? icon;
 final Color? color;
}

class _PaletteItem {
 const _PaletteItem(this.label, this.icon, {this.type = ArchitectureNodeType.custom});
 final String label;
 final IconData icon;
 final ArchitectureNodeType type;
}
