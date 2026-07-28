import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/architecture_service.dart';
import 'package:ndu_project/services/activity_log_service.dart';
import 'package:ndu_project/services/project_navigation_service.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/screens/ui_ux_design_screen.dart';
import 'package:ndu_project/screens/engineering_design_screen.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/file_upload_helper.dart';
import 'package:ndu_project/widgets/execution_phase_ui.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
class BackendDesignScreen extends StatefulWidget {
 const BackendDesignScreen({super.key});

 @override
 State<BackendDesignScreen> createState() => _BackendDesignScreenState();
}

class _BackendDesignScreenState extends State<BackendDesignScreen> {
 final TextEditingController _architectureSummaryController =
 TextEditingController();
 final TextEditingController _databaseSummaryController =
 TextEditingController();
 final TextEditingController _quickComponentNameController =
 TextEditingController();
 final TextEditingController _quickComponentResponsibilityController =
 TextEditingController();
 final TextEditingController _quickEntityNameController =
 TextEditingController();
 final TextEditingController _quickEntityPrimaryKeyController =
 TextEditingController();
 final TextEditingController _quickEntityDescriptionController =
 TextEditingController();

 final List<_ArchitectureComponent> _components = [];
 final List<_ArchitectureDataFlow> _dataFlows = [];
 final List<_DesignDocument> _designDocuments = [];
 final List<_DbEntity> _entities = [];
 final List<_DbField> _fields = [];

 final _Debouncer _saveDebounce = _Debouncer();
 bool _isLoading = false;
 bool _suspendSave = false;
 bool _didSeedDefaults = false;
 Map<String, dynamic>? _architectureWorkspace;
 String? _isKazAiLoadingRowId;

 final List<String> _componentTypes = const [
 'Client',
 'Service',
 'Data store',
 'Integration',
 'Queue',
 'Analytics'
 ];
 final List<String> _componentStatuses = const [
 'Planned',
 'In progress',
 'Live',
 'Deprecated'
 ];
 final List<String> _protocolOptions = const [
 'HTTP',
 'gRPC',
 'Event',
 'Batch',
 'Streaming'
 ];
 final List<String> _documentStatuses = const [
 'Draft',
 'In review',
 'Approved',
 'Deprecated'
 ];
 String _quickComponentType = 'Service';
 String _quickComponentStatus = 'Planned';
 String _quickComponentOwner = 'Platform';
 String _quickEntityOwner = 'Operations';

 List<String> _ownerOptions({String? currentValue}) {
 final data = ProjectDataHelper.getData(context);
 final members = data.teamMembers;
 final names = members
 .map((member) {
 final name = member.name.trim();
 if (name.isNotEmpty) return name;
 final email = member.email.trim();
 if (email.isNotEmpty) return email;
 return member.role.trim();
 })
 .where((value) => value.isNotEmpty)
 .toList();
 final options = names.isEmpty ? <String>['Owner'] : names.toSet().toList();
 final normalized = currentValue?.trim() ?? '';
 if (normalized.isNotEmpty && !options.contains(normalized)) {
 return [normalized, ...options];
 }
 return options;
 }

 @override
 void initState() {
 super.initState();
 _architectureSummaryController.addListener(_scheduleSave);
 _databaseSummaryController.addListener(_scheduleSave);
 WidgetsBinding.instance.addPostFrameCallback((_) async {
 final projectId = _projectId();
 if (projectId != null && projectId.isNotEmpty) {
 await ProjectNavigationService.instance.saveLastPage(
 projectId,
 'backend-design',
 );
 }
 await _loadFromFirestore();
 });
 }

 
 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Backend Design',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['backend_design_screen'] ?? 'No data recorded.'),
 ],
 );
 }
@override
 void dispose() {
 _architectureSummaryController.dispose();
 _databaseSummaryController.dispose();
 _quickComponentNameController.dispose();
 _quickComponentResponsibilityController.dispose();
 _quickEntityNameController.dispose();
 _quickEntityPrimaryKeyController.dispose();
 _quickEntityDescriptionController.dispose();
 _saveDebounce.dispose();
 super.dispose();
 }

 String _defaultArchitectureSummary() {
 return 'Invisible architecture covering cloud services, venue plant systems, vendor handoffs, and the operational backbone that supports the visible experience.';
 }

 String _defaultDatabaseSummary() {
 return 'Information architecture for users, guest lists, stock, access control, and operational events flowing from capture to storage and reporting.';
 }

 List<_ArchitectureComponent> _defaultComponents() {
 return [
 _ArchitectureComponent(
 id: DateTime.now().microsecondsSinceEpoch.toString(),
 name: 'API Gateway',
 type: 'Service',
 responsibility:
 'Routes app traffic, ticket scans, and vendor callbacks.',
 owner: 'Platform',
 status: 'Planned',
 ),
 _ArchitectureComponent(
 id: DateTime.now().microsecondsSinceEpoch.toString(),
 name: 'Operational Data Store',
 type: 'Data store',
 responsibility:
 'Stores guest records, material stock, and audit events.',
 owner: 'Data',
 status: 'Planned',
 ),
 _ArchitectureComponent(
 id: DateTime.now().microsecondsSinceEpoch.toString(),
 name: 'Venue Power Grid',
 type: 'Integration',
 responsibility:
 'Feeds registration desks, stage systems, and back-of-house loads.',
 owner: 'Venue Ops',
 status: 'In progress',
 ),
 _ArchitectureComponent(
 id: DateTime.now().microsecondsSinceEpoch.toString(),
 name: 'HVAC Monitoring',
 type: 'Analytics',
 responsibility:
 'Tracks thermal load and occupancy comfort during peak periods.',
 owner: 'Facilities',
 status: 'Planned',
 ),
 ];
 }

 List<_ArchitectureDataFlow> _defaultDataFlows() {
 return [
 _ArchitectureDataFlow(
 id: DateTime.now().microsecondsSinceEpoch.toString(),
 source: 'Ticket Scanner',
 destination: 'API Gateway',
 protocol: 'HTTP',
 notes: 'Scan payload in, validation result out.',
 ),
 _ArchitectureDataFlow(
 id: DateTime.now().microsecondsSinceEpoch.toString(),
 source: 'Guest Registration Form',
 destination: 'Operational Data Store',
 protocol: 'Event',
 notes:
 'Guest profile, dietary data, and access class persist for operations.',
 ),
 _ArchitectureDataFlow(
 id: DateTime.now().microsecondsSinceEpoch.toString(),
 source: 'Fire Alarm Panel',
 destination: 'Sprinkler and Ops Escalation',
 protocol: 'Batch',
 notes: 'Manual handoff fallback if automation path is unavailable.',
 ),
 ];
 }

 List<_DesignDocument> _defaultDocuments() {
 return [
 _DesignDocument(
 id: DateTime.now().microsecondsSinceEpoch.toString(),
 title: 'Service topology pack',
 description:
 'Cloud services, auth boundary, and vendor integration map.',
 owner: 'Architecture',
 status: 'Draft',
 location: 'AWS Cloud / Architecture repo',
 ),
 _DesignDocument(
 id: DateTime.now().microsecondsSinceEpoch.toString(),
 title: 'Back-of-house operations layout',
 description:
 'Power, comms, storage, and logistics zones behind the customer-facing experience.',
 owner: 'Operations',
 status: 'In review',
 location: 'Venue operations folder',
 ),
 ];
 }

 List<_DbEntity> _defaultEntities() {
 return [
 _DbEntity(
 id: DateTime.now().microsecondsSinceEpoch.toString(),
 name: 'GuestList',
 primaryKey: 'guest_id',
 owner: 'Operations',
 description:
 'Guest identity, access class, dietary restrictions, and arrival status.',
 ),
 _DbEntity(
 id: DateTime.now().microsecondsSinceEpoch.toString(),
 name: 'MaterialStock',
 primaryKey: 'stock_id',
 owner: 'Procurement',
 description:
 'Materials, quantities, storage location, and issue history.',
 ),
 _DbEntity(
 id: DateTime.now().microsecondsSinceEpoch.toString(),
 name: 'AccessCredential',
 primaryKey: 'credential_id',
 owner: 'Security',
 description: 'Backstage passes, wristbands, and zone permissions.',
 ),
 ];
 }

 List<_DbField> _defaultFields() {
 return [
 _DbField(
 id: DateTime.now().microsecondsSinceEpoch.toString(),
 table: 'GuestList',
 field: 'dietary_restriction',
 type: 'string',
 constraints: 'nullable',
 notes: 'Shared with catering 2 hours before service.',
 ),
 _DbField(
 id: DateTime.now().microsecondsSinceEpoch.toString(),
 table: 'MaterialStock',
 field: 'weight_kg',
 type: 'decimal',
 constraints: '>= 0',
 notes: 'Used for load-bearing and transport planning.',
 ),
 _DbField(
 id: DateTime.now().microsecondsSinceEpoch.toString(),
 table: 'AccessCredential',
 field: 'zone_access',
 type: 'array',
 constraints: 'required',
 notes: 'Maps digital roles to physical access zones.',
 ),
 ];
 }

 @override
 Widget build(BuildContext context) {
 final padding = AppBreakpoints.pagePadding(context);

 return ResponsiveScaffold(
 activeItemLabel: 'Backend Design',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: SingleChildScrollView(
 padding: EdgeInsets.all(padding),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (_isLoading) const LinearProgressIndicator(minHeight: 2),
 if (_isLoading) const SizedBox(height: 16),
 PlanningPhaseHeader(
 title: 'Backend Design',
showNavigationButtons: false, onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 _buildBackendFrameworkGuide(),
 const SizedBox(height: 24),
 _buildSystemArchitectureRegister(),
 const SizedBox(height: 20),
 _buildDataArchitectureRegister(),
 const SizedBox(height: 20),
 _buildInterfaceContractsPanel(),
 const SizedBox(height: 20),
 _buildDocumentsSecurityPanel(),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: UI/UX Design',
 nextLabel: 'Next: Engineering',
 onBack: () => Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => const UiUxDesignScreen())),
 onNext: () => Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => const EngineeringDesignScreen())),
 ),
 ],
 ),
 ),
 );
 }

 // ─── Framework Guide ───────────────────────────────────────────────────────

 Widget _actionButton(IconData icon, String label,
 {VoidCallback? onPressed}) {
 return OutlinedButton.icon(
 onPressed: onPressed ?? () {},
 icon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
 label: Text(label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF64748B))),
 style: OutlinedButton.styleFrom(
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 );
 }

 Widget _buildBackendFrameworkGuide() {
 return ExecutionPanelShell(
 title: 'Backend design framework',
 subtitle:
 'Grounded in cloud-native architecture principles, microservice design patterns, '
 'domain-driven design, and infrastructure-as-code conventions.',
 collapsible: true,
 initiallyExpanded: false,
 headerIcon: Icons.dns_outlined,
 headerIconColor: const Color(0xFF2563EB),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Effective backend design '
 'ensures that system topology, data flows, security boundaries, and deployment pipelines '
 'are documented, reviewable, and operationally sound.',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 height: 1.5),
 ),
 const SizedBox(height: 18),
 _buildGuideCard(
 Icons.account_tree_outlined,
 'System Architecture',
 'Component topology showing services, data stores, integrations, and structural dependencies. '
 'Each node should have a clear owner, type classification, and lifecycle status. Map connections '
 'to reveal data flow paths and integration touchpoints.',
 const Color(0xFF2563EB),
 ),
 const SizedBox(height: 12),
 _buildGuideCard(
 Icons.dataset_outlined,
 'Data & Information Flow',
 'Entity-relationship view of the information backbone. Define primary keys, ownership, and '
 'field-level constraints. Document data movement from capture through processing to storage '
 'and reporting across the system.',
 const Color(0xFF10B981),
 ),
 const SizedBox(height: 12),
 _buildGuideCard(
 Icons.shield_outlined,
 'Security & Access Control',
 'Authentication boundaries, authorization policies, and access control matrices. Define who '
 'can access what, at which level, and through which interface. Document encryption standards, '
 'audit logging, and compliance requirements.',
 const Color(0xFF6366F1),
 ),
 const SizedBox(height: 12),
 _buildGuideCard(
 Icons.rocket_launch_outlined,
 'Deployment & Operations',
 'Infrastructure pipelines, deployment strategies, monitoring, and operational runbooks. Document '
 'environment configurations, scaling policies, disaster recovery procedures, and the vendor '
 'support matrix for production operations.',
 const Color(0xFFF97316),
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

 // ─── Panel 1: System Architecture Register ─────────────────────────────────

 Widget _buildSystemArchitectureRegister() {
 final ownerOptions = _ownerOptions(currentValue: _quickComponentOwner);
 return _PanelShell(
 title: 'System architecture register',
 subtitle: 'Map services, data stores, integrations, and infrastructure blocks',
 trailing: _actionButton(Icons.add, 'Add component', onPressed: _addComponent),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Architecture summary text area
 _LabeledTextArea(
 label: 'Architecture summary',
 controller: _architectureSummaryController,
 hintText: 'Describe the overall backend topology, critical services, and integration patterns.',
 ),
 const SizedBox(height: 16),
 _buildComponentsTable(),
 ],
 ),
 );
 }

 // ─── Panel 2: Data Architecture Register ───────────────────────────────────

 Widget _buildDataArchitectureRegister() {
 final ownerOptions = _ownerOptions(currentValue: _quickEntityOwner);
 return _PanelShell(
 title: 'Data architecture register',
 subtitle: 'Entity definitions, primary keys, and field-level constraints',
 trailing: _actionButton(Icons.add, 'Add entity', onPressed: _addEntity),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Database summary text area
 _LabeledTextArea(
 label: 'Schema summary',
 controller: _databaseSummaryController,
 hintText: 'Capture key database decisions, scaling approach, and indexing strategy.',
 ),
 const SizedBox(height: 16),
 // Entity cards
 _SectionHeader(
 title: 'Entities',
 actionLabel: 'Add entity',
 onAction: _addEntity,
 ),
 const SizedBox(height: 10),
 for (final entity in _entities)
 Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Text(
 entity.name,
 style: const TextStyle(
 fontSize: 13.5,
 fontWeight: FontWeight.w800,
 color: Color(0xFF0F172A),
 ),
 ),
 const SizedBox(width: 10),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFF10B981).withOpacity(0.12),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 entity.primaryKey,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFF10B981),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 6),
 Text(
 'Owner: ${entity.owner}',
 style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
 ),
 const SizedBox(height: 4),
 Text(
 entity.description,
 style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.45),
 ),
 ],
 ),
 ),
 _buildKazAiRowButton(
 'entity_${entity.id}',
 'entity description',
 'database entity',
 () => _updateEntity(entity.copyWith(description: 'AI-generated description')),
 ),
 const SizedBox(width: 8),
 IconButton(
 onPressed: () => _deleteEntity(entity.id),
 icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
 tooltip: 'Delete entity',
 ),

                                    IconButton(
                                      onPressed: () => _kazAiForRow(),
                                      icon: const Icon(Icons.auto_awesome,
                                          size: 16, color: Color(0xFFF59E0B)),
                                      tooltip: 'KAZ AI',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28),
                                    ),
 ],
 ),
 ),
 if (_entities.isEmpty)
 const _InlineEmptyState(
 title: 'No entities yet',
 message: 'Add core tables or collections.',
 ),
 const SizedBox(height: 16),
 // Fields table
 _SectionHeader(
 title: 'Field definitions',
 actionLabel: 'Add field',
 onAction: _addField,
 ),
 const SizedBox(height: 10),
 _buildFieldsTable(),
 ],
 ),
 );
 }

 // ─── Panel 3: Interface Contracts & Data Flows ─────────────────────────────

 Widget _buildInterfaceContractsPanel() {
 return _PanelShell(
 title: 'Interface contracts & data flows',
 subtitle: 'API specifications, integration protocols, and operational handoff agreements',
 trailing: _actionButton(Icons.add, 'Add data flow', onPressed: _addDataFlow),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Table header
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(12),
 ),
 child: const Row(
 children: [
 Expanded(flex: 3, child: Text('SOURCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 Expanded(flex: 2, child: Text('PROTOCOL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8), textAlign: TextAlign.center)),
 Expanded(flex: 3, child: Text('DESTINATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 Expanded(flex: 3, child: Text('NOTES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 60, child: Text('ACTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8), textAlign: TextAlign.center)),
 ],
 ),
 ),
 const SizedBox(height: 8),
 if (_dataFlows.isEmpty)
 const _InlineEmptyState(
 title: 'No data flows yet',
 message: 'Map service-to-service data exchange paths.',
 ),
 for (int i = 0; i < _dataFlows.length; i++)
 Container(
 margin: const EdgeInsets.only(bottom: 8),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 decoration: BoxDecoration(
 color: i.isEven ? Colors.white : const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 flex: 3,
 child: Text(
 _dataFlows[i].source,
 style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
 overflow: TextOverflow.ellipsis,
 maxLines: 1,
 ),
 ),
 Expanded(
 flex: 2,
 child: Center(
 child: _buildStatusBadge(_dataFlows[i].protocol, const Color(0xFF6366F1)),
 ),
 ),
 Expanded(
 flex: 3,
 child: Text(
 _dataFlows[i].destination,
 style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
 overflow: TextOverflow.ellipsis,
 maxLines: 1,
 ),
 ),
 Expanded(
 flex: 3,
 child: Text(
 _dataFlows[i].notes,
 style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.45),
 overflow: TextOverflow.ellipsis,
 maxLines: 2,
 ),
 ),
 SizedBox(
 width: 90,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 _buildKazAiRowButton(
 'dataflow_${_dataFlows[i].id}',
 'data flow notes',
 'data flow',
 () => _updateDataFlow(_dataFlows[i].copyWith(notes: 'AI-generated notes')),
 ),
 const SizedBox(width: 4),
 IconButton(
 onPressed: () => _openDataFlowDialog(existing: _dataFlows[i]),
 icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
 tooltip: 'Edit',
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 ),
 IconButton(
 onPressed: () => _deleteDataFlow(_dataFlows[i].id),
 icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
 tooltip: 'Delete',
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 ),

                                    IconButton(
                                      onPressed: () => _kazAiForRow(),
                                      icon: const Icon(Icons.auto_awesome,
                                          size: 16, color: Color(0xFFF59E0B)),
                                      tooltip: 'KAZ AI',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28),
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

 // ─── Panel 4: Design Documents & Security ──────────────────────────────────

 Widget _buildDocumentsSecurityPanel() {
 return _PanelShell(
 title: 'Design documents & security',
 subtitle: 'Architecture documents, security policies, and operational runbooks',
 trailing: _actionButton(Icons.add, 'Add document', onPressed: _addDesignDocument),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Table header
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(12),
 ),
 child: const Row(
 children: [
 Expanded(flex: 3, child: Text('TITLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 Expanded(flex: 2, child: Text('OWNER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8), textAlign: TextAlign.center)),
 Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8), textAlign: TextAlign.center)),
 Expanded(flex: 3, child: Text('LOCATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8))),
 SizedBox(width: 60, child: Text('ACTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.8), textAlign: TextAlign.center)),
 ],
 ),
 ),
 const SizedBox(height: 8),
 if (_designDocuments.isEmpty)
 const _InlineEmptyState(
 title: 'No design documents yet',
 message: 'Add architecture decisions, diagrams, and references.',
 ),
 for (int i = 0; i < _designDocuments.length; i++)
 Container(
 margin: const EdgeInsets.only(bottom: 8),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 decoration: BoxDecoration(
 color: i.isEven ? Colors.white : const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 flex: 3,
 child: Text(
 _designDocuments[i].title,
 style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
 overflow: TextOverflow.ellipsis,
 maxLines: 1,
 ),
 ),
 Expanded(
 flex: 2,
 child: Center(
 child: Text(
 _designDocuments[i].owner,
 style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
 overflow: TextOverflow.ellipsis,
 maxLines: 1,
 ),
 ),
 ),
 Expanded(
 flex: 2,
 child: Center(
 child: _buildStatusBadge(
 _designDocuments[i].status,
 _documentStatusColor(_designDocuments[i].status),
 ),
 ),
 ),
 Expanded(
 flex: 3,
 child: Row(
 children: [
 if (_designDocuments[i].hasUploadedFile) ...[
 const Icon(Icons.attach_file, size: 14, color: Color(0xFF10B981)),
 const SizedBox(width: 4),
 ],
 Expanded(
 child: Text(
 _designDocuments[i].hasUploadedFile
 ? _designDocuments[i].uploadedFileName!
 : _designDocuments[i].location,
 style: TextStyle(
 fontSize: 12,
 color: _designDocuments[i].hasUploadedFile
 ? const Color(0xFF10B981)
 : const Color(0xFF64748B),
 ),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 ),
 SizedBox(
 width: 90,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 _buildKazAiRowButton(
 'doc_${_designDocuments[i].id}',
 'document description',
 'design document',
 () => _updateDesignDocument(_designDocuments[i].copyWith(description: 'AI-generated description')),
 ),
 const SizedBox(width: 4),
 IconButton(
 onPressed: () => _openDesignDocumentDialog(existing: _designDocuments[i]),
 icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
 tooltip: 'Edit',
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 ),
 IconButton(
 onPressed: () => _deleteDesignDocument(_designDocuments[i].id),
 icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
 tooltip: 'Delete',
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 ),

                                    IconButton(
                                      onPressed: () => _kazAiForRow(),
                                      icon: const Icon(Icons.auto_awesome,
                                          size: 16, color: Color(0xFFF59E0B)),
                                      tooltip: 'KAZ AI',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28),
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

 Color _documentStatusColor(String status) {
 switch (status) {
 case 'Approved':
 return const Color(0xFF10B981);
 case 'In review':
 return const Color(0xFFF59E0B);
 case 'Deprecated':
 return const Color(0xFFEF4444);
 default:
 return const Color(0xFF64748B);
 }
 }

 // ─── KAZ AI Helpers ────────────────────────────────────────────────────────

 Widget _buildKazAiRowButton(String rowId, String label, String contextHint, VoidCallback onResult) {
 return Tooltip(
 message: 'KAZ AI – Auto-fill $label',
 child: InkWell(
 onTap: _isKazAiLoadingRowId != null ? null : () async {
 setState(() => _isKazAiLoadingRowId = rowId);
 try {
 final ai = OpenAiServiceSecure();
 final result = await ai.generateCompletion(
 'Based on this project context, generate a $label for a backend design $contextHint.\n\nProvide a concise, specific, actionable response (1-2 sentences). Return ONLY the text content (no JSON, no markdown headers).',
 maxTokens: 200,
 temperature: 0.6,
 );
 final cleaned = result.trim();
 if (cleaned.isNotEmpty && mounted) {
 onResult();
 _scheduleSave();
 }
 } catch (e) {
 debugPrint('KAZ AI generation failed: $e');
 if (mounted) ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('KAZ AI failed: $e'), backgroundColor: const Color(0xFFDC2626)),
 );
 } finally {
 if (mounted) setState(() => _isKazAiLoadingRowId = null);
 }
 },
 child: _isKazAiLoadingRowId == rowId
 ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFF59E0B)))
 : const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFF59E0B)),
 ),
 );
 }

 Widget _buildKazAiPillButton({
 required String label,
 required TextEditingController controller,
 required StateSetter setDialogState,
 }) {
 bool isLoading = false;
 return StatefulBuilder(
 builder: (context, setLocalState) => InkWell(
 onTap: isLoading ? null : () async {
 setLocalState(() => isLoading = true);
 try {
 final ai = OpenAiServiceSecure();
 final result = await ai.generateCompletion(
 'Based on this project context, generate a $label for a backend design element.\n\nProvide a concise, specific, actionable response (1-2 sentences). Return ONLY the text content (no JSON, no markdown headers).',
 maxTokens: 200,
 temperature: 0.6,
 );
 final cleaned = result.trim();
 if (cleaned.isNotEmpty) setDialogState(() => controller.text = cleaned);
 } catch (e) {
 debugPrint('KAZ AI field generation failed: $e');
 if (mounted) ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('KAZ AI failed: $e'), backgroundColor: const Color(0xFFDC2626)),
 );
 }
 if (context.mounted) setLocalState(() => isLoading = false);
 },
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: const Color(0xFFF59E0B).withOpacity(0.1),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 isLoading
 ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFF59E0B)))
 : const Icon(Icons.auto_awesome, size: 10, color: Color(0xFFF59E0B)),
 const SizedBox(width: 3),
 const Text('KAZ AI', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B))),
 ],
 ),
 ),
 ),
 );
 }

 // ─── Shared UI Helpers ─────────────────────────────────────────────────────

 Widget _buildStatusBadge(String label, Color color) {
 return Container(
 constraints: const BoxConstraints(maxWidth: 140),
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: color.withOpacity(0.12),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: color.withOpacity(0.22)),
 ),
 child: Text(
 label,
 overflow: TextOverflow.ellipsis,
 maxLines: 1,
 style: TextStyle(
 fontSize: 11.5,
 fontWeight: FontWeight.w800,
 color: color,
 ),
 ),
 );
 }

 Widget _buildInlineComposerCard({
 required IconData icon,
 required Color accent,
 required String title,
 required String subtitle,
 required Widget child,
 }) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 gradient: LinearGradient(
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 colors: [
 accent.withOpacity(0.08),
 Colors.white,
 ],
 ),
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: accent.withOpacity(0.18)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 40,
 height: 40,
 decoration: BoxDecoration(
 color: accent.withOpacity(0.12),
 borderRadius: BorderRadius.circular(14),
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
 fontSize: 15,
 fontWeight: FontWeight.w800,
 color: Color(0xFF0F172A),
 ),
 ),
 const SizedBox(height: 3),
 Text(
 subtitle,
 style: const TextStyle(
 fontSize: 12.5,
 color: Color(0xFF64748B),
 height: 1.4,
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 child,
 ],
 ),
 );
 }

 Widget _buildComposerTextField({
 required TextEditingController controller,
 required String label,
 required String hint,
 int minLines = 1,
 int maxLines = 1,
 }) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF475569),
 ),
 ),
 const SizedBox(height: 6),
 VoiceTextField(
 controller: controller,
 minLines: minLines,
 maxLines: maxLines,
 decoration: InputDecoration(
 hintText: hint,
 filled: true,
 fillColor: Colors.white,
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: const BorderSide(color: Color(0xFFD8E1EC)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: const BorderSide(color: Color(0xFFD8E1EC)),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: const BorderSide(
 color: Color(0xFF2563EB),
 width: 1.4,
 ),
 ),
 contentPadding: const EdgeInsets.symmetric(
 horizontal: 14,
 vertical: 12,
 ),
 ),
 ),
 ],
 );
 }

 Widget _buildComposerDropdown({
 required String label,
 required String value,
 required List<String> items,
 required ValueChanged<String?> onChanged,
 }) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF475569),
 ),
 ),
 const SizedBox(height: 6),
 DropdownButtonFormField<String>(
 value: value,
 items: items
 .map(
 (item) => DropdownMenuItem<String>(
 value: item,
 child: Text(item),
 ),
 )
 .toList(),
 onChanged: onChanged,
 decoration: InputDecoration(
 filled: true,
 fillColor: Colors.white,
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: const BorderSide(color: Color(0xFFD8E1EC)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: const BorderSide(color: Color(0xFFD8E1EC)),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: const BorderSide(
 color: Color(0xFF2563EB),
 width: 1.4,
 ),
 ),
 contentPadding: const EdgeInsets.symmetric(
 horizontal: 14,
 vertical: 12,
 ),
 ),
 ),
 ],
 );
 }

 // ─── Firestore & Data Methods ──────────────────────────────────────────────

 String? _projectId() => ProjectDataHelper.getData(context).projectId;

 Future<void> _loadFromFirestore() async {
 final projectId = _projectId();
 if (projectId == null || projectId.isEmpty) return;
 if (mounted) setState(() => _isLoading = true);
 bool shouldSeedDefaults = false;
 try {
 final doc = await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('design_phase_sections')
 .doc('backend_design')
 .get();
 final architectureWorkspace = await ArchitectureService.load(projectId);
 final data = doc.data() ?? {};
 final architecture =
 Map<String, dynamic>.from(data['architecture'] ?? {});
 final database = Map<String, dynamic>.from(data['database'] ?? {});
 shouldSeedDefaults = data.isEmpty && !_didSeedDefaults;

 _suspendSave = true;
 final components =
 _ArchitectureComponent.fromList(architecture['components']);
 final flows = _ArchitectureDataFlow.fromList(architecture['dataFlows']);
 final documents = _DesignDocument.fromList(architecture['documents']);
 final entities = _DbEntity.fromList(database['entities']);
 final fields = _DbField.fromList(database['fields']);

 if (!mounted) return;
 setState(() {
 _architectureWorkspace = architectureWorkspace;
 if (shouldSeedDefaults) {
 _didSeedDefaults = true;
 _architectureSummaryController.text = _defaultArchitectureSummary();
 _databaseSummaryController.text = _defaultDatabaseSummary();
 _components
 ..clear()
 ..addAll(_defaultComponents());
 _dataFlows
 ..clear()
 ..addAll(_defaultDataFlows());
 _designDocuments
 ..clear()
 ..addAll(_defaultDocuments());
 _entities
 ..clear()
 ..addAll(_defaultEntities());
 _fields
 ..clear()
 ..addAll(_defaultFields());
 } else {
 _architectureSummaryController.text =
 architecture['summary']?.toString() ?? '';
 _databaseSummaryController.text =
 database['summary']?.toString() ?? '';
 _components
 ..clear()
 ..addAll(components);
 _dataFlows
 ..clear()
 ..addAll(flows);
 _designDocuments
 ..clear()
 ..addAll(documents);
 _entities
 ..clear()
 ..addAll(entities);
 _fields
 ..clear()
 ..addAll(fields);
 }
 });
 } catch (error) {
 debugPrint('Failed to load backend design data: $error');
 } finally {
 _suspendSave = false;
 if (mounted) setState(() => _isLoading = false);
 if (shouldSeedDefaults) _scheduleSave();
 }
 }

 void _scheduleSave() {
 if (_suspendSave) return;
 _saveDebounce.run(_saveToFirestore);
 }

 Future<void> _saveToFirestore() async {
 final projectId = _projectId();
 if (projectId == null || projectId.isEmpty) return;
 final payload = {
 'architecture': {
 'summary': _architectureSummaryController.text.trim(),
 'components': _components.map((entry) => entry.toJson()).toList(),
 'dataFlows': _dataFlows.map((entry) => entry.toJson()).toList(),
 'documents': _designDocuments.map((entry) => entry.toJson()).toList(),
 },
 'database': {
 'summary': _databaseSummaryController.text.trim(),
 'entities': _entities.map((entry) => entry.toJson()).toList(),
 'fields': _fields.map((entry) => entry.toJson()).toList(),
 },
 'updatedAt': FieldValue.serverTimestamp(),
 };

 try {
 await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('design_phase_sections')
 .doc('backend_design')
 .set(payload, SetOptions(merge: true));
 await ActivityLogService.instance.logActivity(
 projectId: projectId,
 phase: 'Design Phase',
 page: 'Backend Design',
 action: 'Updated Backend Design data',
 );
 } catch (error) {
 debugPrint('Backend design save error: $error');
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Unable to save Backend Design changes right now. Please try again.',
 ),
 ),
 );
 }
 }

 void _logActivity(String action, {Map<String, dynamic>? details}) {
 final projectId = _projectId()?.trim() ?? '';
 if (projectId.isEmpty) return;
 unawaited(
 ActivityLogService.instance.logActivity(
 projectId: projectId,
 phase: 'Design Phase',
 page: 'Backend Design',
 action: action,
 details: details,
 ),
 );
 }

 // ── KAZ AI row generator ──
 void _kazAiForRow() {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('KAZ AI: Generating suggestions for this row...'),
 duration: Duration(seconds: 2),
 ),
 );
 }

 // ─── CRUD Methods ──────────────────────────────────────────────────────────

 Future<void> _addComponent() => _openComponentDialog();

 void _updateComponent(_ArchitectureComponent updated) {
 final index = _components.indexWhere((entry) => entry.id == updated.id);
 if (index == -1) return;
 setState(() => _components[index] = updated);
 _scheduleSave();
 }

 void _deleteComponent(String id) {
 setState(() => _components.removeWhere((entry) => entry.id == id));
 _scheduleSave();
 _logActivity('Deleted architecture component row', details: {'itemId': id});
 }

 void _addQuickArchitectureComponent() {
 final name = _quickComponentNameController.text.trim();
 final responsibility = _quickComponentResponsibilityController.text.trim();
 final owner = _quickComponentOwner.trim();
 if (name.isEmpty || responsibility.isEmpty || owner.isEmpty) return;

 setState(() {
 _components.add(
 _ArchitectureComponent(
 id: DateTime.now().microsecondsSinceEpoch.toString(),
 name: name,
 type: _quickComponentType,
 responsibility: responsibility,
 owner: owner,
 status: _quickComponentStatus,
 ),
 );
 _quickComponentNameController.clear();
 _quickComponentResponsibilityController.clear();
 _quickComponentType = _componentTypes.first;
 _quickComponentStatus = _componentStatuses.first;
 });
 _scheduleSave();
 _logActivity('Added architecture component row', details: {'name': name});
 }

 Future<void> _addDataFlow() => _openDataFlowDialog();

 void _updateDataFlow(_ArchitectureDataFlow updated) {
 final index = _dataFlows.indexWhere((entry) => entry.id == updated.id);
 if (index == -1) return;
 setState(() => _dataFlows[index] = updated);
 _scheduleSave();
 }

 void _deleteDataFlow(String id) {
 setState(() => _dataFlows.removeWhere((entry) => entry.id == id));
 _scheduleSave();
 _logActivity('Deleted data flow row', details: {'itemId': id});
 }

 Future<void> _addDesignDocument() => _openDesignDocumentDialog();

 void _updateDesignDocument(_DesignDocument updated) {
 final index =
 _designDocuments.indexWhere((entry) => entry.id == updated.id);
 if (index == -1) return;
 setState(() => _designDocuments[index] = updated);
 _scheduleSave();
 }

 void _deleteDesignDocument(String id) {
 setState(() => _designDocuments.removeWhere((entry) => entry.id == id));
 _scheduleSave();
 _logActivity('Deleted design document row', details: {'itemId': id});
 }

 Future<void> _addEntity() => _openEntityDialog();

 void _updateEntity(_DbEntity updated) {
 final index = _entities.indexWhere((entry) => entry.id == updated.id);
 if (index == -1) return;
 setState(() => _entities[index] = updated);
 _scheduleSave();
 }

 void _deleteEntity(String id) {
 setState(() => _entities.removeWhere((entry) => entry.id == id));
 _scheduleSave();
 _logActivity('Deleted data entity row', details: {'itemId': id});
 }

 void _addQuickDataEntity() {
 final name = _quickEntityNameController.text.trim();
 final primaryKey = _quickEntityPrimaryKeyController.text.trim();
 final owner = _quickEntityOwner.trim();
 final description = _quickEntityDescriptionController.text.trim();
 if (name.isEmpty ||
 primaryKey.isEmpty ||
 owner.isEmpty ||
 description.isEmpty) {
 return;
 }

 setState(() {
 _entities.add(
 _DbEntity(
 id: DateTime.now().microsecondsSinceEpoch.toString(),
 name: name,
 primaryKey: primaryKey,
 owner: owner,
 description: description,
 ),
 );
 _quickEntityNameController.clear();
 _quickEntityPrimaryKeyController.clear();
 _quickEntityDescriptionController.clear();
 });
 _scheduleSave();
 _logActivity('Added quick data entity row', details: {'name': name});
 }

 Future<void> _addField() => _openFieldDialog();

 // ─── Dialog Methods ────────────────────────────────────────────────────────

 Future<void> _openComponentDialog({_ArchitectureComponent? existing}) async {
 final nameController = TextEditingController(text: existing?.name ?? '');
 final responsibilityController =
 TextEditingController(text: existing?.responsibility ?? '');
 final ownerOptions = _ownerOptions(currentValue: existing?.owner);
 String type = existing?.type ?? _componentTypes.first;
 String owner = existing?.owner.isNotEmpty == true
 ? existing!.owner
 : ownerOptions.first;
 String status = existing?.status ?? _componentStatuses.first;
 final saved = await _showBackendDialog(
 title: existing == null ? 'Add architecture component' : 'Edit component',
 content: StatefulBuilder(
 builder: (context, setDialogState) => Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: nameController,
 decoration: const InputDecoration(
 labelText: 'Component name',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 8),
 _buildKazAiPillButton(
 label: 'component name',
 controller: nameController,
 setDialogState: setDialogState,
 ),
 ],
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: type,
 items: _componentTypes
 .map((option) =>
 DropdownMenuItem(value: option, child: Text(option)))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setDialogState(() => type = value);
 },
 decoration: const InputDecoration(
 labelText: 'Component type',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: responsibilityController,
 minLines: 2,
 maxLines: 4,
 decoration: const InputDecoration(
 labelText: 'Responsibility',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 8),
 _buildKazAiPillButton(
 label: 'component responsibility',
 controller: responsibilityController,
 setDialogState: setDialogState,
 ),
 ],
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: owner,
 items: ownerOptions
 .map((option) =>
 DropdownMenuItem(value: option, child: Text(option)))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setDialogState(() => owner = value);
 },
 decoration: const InputDecoration(
 labelText: 'Owner',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: status,
 items: _componentStatuses
 .map((option) =>
 DropdownMenuItem(value: option, child: Text(option)))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setDialogState(() => status = value);
 },
 decoration: const InputDecoration(
 labelText: 'Status',
 border: OutlineInputBorder(),
 ),
 ),
 ],
 ),
 ),
 confirmLabel: existing == null ? 'Add component' : 'Save changes',
 );
 if (saved != true) return;

 final item = _ArchitectureComponent(
 id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
 name: nameController.text.trim(),
 type: type,
 responsibility: responsibilityController.text.trim(),
 owner: owner,
 status: status,
 );
 setState(() {
 if (existing == null) {
 _components.add(item);
 } else {
 final index =
 _components.indexWhere((entry) => entry.id == existing.id);
 if (index != -1) _components[index] = item;
 }
 });
 _scheduleSave();
 _logActivity(
 existing == null
 ? 'Added architecture component row'
 : 'Edited architecture component row',
 details: {'itemId': item.id, 'name': item.name},
 );
 }

 Future<void> _openDataFlowDialog({_ArchitectureDataFlow? existing}) async {
 final sourceController =
 TextEditingController(text: existing?.source ?? '');
 final destinationController =
 TextEditingController(text: existing?.destination ?? '');
 final notesController = TextEditingController(text: existing?.notes ?? '');
 String protocol = existing?.protocol ?? _protocolOptions.first;
 final saved = await _showBackendDialog(
 title: existing == null ? 'Add data flow' : 'Edit data flow',
 content: StatefulBuilder(
 builder: (context, setDialogState) => Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: sourceController,
 decoration: const InputDecoration(
 labelText: 'Source',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 8),
 _buildKazAiPillButton(
 label: 'data source',
 controller: sourceController,
 setDialogState: setDialogState,
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: destinationController,
 decoration: const InputDecoration(
 labelText: 'Destination',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 8),
 _buildKazAiPillButton(
 label: 'data destination',
 controller: destinationController,
 setDialogState: setDialogState,
 ),
 ],
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: protocol,
 items: _protocolOptions
 .map((option) =>
 DropdownMenuItem(value: option, child: Text(option)))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setDialogState(() => protocol = value);
 },
 decoration: const InputDecoration(
 labelText: 'Protocol',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: notesController,
 minLines: 2,
 maxLines: 4,
 decoration: const InputDecoration(
 labelText: 'Notes',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 8),
 _buildKazAiPillButton(
 label: 'data flow notes',
 controller: notesController,
 setDialogState: setDialogState,
 ),
 ],
 ),
 ],
 ),
 ),
 confirmLabel: existing == null ? 'Add flow' : 'Save changes',
 );
 if (saved != true) return;

 final item = _ArchitectureDataFlow(
 id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
 source: sourceController.text.trim(),
 destination: destinationController.text.trim(),
 protocol: protocol,
 notes: notesController.text.trim(),
 );
 setState(() {
 if (existing == null) {
 _dataFlows.add(item);
 } else {
 final index = _dataFlows.indexWhere((entry) => entry.id == existing.id);
 if (index != -1) _dataFlows[index] = item;
 }
 });
 _scheduleSave();
 _logActivity(
 existing == null ? 'Added data flow row' : 'Edited data flow row',
 details: {'itemId': item.id},
 );
 }

 Future<void> _openDesignDocumentDialog({_DesignDocument? existing}) async {
 final titleController = TextEditingController(text: existing?.title ?? '');
 final descriptionController =
 TextEditingController(text: existing?.description ?? '');
 final locationController =
 TextEditingController(text: existing?.location ?? '');
 final ownerOptions = _ownerOptions(currentValue: existing?.owner);
 String owner = existing?.owner.isNotEmpty == true
 ? existing!.owner
 : ownerOptions.first;
 String status = existing?.status ?? _documentStatuses.first;
 String? uploadedFileName = existing?.uploadedFileName;
 String? uploadedFileUrl = existing?.uploadedFileUrl;
 String? uploadedStoragePath = existing?.uploadedStoragePath;
 bool isUploading = false;
 final saved = await _showBackendDialog(
 title: existing == null ? 'Add design document' : 'Edit design document',
 content: StatefulBuilder(
 builder: (context, setDialogState) => Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: titleController,
 decoration: const InputDecoration(
 labelText: 'Document title',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 8),
 _buildKazAiPillButton(
 label: 'document title',
 controller: titleController,
 setDialogState: setDialogState,
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: descriptionController,
 minLines: 2,
 maxLines: 4,
 decoration: const InputDecoration(
 labelText: 'Description',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 8),
 _buildKazAiPillButton(
 label: 'document description',
 controller: descriptionController,
 setDialogState: setDialogState,
 ),
 ],
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: owner,
 items: ownerOptions
 .map((option) =>
 DropdownMenuItem(value: option, child: Text(option)))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setDialogState(() => owner = value);
 },
 decoration: const InputDecoration(
 labelText: 'Owner',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: status,
 items: _documentStatuses
 .map((option) =>
 DropdownMenuItem(value: option, child: Text(option)))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setDialogState(() => status = value);
 },
 decoration: const InputDecoration(
 labelText: 'Status',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: locationController,
 decoration: const InputDecoration(
 labelText: 'Link or location',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 8),
 _buildKazAiPillButton(
 label: 'document location',
 controller: locationController,
 setDialogState: setDialogState,
 ),
 ],
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
 ? const Color(0xFF10B981)
 : const Color(0xFFE2E8F0),
 ),
 ),
 child: Column(
 children: [
 if (uploadedFileName != null) ...[
 Row(
 children: [
 const Icon(Icons.check_circle,
 size: 20, color: Color(0xFF10B981)),
 const SizedBox(width: 8),
 Expanded(
 child: Text(uploadedFileName!,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 overflow: TextOverflow.ellipsis),
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
 constraints:
 const BoxConstraints(minWidth: 28, minHeight: 28),
 ),
 ],
 ),
 ] else ...[
 Icon(Icons.cloud_upload_outlined,
 size: 36, color: Colors.grey.shade400),
 const SizedBox(height: 8),
 Text('Click to upload a document',
 style: TextStyle(
 fontSize: 13, color: Colors.grey.shade600)),
 const SizedBox(height: 4),
 Text(
 'PDF, DOC, DOCX, XLS, XLSX, PPT, PPTX, TXT, CSV, PNG, JPG',
 style: TextStyle(
 fontSize: 11, color: Colors.grey.shade500)),
 ],
 const SizedBox(height: 12),
 SizedBox(
 width: double.infinity,
 child: OutlinedButton.icon(
 onPressed: isUploading
 ? null
 : () async {
 setDialogState(() => isUploading = true);
 final projectId = _projectId();
 if (projectId == null || projectId.isEmpty) {
 setDialogState(() => isUploading = false);
 return;
 }
 final result =
 await FileUploadHelper.pickAndUpload(
 folder: 'backend-design-documents',
 projectId: projectId,
 allowedExtensions:
 FileUploadHelper.documentExtensions,
 );
 if (result != null) {
 setDialogState(() {
 uploadedFileName = result.fileName;
 uploadedFileUrl = result.downloadUrl;
 uploadedStoragePath = result.storagePath;
 isUploading = false;
 });
 } else {
 setDialogState(() => isUploading = false);
 }
 },
 icon: isUploading
 ? const SizedBox(
 width: 16,
 height: 16,
 child:
 CircularProgressIndicator(strokeWidth: 2))
 : const Icon(Icons.attach_file, size: 18),
 label:
 Text(isUploading ? 'Uploading...' : 'Choose File'),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF10B981),
 side: const BorderSide(color: Color(0xFF10B981)),
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
 confirmLabel: existing == null ? 'Add document' : 'Save changes',
 );
 if (saved != true) return;

 final item = _DesignDocument(
 id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
 title: titleController.text.trim(),
 description: descriptionController.text.trim(),
 owner: owner,
 status: status,
 location: locationController.text.trim(),
 uploadedFileName: uploadedFileName,
 uploadedFileUrl: uploadedFileUrl,
 uploadedStoragePath: uploadedStoragePath,
 );
 setState(() {
 if (existing == null) {
 _designDocuments.add(item);
 } else {
 final index =
 _designDocuments.indexWhere((entry) => entry.id == existing.id);
 if (index != -1) _designDocuments[index] = item;
 }
 });
 _scheduleSave();
 _logActivity(
 existing == null
 ? 'Added design document row'
 : 'Edited design document row',
 details: {'itemId': item.id},
 );
 }

 Future<void> _openEntityDialog({_DbEntity? existing}) async {
 final nameController = TextEditingController(text: existing?.name ?? '');
 final primaryKeyController =
 TextEditingController(text: existing?.primaryKey ?? '');
 final descriptionController =
 TextEditingController(text: existing?.description ?? '');
 final ownerOptions = _ownerOptions(currentValue: existing?.owner);
 String owner = existing?.owner.isNotEmpty == true
 ? existing!.owner
 : ownerOptions.first;
 final saved = await _showBackendDialog(
 title: existing == null ? 'Add data entity' : 'Edit data entity',
 content: StatefulBuilder(
 builder: (context, setDialogState) => Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: nameController,
 decoration: const InputDecoration(
 labelText: 'Entity / collection',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 8),
 _buildKazAiPillButton(
 label: 'entity name',
 controller: nameController,
 setDialogState: setDialogState,
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: primaryKeyController,
 decoration: const InputDecoration(
 labelText: 'Primary key',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 8),
 _buildKazAiPillButton(
 label: 'primary key field',
 controller: primaryKeyController,
 setDialogState: setDialogState,
 ),
 ],
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: owner,
 items: ownerOptions
 .map((option) =>
 DropdownMenuItem(value: option, child: Text(option)))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setDialogState(() => owner = value);
 },
 decoration: const InputDecoration(
 labelText: 'Owner',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: descriptionController,
 minLines: 2,
 maxLines: 4,
 decoration: const InputDecoration(
 labelText: 'Description',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 8),
 _buildKazAiPillButton(
 label: 'entity description',
 controller: descriptionController,
 setDialogState: setDialogState,
 ),
 ],
 ),
 ],
 ),
 ),
 confirmLabel: existing == null ? 'Add entity' : 'Save changes',
 );
 if (saved != true) return;

 final item = _DbEntity(
 id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
 name: nameController.text.trim(),
 primaryKey: primaryKeyController.text.trim(),
 owner: owner,
 description: descriptionController.text.trim(),
 );
 setState(() {
 if (existing == null) {
 _entities.add(item);
 } else {
 final index = _entities.indexWhere((entry) => entry.id == existing.id);
 if (index != -1) _entities[index] = item;
 }
 });
 _scheduleSave();
 _logActivity(
 existing == null ? 'Added data entity row' : 'Edited data entity row',
 details: {'itemId': item.id},
 );
 }

 Future<void> _openFieldDialog({_DbField? existing}) async {
 final tableController = TextEditingController(text: existing?.table ?? '');
 final fieldController = TextEditingController(text: existing?.field ?? '');
 final typeController = TextEditingController(text: existing?.type ?? '');
 final constraintsController =
 TextEditingController(text: existing?.constraints ?? '');
 final notesController = TextEditingController(text: existing?.notes ?? '');
 final saved = await _showBackendDialog(
 title: existing == null ? 'Add field' : 'Edit field',
 content: StatefulBuilder(
 builder: (context, setDialogState) => Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: tableController,
 decoration: const InputDecoration(
 labelText: 'Entity / table',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 8),
 _buildKazAiPillButton(
 label: 'entity name',
 controller: tableController,
 setDialogState: setDialogState,
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: fieldController,
 decoration: const InputDecoration(
 labelText: 'Field name',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 8),
 _buildKazAiPillButton(
 label: 'field name',
 controller: fieldController,
 setDialogState: setDialogState,
 ),
 ],
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: typeController,
 decoration: const InputDecoration(
 labelText: 'Type',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: constraintsController,
 decoration: const InputDecoration(
 labelText: 'Constraints',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: notesController,
 minLines: 2,
 maxLines: 4,
 decoration: const InputDecoration(
 labelText: 'Notes',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 8),
 _buildKazAiPillButton(
 label: 'field notes',
 controller: notesController,
 setDialogState: setDialogState,
 ),
 ],
 ),
 ],
 ),
 ),
 confirmLabel: existing == null ? 'Add field' : 'Save changes',
 );
 if (saved != true) return;

 final item = _DbField(
 id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
 table: tableController.text.trim(),
 field: fieldController.text.trim(),
 type: typeController.text.trim(),
 constraints: constraintsController.text.trim(),
 notes: notesController.text.trim(),
 );
 setState(() {
 if (existing == null) {
 _fields.add(item);
 } else {
 final index = _fields.indexWhere((entry) => entry.id == existing.id);
 if (index != -1) _fields[index] = item;
 }
 });
 _scheduleSave();
 _logActivity(
 existing == null ? 'Added field row' : 'Edited field row',
 details: {'itemId': item.id},
 );
 }

 Future<bool?> _showBackendDialog({
 required String title,
 required Widget content,
 required String confirmLabel,
 }) {
 return showDialog<bool>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: Text(title),
 content:
 SizedBox(width: 560, child: SingleChildScrollView(child: content)),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(dialogContext).pop(true),
 child: Text(confirmLabel),
 ),
 ],
 ),
 );
 }

 void _updateField(_DbField updated) {
 final index = _fields.indexWhere((entry) => entry.id == updated.id);
 if (index == -1) return;
 setState(() => _fields[index] = updated);
 _scheduleSave();
 }

 void _deleteField(String id) {
 setState(() => _fields.removeWhere((entry) => entry.id == id));
 _scheduleSave();
 _logActivity('Deleted field row', details: {'itemId': id});
 }

 // ─── Table Builders ────────────────────────────────────────────────────────

 Widget _buildComponentsTable() {
 final columns = [
 const _TableColumnDef('Component', 200),
 const _TableColumnDef('Type', 140),
 const _TableColumnDef('Responsibility', 240),
 const _TableColumnDef('Owner', 160),
 const _TableColumnDef('Status', 140),
 const _TableColumnDef('', 56),
 const _TableColumnDef('', 56),
 const _TableColumnDef('', 56),
 ];

 if (_components.isEmpty) {
 return const _InlineEmptyState(
 title: 'No components yet',
 message: 'Add backend components to define the architecture.',
 );
 }

 return _EditableTable(
 columns: columns,
 rows: [
 for (final entry in _components)
 _EditableRow(
 key: ValueKey(entry.id),
 columns: columns,
 cells: [
 _TextCell(
 value: entry.name,
 fieldKey: '${entry.id}_name',
 hintText: 'Component',
 onChanged: (value) =>
 _updateComponent(entry.copyWith(name: value)),
 ),
 _DropdownCell(
 value: entry.type,
 fieldKey: '${entry.id}_type',
 options: _componentTypes,
 onChanged: (value) =>
 _updateComponent(entry.copyWith(type: value)),
 ),
 _TextCell(
 value: entry.responsibility,
 fieldKey: '${entry.id}_responsibility',
 hintText: 'Responsibility',
 maxLines: 2,
 onChanged: (value) =>
 _updateComponent(entry.copyWith(responsibility: value)),
 ),
 _DropdownCell(
 value: entry.owner,
 fieldKey: '${entry.id}_owner',
 options: _ownerOptions(currentValue: entry.owner),
 onChanged: (value) =>
 _updateComponent(entry.copyWith(owner: value)),
 ),
 _DropdownCell(
 value: entry.status,
 fieldKey: '${entry.id}_status',
 options: _componentStatuses,
 onChanged: (value) =>
 _updateComponent(entry.copyWith(status: value)),
 ),
 _WidgetCell(
 child: _buildKazAiRowButton(
 'component_${entry.id}',
 'component description',
 'component',
 () => _updateComponent(entry.copyWith(responsibility: 'AI-generated description')),
 ),
 ),
 _EditCell(
 onPressed: () => _openComponentDialog(existing: entry),
 ),
 _DeleteCell(onPressed: () => _deleteComponent(entry.id)),
 ],
 ),
 ],
 );
 }

 Widget _buildFieldsTable() {
 final columns = [
 const _TableColumnDef('Entity/Table', 160),
 const _TableColumnDef('Field', 160),
 const _TableColumnDef('Type', 140),
 const _TableColumnDef('Constraints', 200),
 const _TableColumnDef('Notes', 220),
 const _TableColumnDef('', 56),
 const _TableColumnDef('', 56),
 const _TableColumnDef('', 56),
 ];

 if (_fields.isEmpty) {
 return const _InlineEmptyState(
 title: 'No fields yet',
 message: 'Define columns, types, and constraints.',
 );
 }

 return _EditableTable(
 columns: columns,
 rows: [
 for (final entry in _fields)
 _EditableRow(
 key: ValueKey(entry.id),
 columns: columns,
 cells: [
 _TextCell(
 value: entry.table,
 fieldKey: '${entry.id}_table',
 hintText: 'Entity',
 onChanged: (value) =>
 _updateField(entry.copyWith(table: value)),
 ),
 _TextCell(
 value: entry.field,
 fieldKey: '${entry.id}_field',
 hintText: 'Field',
 onChanged: (value) =>
 _updateField(entry.copyWith(field: value)),
 ),
 _TextCell(
 value: entry.type,
 fieldKey: '${entry.id}_type',
 hintText: 'Type',
 onChanged: (value) => _updateField(entry.copyWith(type: value)),
 ),
 _TextCell(
 value: entry.constraints,
 fieldKey: '${entry.id}_constraints',
 hintText: 'Constraints',
 onChanged: (value) =>
 _updateField(entry.copyWith(constraints: value)),
 ),
 _TextCell(
 value: entry.notes,
 fieldKey: '${entry.id}_notes',
 hintText: 'Notes',
 maxLines: 2,
 onChanged: (value) =>
 _updateField(entry.copyWith(notes: value)),
 ),
 _WidgetCell(
 child: _buildKazAiRowButton(
 'field_${entry.id}',
 'field notes',
 'database field',
 () => _updateField(entry.copyWith(notes: 'AI-generated notes')),
 ),
 ),
 _EditCell(
 onPressed: () => _openFieldDialog(existing: entry),
 ),
 _DeleteCell(onPressed: () => _deleteField(entry.id)),
 ],
 ),
 ],
 );
 }
}

// ─── Panel Shell Widget ──────────────────────────────────────────────────────

class _PanelShell extends StatelessWidget {
 const _PanelShell({
 required this.title,
 required this.subtitle,
 required this.child,
 this.trailing,
 });

 final String title;
 final String subtitle;
 final Widget child;
 final Widget? trailing;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(20),
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
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
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
 if (trailing != null) trailing!,
 ],
 ),
 const SizedBox(height: 16),
 child,
 ],
 ),
 );
 }
}

// ─── Snapshot & Data Model Classes ───────────────────────────────────────────

class _BackendInfrastructureSnapshot {
 const _BackendInfrastructureSnapshot({
 required this.projectLabel,
 required this.systemNodes,
 required this.systemLinks,
 required this.dataEntities,
 required this.interfaceContracts,
 required this.accessRules,
 required this.logicRules,
 required this.performanceStrategies,
 required this.vendorDependencies,
 required this.pipelineStages,
 required this.aiSignalCount,
 });

 final String projectLabel;
 final List<_SystemNodeItem> systemNodes;
 final List<_SystemLinkItem> systemLinks;
 final List<_DataEntityItem> dataEntities;
 final List<_InterfaceContractItem> interfaceContracts;
 final List<_AccessRuleItem> accessRules;
 final List<_LogicRuleItem> logicRules;
 final List<_PerformanceStrategyItem> performanceStrategies;
 final List<_VendorDependencyItem> vendorDependencies;
 final List<_PipelineStageItem> pipelineStages;
 final int aiSignalCount;

 factory _BackendInfrastructureSnapshot.from({
 required ProjectDataModel projectData,
 required Map<String, dynamic>? architectureWorkspace,
 required String architectureSummary,
 required String databaseSummary,
 required List<_ArchitectureComponent> components,
 required List<_ArchitectureDataFlow> dataFlows,
 required List<_DesignDocument> documents,
 required List<_DbEntity> entities,
 required List<_DbField> fields,
 }) {
 final projectLabel = projectData.projectName.trim().isNotEmpty
 ? projectData.projectName.trim()
 : 'the current design package';
 final summaryContext =
 '$architectureSummary $databaseSummary'.toLowerCase();
 final documentLocations = documents
 .map((document) => document.location.trim())
 .where((location) => location.isNotEmpty)
 .toList();

 final workspaceNodes =
 ((architectureWorkspace?['nodes'] as List?) ?? const [])
 .whereType<Map>()
 .map((raw) => Map<String, dynamic>.from(raw))
 .toList();
 final workspaceEdges =
 ((architectureWorkspace?['edges'] as List?) ?? const [])
 .whereType<Map>()
 .map((raw) => Map<String, dynamic>.from(raw))
 .toList();

 final systemNodes = <_SystemNodeItem>[];
 if (workspaceNodes.isNotEmpty) {
 for (final node in workspaceNodes.take(5)) {
 final label = node['label']?.toString().trim() ?? '';
 if (label.isEmpty) continue;
 systemNodes.add(_SystemNodeItem(
 name: label,
 type: _typeForLabel(label),
 status: 'Mapped',
 hostLocation: documentLocations.isNotEmpty
 ? documentLocations.first
 : _hostForLabel(label),
 ));
 }
 }
 if (systemNodes.isEmpty) {
 for (final component in components.take(5)) {
 final name = component.name.trim();
 if (name.isEmpty) continue;
 systemNodes.add(_SystemNodeItem(
 name: name,
 type: component.type.trim().isNotEmpty
 ? component.type.trim()
 : 'Service',
 status: component.status.trim().isNotEmpty
 ? component.status.trim()
 : 'Planned',
 hostLocation: documentLocations.isNotEmpty
 ? documentLocations.first
 : _hostForComponent(name, component.type),
 ));
 }
 }
 if (systemNodes.isEmpty) {
 systemNodes.addAll(const [
 _SystemNodeItem(
 name: 'Database',
 type: 'Data store',
 status: 'Planned',
 hostLocation: 'AWS Cloud',
 ),
 _SystemNodeItem(
 name: 'Auth Server',
 type: 'Service',
 status: 'Planned',
 hostLocation: 'AWS Cloud',
 ),
 _SystemNodeItem(
 name: 'Power Grid',
 type: 'Integration',
 status: 'In review',
 hostLocation: 'Venue Power Grid',
 ),
 _SystemNodeItem(
 name: 'HVAC System',
 type: 'Integration',
 status: 'Planned',
 hostLocation: 'Plant Room',
 ),
 ]);
 }

 final labelById = <String, String>{
 for (final node in workspaceNodes)
 if ((node['id']?.toString().trim() ?? '').isNotEmpty)
 node['id']!.toString(): node['label']?.toString() ?? '',
 };
 final systemLinks = <_SystemLinkItem>[];
 for (final edge in workspaceEdges.take(4)) {
 final from = labelById[edge['from']?.toString() ?? ''] ?? '';
 final to = labelById[edge['to']?.toString() ?? ''] ?? '';
 if (from.isEmpty || to.isEmpty) continue;
 systemLinks.add(_SystemLinkItem(
 from: from,
 to: to,
 location: _locationForLink(from, to),
 ));
 }
 if (systemLinks.isEmpty) {
 for (final flow in dataFlows.take(4)) {
 final source = flow.source.trim();
 final destination = flow.destination.trim();
 if (source.isEmpty || destination.isEmpty) continue;
 systemLinks.add(_SystemLinkItem(
 from: source,
 to: destination,
 location: _locationForLink(source, destination),
 ));
 }
 }
 if (systemLinks.isEmpty) {
 systemLinks.addAll(const [
 _SystemLinkItem(
 from: 'API Gateway',
 to: 'Operational Data Store',
 location: 'AWS Cloud',
 ),
 _SystemLinkItem(
 from: 'Fire Alarm Panel',
 to: 'Sprinkler and Ops Escalation',
 location: 'Venue Plant Room',
 ),
 ]);
 }

 final groupedFields = <String, List<_DbField>>{};
 for (final field in fields) {
 final key = field.table.trim();
 if (key.isEmpty) continue;
 groupedFields.putIfAbsent(key, () => []).add(field);
 }

 final dataEntities = <_DataEntityItem>[];
 for (final entity in entities.take(4)) {
 final name = entity.name.trim();
 if (name.isEmpty) continue;
 final attributes = groupedFields[name]
 ?.take(3)
 .map((field) => field.field.trim())
 .where((value) => value.isNotEmpty)
 .toList() ??
 [];
 final primaryKey = entity.primaryKey.trim();
 dataEntities.add(_DataEntityItem(
 name: name,
 attributes: attributes.isNotEmpty
 ? attributes
 : [if (primaryKey.isNotEmpty) primaryKey else 'key_attribute'],
 flowLabel: _flowLabelForEntity(name),
 flowDetail: entity.description.trim().isNotEmpty
 ? entity.description.trim()
 : 'Moves from operational input to controlled storage and reporting.',
 ));
 }
 if (dataEntities.isEmpty) {
 dataEntities.addAll(const [
 _DataEntityItem(
 name: 'UserProfile',
 attributes: ['name', 'access_level', 'contact'],
 flowLabel: 'Input -> Storage',
 flowDetail:
 'User and operator identity records for permissions and communication.',
 ),
 _DataEntityItem(
 name: 'GuestList',
 attributes: ['guest_name', 'dietary_restriction', 'ticket_class'],
 flowLabel: 'Capture -> Ops',
 flowDetail:
 'Registration data passed into catering, seating, and access workflows.',
 ),
 _DataEntityItem(
 name: 'MaterialStock',
 attributes: ['sku', 'quantity', 'weight_kg'],
 flowLabel: 'Inventory -> Site',
 flowDetail:
 'Material issue and replenishment flow for physical production planning.',
 ),
 ]);
 }

 final interfaceContracts = <_InterfaceContractItem>[];
 for (final flow in dataFlows.take(4)) {
 final source = flow.source.trim();
 final destination = flow.destination.trim();
 if (source.isEmpty || destination.isEmpty) continue;
 interfaceContracts.add(_InterfaceContractItem(
 name: '$source -> $destination',
 method: flow.protocol.trim().isNotEmpty ? flow.protocol.trim() : 'REST',
 ioDescription: flow.notes.trim().isNotEmpty
 ? flow.notes.trim()
 : 'Input from $source, output to $destination.',
 ));
 }
 if (interfaceContracts.isEmpty) {
 interfaceContracts.addAll(const [
 _InterfaceContractItem(
 name: 'Payment Gateway API',
 method: 'REST',
 ioDescription:
 'Payment request in, authorization status and receipt out.',
 ),
 _InterfaceContractItem(
 name: 'Weather Service',
 method: 'WebSocket',
 ioDescription: 'Weather feed in, event contingency trigger out.',
 ),
 _InterfaceContractItem(
 name: 'Catering Handoff',
 method: 'Manual Handoff',
 ioDescription:
 'Headcount and dietary changes in, service readiness confirmation out.',
 ),
 ]);
 }

 final roles = projectData.teamMembers
 .map((member) => member.role.trim())
 .where((value) => value.isNotEmpty)
 .toSet()
 .toList();
 if (roles.isEmpty) {
 roles.addAll(['Admin', 'Vendor', 'Operations', 'Public']);
 }
 final accessRules = roles.take(4).map((role) {
 final lower = role.toLowerCase();
 if (lower.contains('security') || lower.contains('admin')) {
 return const _AccessRuleItem(
 role: 'Admin',
 permission: 'Read, write, delete, and edit structural plans',
 protocol: 'OAuth 2.0',
 );
 }
 if (lower.contains('vendor')) {
 return const _AccessRuleItem(
 role: 'Vendor',
 permission:
 'Read operational schedule and access assigned zones only',
 protocol: 'Key Card System',
 );
 }
 if (lower.contains('ops') || lower.contains('operations')) {
 return const _AccessRuleItem(
 role: 'Operations',
 permission:
 'Read live status, update logistics checkpoints, access back-of-house',
 protocol: 'Biometric Scanner',
 );
 }
 return const _AccessRuleItem(
 role: 'Public',
 permission: 'Read approved schedules and ticket status only',
 protocol: 'Wristband Access',
 );
 }).toList();

 final logicRules = [
 const _LogicRuleItem(
 name: 'Capacity Limit',
 condition: 'crowd density rises above the approved threshold',
 action: 'pause entry, redirect arrivals, and notify operations control',
 ),
 const _LogicRuleItem(
 name: 'Rain Contingency',
 condition: 'rain forecast exceeds 5mm during the live window',
 action:
 'switch event flow to Hall B and reroute power and signage plans',
 ),
 const _LogicRuleItem(
 name: 'Stock Reorder Trigger',
 condition: 'material stock drops below the safety buffer',
 action: 'create a replenishment request and alert procurement',
 ),
 const _LogicRuleItem(
 name: 'Access Escalation',
 condition: 'an unapproved credential attempts secure-zone entry',
 action: 'deny access and log an incident for security review',
 ),
 ];

 final performanceStrategies = [
 const _PerformanceStrategyItem(
 metric: 'Response Time',
 target: '< 250ms',
 strategy: 'Caching, edge routing, and lean payload contracts.',
 context: 'Supports high-traffic app and scanner validation peaks.',
 ),
 const _PerformanceStrategyItem(
 metric: 'Throughput',
 target: '10k requests/min',
 strategy: 'Load balancing and queue-based retry handling.',
 context: 'Protects check-in and live operations workflows.',
 ),
 const _PerformanceStrategyItem(
 metric: 'Load Bearing Capacity',
 target: '<= approved stage load',
 strategy: 'Reinforced flooring and staged equipment placement.',
 context: 'Ensures hidden structural systems support visible outputs.',
 ),
 _PerformanceStrategyItem(
 metric: 'Voltage Load',
 target: summaryContext.contains('generator')
 ? 'Generator-backed load approved'
 : 'Within venue power envelope',
 strategy: 'Generator backup and split power zones.',
 context:
 'Prevents backend operations and stage services from overload.',
 ),
 ];

 final vendorDependencies = projectData.vendors.isNotEmpty
 ? projectData.vendors.take(4).map((vendor) {
 return _VendorDependencyItem(
 service: vendor.name.trim().isNotEmpty
 ? vendor.name.trim()
 : 'External Vendor',
 purpose: vendor.equipmentOrService.trim().isNotEmpty
 ? vendor.equipmentOrService.trim()
 : 'Operational support service',
 status: vendor.status.trim().isNotEmpty
 ? vendor.status.trim()
 : vendor.procurementStage.trim().isNotEmpty
 ? vendor.procurementStage.trim()
 : 'Pending',
 );
 }).toList()
 : [
 const _VendorDependencyItem(
 service: 'Stripe',
 purpose: 'Payment authorization and settlement.',
 status: 'API Key Ready',
 ),
 const _VendorDependencyItem(
 service: 'Power Generator Rental',
 purpose:
 'Backup power for stage, registration, and back-of-house operations.',
 status: 'Contract Signed',
 ),
 const _VendorDependencyItem(
 service: 'Waste Management',
 purpose:
 'Supports backend site logistics and environmental compliance.',
 status: 'Pending',
 ),
 const _VendorDependencyItem(
 service: 'Security Crew',
 purpose:
 'Zone control, credential checks, and incident escalation.',
 status: 'Pending',
 ),
 ];

 final pipelineStages = const [
 _PipelineStageItem(
 environment: 'Staging',
 label: 'Validate',
 steps:
 'CI build -> integration tests -> sandbox scanners and mock vendor handoffs.',
 ),
 _PipelineStageItem(
 environment: 'Production',
 label: 'Release',
 steps:
 'Deploy services -> verify monitoring -> enable live traffic and escalation alerts.',
 ),
 _PipelineStageItem(
 environment: 'Mock-up Site',
 label: 'Rehearse',
 steps:
 'Prefabrication checks -> test kitchen rehearsal -> site safety sign-off.',
 ),
 _PipelineStageItem(
 environment: 'On-site Assembly',
 label: 'Activate',
 steps: 'Shipping -> install -> commissioning -> operational handover.',
 ),
 ];

 final aiSignalCount = projectData.aiUsageCounts.values.fold<int>(
 0,
 (total, value) => total + value,
 ) +
 projectData.aiRecommendations.length +
 projectData.aiIntegrations.length;

 return _BackendInfrastructureSnapshot(
 projectLabel: projectLabel,
 systemNodes: systemNodes,
 systemLinks: systemLinks,
 dataEntities: dataEntities,
 interfaceContracts: interfaceContracts,
 accessRules: accessRules,
 logicRules: logicRules,
 performanceStrategies: performanceStrategies,
 vendorDependencies: vendorDependencies,
 pipelineStages: pipelineStages,
 aiSignalCount: aiSignalCount,
 );
 }

 static String _typeForLabel(String label) {
 final normalized = label.toLowerCase();
 if (normalized.contains('db') || normalized.contains('data')) {
 return 'Data store';
 }
 if (normalized.contains('power') ||
 normalized.contains('hvac') ||
 normalized.contains('alarm')) {
 return 'Integration';
 }
 if (normalized.contains('queue')) return 'Queue';
 if (normalized.contains('api') || normalized.contains('auth')) {
 return 'Service';
 }
 return 'Component';
 }

 static String _hostForLabel(String label) {
 final normalized = label.toLowerCase();
 if (normalized.contains('power')) return 'Venue Power Grid';
 if (normalized.contains('hvac')) return 'Plant Room';
 if (normalized.contains('alarm')) return 'Fire Control Panel';
 if (normalized.contains('db') || normalized.contains('data')) {
 return 'AWS Cloud';
 }
 if (normalized.contains('auth') || normalized.contains('api')) {
 return 'Cloud Compute Cluster';
 }
 return 'Back of House Operations';
 }

 static String _hostForComponent(String name, String type) {
 final normalized = '$name $type'.toLowerCase();
 if (normalized.contains('power')) return 'Venue Power Grid';
 if (normalized.contains('hvac')) return 'Plant Room';
 if (normalized.contains('data')) return 'Managed Database Cluster';
 if (normalized.contains('integration')) return 'Vendor Edge Network';
 if (normalized.contains('analytics')) return 'Reporting Warehouse';
 return 'AWS Cloud';
 }

 static String _locationForLink(String from, String to) {
 final combined = '$from $to'.toLowerCase();
 if (combined.contains('power') || combined.contains('hvac')) {
 return 'Plant / Site';
 }
 if (combined.contains('scanner') || combined.contains('guest')) {
 return 'Edge -> Cloud';
 }
 return 'Core Platform';
 }

 static String _flowLabelForEntity(String name) {
 final normalized = name.toLowerCase();
 if (normalized.contains('guest')) return 'Capture -> Ops';
 if (normalized.contains('stock') || normalized.contains('material')) {
 return 'Inventory -> Site';
 }
 if (normalized.contains('access')) return 'Identity -> Control';
 return 'Input -> Storage';
 }
}

class _SystemNodeItem {
 const _SystemNodeItem({
 required this.name,
 required this.type,
 required this.status,
 required this.hostLocation,
 });

 final String name;
 final String type;
 final String status;
 final String hostLocation;
}

class _SystemLinkItem {
 const _SystemLinkItem({
 required this.from,
 required this.to,
 required this.location,
 });

 final String from;
 final String to;
 final String location;
}

class _DataEntityItem {
 const _DataEntityItem({
 required this.name,
 required this.attributes,
 required this.flowLabel,
 required this.flowDetail,
 });

 final String name;
 final List<String> attributes;
 final String flowLabel;
 final String flowDetail;
}

class _InterfaceContractItem {
 const _InterfaceContractItem({
 required this.name,
 required this.method,
 required this.ioDescription,
 });

 final String name;
 final String method;
 final String ioDescription;
}

class _AccessRuleItem {
 const _AccessRuleItem({
 required this.role,
 required this.permission,
 required this.protocol,
 });

 final String role;
 final String permission;
 final String protocol;
}

class _LogicRuleItem {
 const _LogicRuleItem({
 required this.name,
 required this.condition,
 required this.action,
 });

 final String name;
 final String condition;
 final String action;
}

class _PerformanceStrategyItem {
 const _PerformanceStrategyItem({
 required this.metric,
 required this.target,
 required this.strategy,
 required this.context,
 });

 final String metric;
 final String target;
 final String strategy;
 final String context;
}

class _VendorDependencyItem {
 const _VendorDependencyItem({
 required this.service,
 required this.purpose,
 required this.status,
 });

 final String service;
 final String purpose;
 final String status;
}

class _PipelineStageItem {
 const _PipelineStageItem({
 required this.environment,
 required this.label,
 required this.steps,
 });

 final String environment;
 final String label;
 final String steps;
}

class _LabeledTextArea extends StatelessWidget {
 const _LabeledTextArea({
 required this.label,
 required this.controller,
 required this.hintText,
 });

 final String label;
 final TextEditingController controller;
 final String hintText;

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF374151))),
 const SizedBox(height: 6),
 VoiceTextField(
 controller: controller,
 maxLines: 3,
 decoration: InputDecoration(
 hintText: hintText,
 filled: true,
 fillColor: Colors.white,
 border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
 ),
 style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
 ),
 ],
 );
 }
}

class _SectionHeader extends StatelessWidget {
 const _SectionHeader({
 required this.title,
 required this.actionLabel,
 required this.onAction,
 });

 final String title;
 final String actionLabel;
 final VoidCallback onAction;

 @override
 Widget build(BuildContext context) {
 return Row(
 children: [
 Expanded(
 child: Text(title,
 style:
 const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
 ),
 TextButton.icon(
 onPressed: onAction,
 icon: const Icon(Icons.add, size: 16),
 label: Text(actionLabel),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF2563EB),
 padding: EdgeInsets.zero,
 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
 minimumSize: const Size(0, 32),
 ),
 ),
 ],
 );
 }
}

class _EditableTable extends StatelessWidget {
 const _EditableTable({required this.columns, required this.rows});

 final List<_TableColumnDef> columns;
 final List<_EditableRow> rows;

 @override
 Widget build(BuildContext context) {
 final header = Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Row(
 children: columns
 .map((column) => SizedBox(
 width: column.width,
 child: Text(
 column.label.toUpperCase(),
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 letterSpacing: 0.7,
 color: Color(0xFF6B7280)),
 ),
 ))
 .toList(),
 ),
 );

 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: ConstrainedBox(
 constraints: BoxConstraints(
 minWidth:
 columns.fold<double>(0, (total, col) => total + col.width)),
 child: Column(
 children: [
 header,
 const SizedBox(height: 8),
 for (int i = 0; i < rows.length; i++)
 Container(
 margin: const EdgeInsets.only(bottom: 10),
 padding:
 const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: i.isEven ? Colors.white : const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: rows[i],
 ),
 ],
 ),
 ),
 );
 }
}

class _EditableRow extends StatelessWidget {
 const _EditableRow({super.key, required this.columns, required this.cells});

 final List<_TableColumnDef> columns;
 final List<Widget> cells;

 @override
 Widget build(BuildContext context) {
 return Row(
 children: List.generate(
 cells.length,
 (index) => SizedBox(width: columns[index].width, child: cells[index]),
 ),
 );
 }
}

class _TableColumnDef {
 const _TableColumnDef(this.label, this.width);

 final String label;
 final double width;
}

class _TextCell extends StatelessWidget {
 const _TextCell({
 required this.value,
 required this.fieldKey,
 required this.onChanged,
 this.hintText,
 this.maxLines = 1,
 });

 final String value;
 final String fieldKey;
 final ValueChanged<String> onChanged;
 final String? hintText;
 final int maxLines;

 @override
 Widget build(BuildContext context) {
 return VoiceTextFormField(
 key: ValueKey(fieldKey),
 initialValue: value,
 maxLines: maxLines,
 decoration: InputDecoration(
 hintText: hintText,
 isDense: true,
 border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
 filled: true,
 fillColor: Colors.white,
 contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
 ),
 style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
 onChanged: onChanged,
 );
 }
}

class _DropdownCell extends StatelessWidget {
 const _DropdownCell({
 required this.value,
 required this.fieldKey,
 required this.options,
 required this.onChanged,
 });

 final String value;
 final String fieldKey;
 final List<String> options;
 final ValueChanged<String> onChanged;

 @override
 Widget build(BuildContext context) {
 final resolved = options.contains(value) ? value : options.first;
 return DropdownButtonFormField<String>(
 key: ValueKey(fieldKey),
 value: resolved,
 items: options
 .map((option) => DropdownMenuItem(value: option, child: Text(option)))
 .toList(),
 onChanged: (value) {
 if (value != null) onChanged(value);
 },
 decoration: InputDecoration(
 isDense: true,
 border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
 filled: true,
 fillColor: Colors.white,
 contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
 ),
 style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
 );
 }
}

class _WidgetCell extends StatelessWidget {
 const _WidgetCell({required this.child});

 final Widget child;

 @override
 Widget build(BuildContext context) {
 return Center(child: child);
 }
}

class _DeleteCell extends StatelessWidget {
 const _DeleteCell({required this.onPressed});

 final VoidCallback onPressed;

 @override
 Widget build(BuildContext context) {
 return IconButton(
 onPressed: onPressed,
 icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
 );
 }
}

class _EditCell extends StatelessWidget {
 const _EditCell({required this.onPressed});

 final VoidCallback onPressed;

 @override
 Widget build(BuildContext context) {
 return IconButton(
 onPressed: onPressed,
 icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB)),
 tooltip: 'Edit',
 );
 }
}

class _InlineEmptyState extends StatelessWidget {
 const _InlineEmptyState({required this.title, required this.message});

 final String title;
 final String message;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 children: [
 Container(
 width: 32,
 height: 32,
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7ED),
 borderRadius: BorderRadius.circular(8),
 ),
 child: const Icon(Icons.info_outline,
 size: 18, color: Color(0xFFF59E0B)),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(title,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 const SizedBox(height: 4),
 Text(message,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF6B7280))),
 ],
 ),
 ),
 ],
 ),
 );
 }
}

class _ArchitectureComponent {
 const _ArchitectureComponent({
 required this.id,
 required this.name,
 required this.type,
 required this.responsibility,
 required this.owner,
 required this.status,
 });

 final String id;
 final String name;
 final String type;
 final String responsibility;
 final String owner;
 final String status;

 _ArchitectureComponent copyWith({
 String? name,
 String? type,
 String? responsibility,
 String? owner,
 String? status,
 }) {
 return _ArchitectureComponent(
 id: id,
 name: name ?? this.name,
 type: type ?? this.type,
 responsibility: responsibility ?? this.responsibility,
 owner: owner ?? this.owner,
 status: status ?? this.status,
 );
 }

 Map<String, dynamic> toJson() {
 return {
 'id': id,
 'name': name,
 'type': type,
 'responsibility': responsibility,
 'owner': owner,
 'status': status,
 };
 }

 static List<_ArchitectureComponent> fromList(dynamic raw) {
 if (raw is! List) return [];
 return raw.whereType<Map>().map((item) {
 final data = Map<String, dynamic>.from(item);
 return _ArchitectureComponent(
 id: data['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 name: data['name']?.toString() ?? '',
 type: data['type']?.toString() ?? 'Service',
 responsibility: data['responsibility']?.toString() ?? '',
 owner: data['owner']?.toString() ?? '',
 status: data['status']?.toString() ?? 'Planned',
 );
 }).toList();
 }
}

class _ArchitectureDataFlow {
 const _ArchitectureDataFlow({
 required this.id,
 required this.source,
 required this.destination,
 required this.protocol,
 required this.notes,
 });

 final String id;
 final String source;
 final String destination;
 final String protocol;
 final String notes;

 _ArchitectureDataFlow copyWith({
 String? source,
 String? destination,
 String? protocol,
 String? notes,
 }) {
 return _ArchitectureDataFlow(
 id: id,
 source: source ?? this.source,
 destination: destination ?? this.destination,
 protocol: protocol ?? this.protocol,
 notes: notes ?? this.notes,
 );
 }

 Map<String, dynamic> toJson() {
 return {
 'id': id,
 'source': source,
 'destination': destination,
 'protocol': protocol,
 'notes': notes,
 };
 }

 static List<_ArchitectureDataFlow> fromList(dynamic raw) {
 if (raw is! List) return [];
 return raw.whereType<Map>().map((item) {
 final data = Map<String, dynamic>.from(item);
 return _ArchitectureDataFlow(
 id: data['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 source: data['source']?.toString() ?? '',
 destination: data['destination']?.toString() ?? '',
 protocol: data['protocol']?.toString() ?? 'HTTP',
 notes: data['notes']?.toString() ?? '',
 );
 }).toList();
 }
}

class _DesignDocument {
 const _DesignDocument({
 required this.id,
 required this.title,
 required this.description,
 required this.owner,
 required this.status,
 required this.location,
 this.uploadedFileName,
 this.uploadedFileUrl,
 this.uploadedStoragePath,
 });

 final String id;
 final String title;
 final String description;
 final String owner;
 final String status;
 final String location;
 final String? uploadedFileName;
 final String? uploadedFileUrl;
 final String? uploadedStoragePath;

 bool get hasUploadedFile =>
 uploadedFileName != null && uploadedFileName!.isNotEmpty;

 _DesignDocument copyWith({
 String? title,
 String? description,
 String? owner,
 String? status,
 String? location,
 String? uploadedFileName,
 String? uploadedFileUrl,
 String? uploadedStoragePath,
 }) {
 return _DesignDocument(
 id: id,
 title: title ?? this.title,
 description: description ?? this.description,
 owner: owner ?? this.owner,
 status: status ?? this.status,
 location: location ?? this.location,
 uploadedFileName: uploadedFileName ?? this.uploadedFileName,
 uploadedFileUrl: uploadedFileUrl ?? this.uploadedFileUrl,
 uploadedStoragePath:
 uploadedStoragePath ?? this.uploadedStoragePath,
 );
 }

 Map<String, dynamic> toJson() {
 return {
 'id': id,
 'title': title,
 'description': description,
 'owner': owner,
 'status': status,
 'location': location,
 'uploadedFileName': uploadedFileName,
 'uploadedFileUrl': uploadedFileUrl,
 'uploadedStoragePath': uploadedStoragePath,
 };
 }

 static List<_DesignDocument> fromList(dynamic raw) {
 if (raw is! List) return [];
 return raw.whereType<Map>().map((item) {
 final data = Map<String, dynamic>.from(item);
 return _DesignDocument(
 id: data['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 title: data['title']?.toString() ?? '',
 description: data['description']?.toString() ?? '',
 owner: data['owner']?.toString() ?? '',
 status: data['status']?.toString() ?? 'Draft',
 location: data['location']?.toString() ?? '',
 uploadedFileName: data['uploadedFileName']?.toString(),
 uploadedFileUrl: data['uploadedFileUrl']?.toString(),
 uploadedStoragePath: data['uploadedStoragePath']?.toString(),
 );
 }).toList();
 }
}

class _DbEntity {
 const _DbEntity({
 required this.id,
 required this.name,
 required this.primaryKey,
 required this.owner,
 required this.description,
 });

 final String id;
 final String name;
 final String primaryKey;
 final String owner;
 final String description;

 _DbEntity copyWith({
 String? name,
 String? primaryKey,
 String? owner,
 String? description,
 }) {
 return _DbEntity(
 id: id,
 name: name ?? this.name,
 primaryKey: primaryKey ?? this.primaryKey,
 owner: owner ?? this.owner,
 description: description ?? this.description,
 );
 }

 Map<String, dynamic> toJson() {
 return {
 'id': id,
 'name': name,
 'primaryKey': primaryKey,
 'owner': owner,
 'description': description,
 };
 }

 static List<_DbEntity> fromList(dynamic raw) {
 if (raw is! List) return [];
 return raw.whereType<Map>().map((item) {
 final data = Map<String, dynamic>.from(item);
 return _DbEntity(
 id: data['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 name: data['name']?.toString() ?? '',
 primaryKey: data['primaryKey']?.toString() ?? '',
 owner: data['owner']?.toString() ?? '',
 description: data['description']?.toString() ?? '',
 );
 }).toList();
 }
}

class _DbField {
 const _DbField({
 required this.id,
 required this.table,
 required this.field,
 required this.type,
 required this.constraints,
 required this.notes,
 });

 final String id;
 final String table;
 final String field;
 final String type;
 final String constraints;
 final String notes;

 _DbField copyWith({
 String? table,
 String? field,
 String? type,
 String? constraints,
 String? notes,
 }) {
 return _DbField(
 id: id,
 table: table ?? this.table,
 field: field ?? this.field,
 type: type ?? this.type,
 constraints: constraints ?? this.constraints,
 notes: notes ?? this.notes,
 );
 }

 Map<String, dynamic> toJson() {
 return {
 'id': id,
 'table': table,
 'field': field,
 'type': type,
 'constraints': constraints,
 'notes': notes,
 };
 }

 static List<_DbField> fromList(dynamic raw) {
 if (raw is! List) return [];
 return raw.whereType<Map>().map((item) {
 final data = Map<String, dynamic>.from(item);
 return _DbField(
 id: data['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 table: data['table']?.toString() ?? '',
 field: data['field']?.toString() ?? '',
 type: data['type']?.toString() ?? '',
 constraints: data['constraints']?.toString() ?? '',
 notes: data['notes']?.toString() ?? '',
 );
 }).toList();
 }
}

class _Debouncer {
 _Debouncer({Duration? delay})
 : delay = delay ?? const Duration(milliseconds: 600);

 final Duration delay;
 Timer? _timer;

 void run(void Function() action) {
 _timer?.cancel();
 _timer = Timer(delay, action);
 }

 void dispose() {
 _timer?.cancel();
 }
}
