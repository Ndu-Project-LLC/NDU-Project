import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/activity_log_service.dart';
import 'package:ndu_project/services/project_navigation_service.dart';
import 'package:ndu_project/utils/design_planning_document.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/csv_table_import_button.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
// ─── Data Models ─────────────────────────────────────────────────────────────

class _StructuralItem {
 final String id;
 final String layer;
 final String description;
 final String specification;
 final String status;
 final String owner;

 const _StructuralItem({
 required this.id,
 required this.layer,
 required this.description,
 required this.specification,
 required this.status,
 required this.owner,
 });

 _StructuralItem copyWith({
 String? id,
 String? layer,
 String? description,
 String? specification,
 String? status,
 String? owner,
 }) {
 return _StructuralItem(
 id: id ?? this.id,
 layer: layer ?? this.layer,
 description: description ?? this.description,
 specification: specification ?? this.specification,
 status: status ?? this.status,
 owner: owner ?? this.owner,
 );
 }

 Map<String, dynamic> toMap() => {
 'id': id,
 'layer': layer,
 'description': description,
 'specification': specification,
 'status': status,
 'owner': owner,
 };

 static List<_StructuralItem> fromList(dynamic data) {
 if (data is! List) return [];
 return data
 .map((e) {
 if (e is! Map<String, dynamic>) return null;
 return _StructuralItem(
 id: e['id']?.toString() ?? '',
 layer: e['layer']?.toString() ?? '',
 description: e['description']?.toString() ?? '',
 specification: e['specification']?.toString() ?? '',
 status: e['status']?.toString() ?? '',
 owner: e['owner']?.toString() ?? '',
 );
 })
 .whereType<_StructuralItem>()
 .toList();
 }
}

class _ComponentItem {
 final String id;
 final String component;
 final String responsibility;
 final String interfaceType;
 final String status;
 final String owner;

 const _ComponentItem({
 required this.id,
 required this.component,
 required this.responsibility,
 required this.interfaceType,
 required this.status,
 required this.owner,
 });

 _ComponentItem copyWith({
 String? id,
 String? component,
 String? responsibility,
 String? interfaceType,
 String? status,
 String? owner,
 }) {
 return _ComponentItem(
 id: id ?? this.id,
 component: component ?? this.component,
 responsibility: responsibility ?? this.responsibility,
 interfaceType: interfaceType ?? this.interfaceType,
 status: status ?? this.status,
 owner: owner ?? this.owner,
 );
 }

 Map<String, dynamic> toMap() => {
 'id': id,
 'component': component,
 'responsibility': responsibility,
 'interfaceType': interfaceType,
 'status': status,
 'owner': owner,
 };

 static List<_ComponentItem> fromList(dynamic data) {
 if (data is! List) return [];
 return data
 .map((e) {
 if (e is! Map<String, dynamic>) return null;
 return _ComponentItem(
 id: e['id']?.toString() ?? '',
 component: e['component']?.toString() ?? '',
 responsibility: e['responsibility']?.toString() ?? '',
 interfaceType: e['interfaceType']?.toString() ?? '',
 status: e['status']?.toString() ?? '',
 owner: e['owner']?.toString() ?? '',
 );
 })
 .whereType<_ComponentItem>()
 .toList();
 }
}

class _CalculationItem {
 final String id;
 final String calculation;
 final String type;
 final String standard;
 final String status;
 final String peStamp;
 final String reviewer;

 const _CalculationItem({
 required this.id,
 required this.calculation,
 required this.type,
 required this.standard,
 required this.status,
 required this.peStamp,
 required this.reviewer,
 });

 _CalculationItem copyWith({
 String? id,
 String? calculation,
 String? type,
 String? standard,
 String? status,
 String? peStamp,
 String? reviewer,
 }) {
 return _CalculationItem(
 id: id ?? this.id,
 calculation: calculation ?? this.calculation,
 type: type ?? this.type,
 standard: standard ?? this.standard,
 status: status ?? this.status,
 peStamp: peStamp ?? this.peStamp,
 reviewer: reviewer ?? this.reviewer,
 );
 }

 Map<String, dynamic> toMap() => {
 'id': id,
 'calculation': calculation,
 'type': type,
 'standard': standard,
 'status': status,
 'peStamp': peStamp,
 'reviewer': reviewer,
 };

 static List<_CalculationItem> fromList(dynamic data) {
 if (data is! List) return [];
 return data
 .map((e) {
 if (e is! Map<String, dynamic>) return null;
 return _CalculationItem(
 id: e['id']?.toString() ?? '',
 calculation: e['calculation']?.toString() ?? '',
 type: e['type']?.toString() ?? '',
 standard: e['standard']?.toString() ?? '',
 status: e['status']?.toString() ?? '',
 peStamp: e['peStamp']?.toString() ?? '',
 reviewer: e['reviewer']?.toString() ?? '',
 );
 })
 .whereType<_CalculationItem>()
 .toList();
 }
}

class _ComplianceItem {
 final String id;
 final String standard;
 final String scope;
 final String applicability;
 final String complianceStatus;
 final String evidence;
 final String owner;

 const _ComplianceItem({
 required this.id,
 required this.standard,
 required this.scope,
 required this.applicability,
 required this.complianceStatus,
 required this.evidence,
 required this.owner,
 });

 _ComplianceItem copyWith({
 String? id,
 String? standard,
 String? scope,
 String? applicability,
 String? complianceStatus,
 String? evidence,
 String? owner,
 }) {
 return _ComplianceItem(
 id: id ?? this.id,
 standard: standard ?? this.standard,
 scope: scope ?? this.scope,
 applicability: applicability ?? this.applicability,
 complianceStatus: complianceStatus ?? this.complianceStatus,
 evidence: evidence ?? this.evidence,
 owner: owner ?? this.owner,
 );
 }

 Map<String, dynamic> toMap() => {
 'id': id,
 'standard': standard,
 'scope': scope,
 'applicability': applicability,
 'complianceStatus': complianceStatus,
 'evidence': evidence,
 'owner': owner,
 };

 static List<_ComplianceItem> fromList(dynamic data) {
 if (data is! List) return [];
 return data
 .map((e) {
 if (e is! Map<String, dynamic>) return null;
 return _ComplianceItem(
 id: e['id']?.toString() ?? '',
 standard: e['standard']?.toString() ?? '',
 scope: e['scope']?.toString() ?? '',
 applicability: e['applicability']?.toString() ?? '',
 complianceStatus: e['complianceStatus']?.toString() ?? '',
 evidence: e['evidence']?.toString() ?? '',
 owner: e['owner']?.toString() ?? '',
 );
 })
 .whereType<_ComplianceItem>()
 .toList();
 }
}

class _EcnItem {
 final String id;
 final String ecnId;
 final String title;
 final String priority;
 final String status;
 final String originator;
 final String approver;
 final String date;

 const _EcnItem({
 required this.id,
 required this.ecnId,
 required this.title,
 required this.priority,
 required this.status,
 required this.originator,
 required this.approver,
 required this.date,
 });

 _EcnItem copyWith({
 String? id,
 String? ecnId,
 String? title,
 String? priority,
 String? status,
 String? originator,
 String? approver,
 String? date,
 }) {
 return _EcnItem(
 id: id ?? this.id,
 ecnId: ecnId ?? this.ecnId,
 title: title ?? this.title,
 priority: priority ?? this.priority,
 status: status ?? this.status,
 originator: originator ?? this.originator,
 approver: approver ?? this.approver,
 date: date ?? this.date,
 );
 }

 Map<String, dynamic> toMap() => {
 'id': id,
 'ecnId': ecnId,
 'title': title,
 'priority': priority,
 'status': status,
 'originator': originator,
 'approver': approver,
 'date': date,
 };

 static List<_EcnItem> fromList(dynamic data) {
 if (data is! List) return [];
 return data
 .map((e) {
 if (e is! Map<String, dynamic>) return null;
 return _EcnItem(
 id: e['id']?.toString() ?? '',
 ecnId: e['ecnId']?.toString() ?? '',
 title: e['title']?.toString() ?? '',
 priority: e['priority']?.toString() ?? '',
 status: e['status']?.toString() ?? '',
 originator: e['originator']?.toString() ?? '',
 approver: e['approver']?.toString() ?? '',
 date: e['date']?.toString() ?? '',
 );
 })
 .whereType<_EcnItem>()
 .toList();
 }
}

class _ReadinessGate {
 final String id;
 final String gate;
 final String owner;
 final String status;

 const _ReadinessGate({
 required this.id,
 required this.gate,
 required this.owner,
 required this.status,
 });

 _ReadinessGate copyWith({
 String? id,
 String? gate,
 String? owner,
 String? status,
 }) {
 return _ReadinessGate(
 id: id ?? this.id,
 gate: gate ?? this.gate,
 owner: owner ?? this.owner,
 status: status ?? this.status,
 );
 }

 Map<String, dynamic> toMap() => {
 'id': id,
 'gate': gate,
 'owner': owner,
 'status': status,
 };

 static List<_ReadinessGate> fromList(dynamic data) {
 if (data is! List) return [];
 return data
 .map((e) {
 if (e is! Map<String, dynamic>) return null;
 return _ReadinessGate(
 id: e['id']?.toString() ?? '',
 gate: e['gate']?.toString() ?? '',
 owner: e['owner']?.toString() ?? '',
 status: e['status']?.toString() ?? '',
 );
 })
 .whereType<_ReadinessGate>()
 .toList();
 }
}


// ─── Debouncer ───────────────────────────────────────────────────────────────

class _Debouncer {
 Timer? _timer;
 void run(VoidCallback action) {
 _timer?.cancel();
 _timer = Timer(const Duration(milliseconds: 600), action);
 }

 void dispose() {
 _timer?.cancel();
 }
}

// ─── Panel Shell ─────────────────────────────────────────────────────────────

class _PanelShell extends StatelessWidget {
 final String title;
 final String subtitle;
 final Widget? trailing;
 final Widget child;

 const _PanelShell({
 required this.title,
 required this.subtitle,
 this.trailing,
 required this.child,
 });

 @override
 Widget build(BuildContext context) {
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
 trailing!,
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
}

// ─── Main Screen ─────────────────────────────────────────────────────────────

class EngineeringDesignScreen extends StatefulWidget {
 const EngineeringDesignScreen({super.key});

 @override
 State<EngineeringDesignScreen> createState() =>
 _EngineeringDesignScreenState();
}

class _EngineeringDesignScreenState extends State<EngineeringDesignScreen> {
 final TextEditingController _notesController = TextEditingController();
 final TextEditingController _keyDecisionsController = TextEditingController();
 final _Debouncer _saveDebouncer = _Debouncer();

 bool _isLoading = false;
 bool _suspendSave = false;
 bool _didSeedDefaults = false;
 bool _frameworkGuideExpanded = false;

 // Register data lists
 List<_StructuralItem> _structuralItems = [];
 List<_ComponentItem> _componentItems = [];
 List<_CalculationItem> _calculationItems = [];
 List<_ComplianceItem> _complianceItems = [];
 List<_EcnItem> _ecnItems = [];
 List<_ReadinessGate> _readinessGates = [];

 static const List<String> _structuralStatusOptions = [
 'Defined',
 'In Review',
 'Draft',
 'Planned',
 ];

 static const List<String> _componentStatusOptions = [
 'Defined',
 'In Review',
 'Draft',
 'Planned',
 ];

 static const List<String> _calculationStatusOptions = [
 'Complete',
 'In Review',
 'Draft',
 'Planned',
 ];

 static const List<String> _complianceStatusOptions = [
 'Compliant',
 'Partial',
 'In Review',
 'Not Started',
 ];

 static const List<String> _ecnStatusOptions = [
 'Approved',
 'Under Review',
 'Pending',
 'Draft',
 ];

 static const List<String> _ecnPriorityOptions = [
 'High',
 'Medium',
 'Low',
 ];

 static const List<String> _readinessStatusOptions = [
 'Complete',
 'In Progress',
 'Pending',
 'Not Started',
 ];

 static const List<String> _peStampOptions = ['Yes', 'No', 'N/A'];

 String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

 @override
 void initState() {
 super.initState();
 _structuralItems = _defaultStructuralItems();
 _componentItems = _defaultComponentItems();
 _calculationItems = _defaultCalculationItems();
 _complianceItems = _defaultComplianceItems();
 _ecnItems = _defaultEcnItems();
 _readinessGates = _defaultReadinessGates();

 WidgetsBinding.instance.addPostFrameCallback((_) async {
 final provider = ProjectDataInherited.maybeOf(context);
 final projectId = provider?.projectData.projectId;
 if (projectId != null && projectId.isNotEmpty) {
 await ProjectNavigationService.instance.saveLastPage(
 projectId,
 'engineering',
 );
 }
 await _loadFromFirestore();
 });
 _notesController.addListener(_scheduleSave);
 _keyDecisionsController.addListener(_scheduleSave);
 }

 
 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Engineering Design',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['engineering_design_screen'] ?? 'No data recorded.'),
 ],
 );
 }
@override
 void dispose() {
 _notesController.dispose();
 _keyDecisionsController.dispose();
 _saveDebouncer.dispose();
 super.dispose();
 }

 // ─── Firestore ─────────────────────────────────────────────────────────────

 DocumentReference<Map<String, dynamic>> _docFor(String projectId) {
 return FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('design_phase_sections')
 .doc('engineering_design');
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
 shouldSeedDefaults = data.isEmpty && !_didSeedDefaults;
 _suspendSave = true;
 if (!mounted) return;
 setState(() {
 if (shouldSeedDefaults) {
 _didSeedDefaults = true;
 final planningDoc = DesignPlanningDocument.fromProjectData(
 provider?.projectData ?? ProjectDataModel(),
 );
 _notesController.text = [
 planningDoc.architectureSummary.trim(),
 planningDoc.buildTechnicalDigest().trim(),
 ].where((v) => v.isNotEmpty).join('\n\n');
 _keyDecisionsController.text = planningDoc.decisions
 .map((item) => item.decision.trim())
 .where((v) => v.isNotEmpty)
 .join('\n');
 } else {
 _notesController.text = data['notes']?.toString() ?? '';
 _keyDecisionsController.text =
 data['keyDecisions']?.toString() ?? '';
 final structural = _StructuralItem.fromList(data['structuralItems']);
 final components = _ComponentItem.fromList(data['componentItems']);
 final calculations =
 _CalculationItem.fromList(data['calculationItems']);
 final compliance = _ComplianceItem.fromList(data['complianceItems']);
 final ecns = _EcnItem.fromList(data['ecnItems']);
 final gates = _ReadinessGate.fromList(data['readinessGates']);
 _structuralItems =
 structural.isEmpty ? _defaultStructuralItems() : structural;
 _componentItems =
 components.isEmpty ? _defaultComponentItems() : components;
 _calculationItems =
 calculations.isEmpty ? _defaultCalculationItems() : calculations;
 _complianceItems =
 compliance.isEmpty ? _defaultComplianceItems() : compliance;
 _ecnItems = ecns.isEmpty ? _defaultEcnItems() : ecns;
 _readinessGates =
 gates.isEmpty ? _defaultReadinessGates() : gates;
 }
 });
 } catch (error) {
 debugPrint('Engineering design load error: $error');
 } finally {
 _suspendSave = false;
 if (mounted) setState(() => _isLoading = false);
 if (shouldSeedDefaults) _scheduleSave();
 }
 }

 Future<void> _saveToFirestore() async {
 final provider = ProjectDataInherited.maybeOf(context);
 final projectId = provider?.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;
 try {
 await _docFor(projectId).set({
 'notes': _notesController.text.trim(),
 'keyDecisions': _keyDecisionsController.text.trim(),
 'structuralItems': _structuralItems.map((e) => e.toMap()).toList(),
 'componentItems': _componentItems.map((e) => e.toMap()).toList(),
 'calculationItems': _calculationItems.map((e) => e.toMap()).toList(),
 'complianceItems': _complianceItems.map((e) => e.toMap()).toList(),
 'ecnItems': _ecnItems.map((e) => e.toMap()).toList(),
 'readinessGates': _readinessGates.map((e) => e.toMap()).toList(),
 'updatedAt': FieldValue.serverTimestamp(),
 }, SetOptions(merge: true));
 await ActivityLogService.instance.logActivity(
 projectId: projectId,
 phase: 'Design Phase',
 page: 'Engineering',
 action: 'Updated Engineering data',
 );
 } catch (error) {
 debugPrint('Engineering design save error: $error');
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Unable to save Engineering changes right now. Please try again.',
 ),
 ),
 );
 }
 }

 void _logActivity(String action, {Map<String, dynamic>? details}) {
 final projectId = ProjectDataInherited.maybeOf(context)
 ?.projectData
 .projectId
 ?.trim() ??
 '';
 if (projectId.isEmpty) return;
 unawaited(
 ActivityLogService.instance.logActivity(
 projectId: projectId,
 phase: 'Design Phase',
 page: 'Engineering',
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

 // ─── Default Data ──────────────────────────────────────────────────────────

 List<_StructuralItem> _defaultStructuralItems() => [
 _StructuralItem(
 id: _newId(),
 layer: 'Structural Modeling',
 description:
 'UML diagrams, steel framing, coordination drawings',
 specification: 'IFC 4.0 / ISO 16739',
 status: 'Defined',
 owner: 'Structural Engineer'),
 _StructuralItem(
 id: _newId(),
 layer: 'Integration Layer',
 description:
 'APIs, physical joints, HVAC interfaces, vendor handoffs',
 specification: 'OpenAPI 3.1 / ASHRAE',
 status: 'In Review',
 owner: 'Integration Lead'),
 _StructuralItem(
 id: _newId(),
 layer: 'Verification Layer',
 description:
 'Load checks, latency budgets, code compliance, approvals',
 specification: 'ISO 9001 / ACI 318',
 status: 'Draft',
 owner: 'QA Lead'),
 _StructuralItem(
 id: _newId(),
 layer: 'Data Architecture',
 description:
 'Entity models, data flows, storage specifications',
 specification: 'DAMA-DMBOK',
 status: 'Planned',
 owner: 'Data Architect'),
 _StructuralItem(
 id: _newId(),
 layer: 'Security Architecture',
 description:
 'Threat model, encryption, access control design',
 specification: 'NIST 800-53',
 status: 'Planned',
 owner: 'Security Architect'),
 ];

 List<_ComponentItem> _defaultComponentItems() => [
 _ComponentItem(
 id: _newId(),
 component: 'Ticketing API',
 responsibility:
 'REST contract for ticket validation and gate access rules',
 interfaceType: 'REST API',
 status: 'Defined',
 owner: 'Software Lead'),
 _ComponentItem(
 id: _newId(),
 component: 'Primary Roof Truss Joint',
 responsibility:
 'Physical joint specification and load transfer detail',
 interfaceType: 'Mechanical',
 status: 'In Review',
 owner: 'Structural Engineer'),
 _ComponentItem(
 id: _newId(),
 component: 'HVAC Control Interface',
 responsibility:
 'Environmental control signals and occupancy response logic',
 interfaceType: 'BACnet/IP',
 status: 'Draft',
 owner: 'MEP Engineer'),
 _ComponentItem(
 id: _newId(),
 component: 'Steel Grade Reference Pack',
 responsibility:
 'Datasheet and compliance mapping for fabricated members',
 interfaceType: 'Document',
 status: 'Planned',
 owner: 'Materials Engineer'),
 _ComponentItem(
 id: _newId(),
 component: 'Electrical Distribution Panel',
 responsibility:
 'Power distribution schematic and breaker coordination',
 interfaceType: 'IEC 61850',
 status: 'Draft',
 owner: 'Electrical Engineer'),
 _ComponentItem(
 id: _newId(),
 component: 'Fire Suppression Interface',
 responsibility:
 'Smoke detection trigger and suppression activation logic',
 interfaceType: 'NFPA 72',
 status: 'Planned',
 owner: 'Fire Engineer'),
 ];

 List<_CalculationItem> _defaultCalculationItems() => [
 _CalculationItem(
 id: _newId(),
 calculation: 'Steel Frame Load Analysis',
 type: 'Structural',
 standard: 'AISC 360-16',
 status: 'Complete',
 peStamp: 'Yes',
 reviewer: 'Senior Structural'),
 _CalculationItem(
 id: _newId(),
 calculation: 'Foundation Bearing Capacity',
 type: 'Geotechnical',
 standard: 'ACI 336',
 status: 'In Review',
 peStamp: 'No',
 reviewer: 'Geotechnical Lead'),
 _CalculationItem(
 id: _newId(),
 calculation: 'Wind Load Assessment',
 type: 'Environmental',
 standard: 'ASCE 7-22',
 status: 'Complete',
 peStamp: 'Yes',
 reviewer: 'Structural Engineer'),
 _CalculationItem(
 id: _newId(),
 calculation: 'Seismic Design Category',
 type: 'Structural',
 standard: 'IBC 2021',
 status: 'Draft',
 peStamp: 'No',
 reviewer: 'Structural Engineer'),
 _CalculationItem(
 id: _newId(),
 calculation: 'Latency Budget Analysis',
 type: 'Performance',
 standard: 'RFC 768',
 status: 'Planned',
 peStamp: 'N/A',
 reviewer: 'Software Lead'),
 _CalculationItem(
 id: _newId(),
 calculation: 'Thermal Load Calculation',
 type: 'MEP',
 standard: 'ASHRAE 90.1',
 status: 'In Review',
 peStamp: 'No',
 reviewer: 'MEP Engineer'),
 ];

 List<_ComplianceItem> _defaultComplianceItems() => [
 _ComplianceItem(
 id: _newId(),
 standard: 'ISO 9001:2015',
 scope: 'Quality Management System',
 applicability: 'All deliverables',
 complianceStatus: 'Partial',
 evidence: 'QMS Manual',
 owner: 'Quality Manager'),
 _ComplianceItem(
 id: _newId(),
 standard: 'ACI 318-19',
 scope: 'Concrete Building Code',
 applicability: 'Structural elements',
 complianceStatus: 'Compliant',
 evidence: 'Mix designs, rebar schedules',
 owner: 'Structural Engineer'),
 _ComplianceItem(
 id: _newId(),
 standard: 'ASCE 7-22',
 scope: 'Minimum Design Loads',
 applicability: 'All structural loads',
 complianceStatus: 'Compliant',
 evidence: 'Load calculations',
 owner: 'Structural Engineer'),
 _ComplianceItem(
 id: _newId(),
 standard: 'IBC 2021',
 scope: 'International Building Code',
 applicability: 'Building envelope',
 complianceStatus: 'In Review',
 evidence: 'Code analysis sheet',
 owner: 'Architect'),
 _ComplianceItem(
 id: _newId(),
 standard: 'NFPA 72',
 scope: 'Fire Alarm & Signaling',
 applicability: 'Fire safety systems',
 complianceStatus: 'Not Started',
 evidence: 'TBD',
 owner: 'Fire Engineer'),
 _ComplianceItem(
 id: _newId(),
 standard: 'IEEE 830',
 scope: 'Software Requirements',
 applicability: 'Software interfaces',
 complianceStatus: 'Partial',
 evidence: 'SRS documents',
 owner: 'Software Lead'),
 ];

 List<_EcnItem> _defaultEcnItems() => [
 _EcnItem(
 id: _newId(),
 ecnId: 'ECN-001',
 title: 'Roof Truss Modification for Load Increase',
 priority: 'High',
 status: 'Under Review',
 originator: 'Structural Engineer',
 approver: 'PE Lead',
 date: '2025-01-15'),
 _EcnItem(
 id: _newId(),
 ecnId: 'ECN-002',
 title: 'HVAC Ductwork Rerouting',
 priority: 'Medium',
 status: 'Approved',
 originator: 'MEP Engineer',
 approver: 'Design Manager',
 date: '2025-01-10'),
 _EcnItem(
 id: _newId(),
 ecnId: 'ECN-003',
 title: 'API Schema Update v2.1',
 priority: 'Medium',
 status: 'Pending',
 originator: 'Software Lead',
 approver: 'Technical Architect',
 date: '2025-01-18'),
 _EcnItem(
 id: _newId(),
 ecnId: 'ECN-004',
 title: 'Foundation Depth Adjustment',
 priority: 'High',
 status: 'Draft',
 originator: 'Geotechnical Lead',
 approver: 'PE Lead',
 date: '2025-01-20'),
 ];

 List<_ReadinessGate> _defaultReadinessGates() => [
 _ReadinessGate(
 id: _newId(),
 gate: 'Structural Sign-off Ready',
 owner: 'PE Lead',
 status: 'In Progress'),
 _ReadinessGate(
 id: _newId(),
 gate: 'Electrical Coordination Review',
 owner: 'Electrical Engineer',
 status: 'Pending'),
 _ReadinessGate(
 id: _newId(),
 gate: 'Software Interface Freeze',
 owner: 'Software Lead',
 status: 'Not Started'),
 _ReadinessGate(
 id: _newId(),
 gate: 'MEP Coordination Sign-off',
 owner: 'MEP Engineer',
 status: 'Pending'),
 _ReadinessGate(
 id: _newId(),
 gate: 'Code Compliance Verification',
 owner: 'Code Official',
 status: 'Not Started'),
 _ReadinessGate(
 id: _newId(),
 gate: 'Executive Design Authorization',
 owner: 'Executive Sponsor',
 status: 'Not Started'),
 ];

 // ─── Status Tag ────────────────────────────────────────────────────────────

 Widget _buildStatusTag(String status, Color color) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: color.withOpacity(0.12),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(
 status,
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: color,
 ),
 ),
 );
 }

 Color _statusColor(String status) {
 switch (status) {
 case 'Defined':
 case 'Complete':
 case 'Compliant':
 case 'Approved':
 return const Color(0xFF10B981);
 case 'In Review':
 case 'In Progress':
 case 'Partial':
 return const Color(0xFFF59E0B);
 case 'Draft':
 case 'Pending':
 return const Color(0xFF6366F1);
 case 'Planned':
 case 'Not Started':
 return const Color(0xFF6B7280);
 case 'Under Review':
 return const Color(0xFF0EA5E9);
 default:
 return const Color(0xFF6B7280);
 }
 }

 Color _priorityColor(String priority) {
 switch (priority) {
 case 'High':
 return const Color(0xFFEF4444);
 case 'Medium':
 return const Color(0xFFF59E0B);
 case 'Low':
 return const Color(0xFF10B981);
 default:
 return const Color(0xFF6B7280);
 }
 }

 // ─── CRUD Operations: Structural ──────────────────────────────────────────

 void _removeStructuralItem(String id) {
 setState(() => _structuralItems.removeWhere((item) => item.id == id));
 _scheduleSave();
 _logActivity('Deleted structural row', details: {'itemId': id});
 }

 Future<void> _openStructuralItemDialog(
 {_StructuralItem? existing}) async {
 final layerController =
 TextEditingController(text: existing?.layer ?? '');
 final descController =
 TextEditingController(text: existing?.description ?? '');
 final specController =
 TextEditingController(text: existing?.specification ?? '');
 String status = existing?.status ?? _structuralStatusOptions.first;
 String owner = existing?.owner ?? 'Owner';

 final saved = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (context, setModalState) => AlertDialog(
 title: Text(existing == null
 ? 'Add architecture layer'
 : 'Edit architecture layer'),
 content: SizedBox(
 width: 520,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: layerController,
 decoration: const InputDecoration(
 labelText: 'Layer name',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: descController,
 minLines: 2,
 maxLines: 4,
 decoration: const InputDecoration(
 labelText: 'Description',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: specController,
 decoration: const InputDecoration(
 labelText: 'Specification',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: _structuralStatusOptions.contains(status)
 ? status
 : _structuralStatusOptions.first,
 items: _structuralStatusOptions
 .map((o) =>
 DropdownMenuItem(value: o, child: Text(o)))
 .toList(),
 onChanged: (v) {
 if (v == null) return;
 setModalState(() => status = v);
 },
 decoration: const InputDecoration(
 labelText: 'Status',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: TextEditingController(text: owner),
 decoration: const InputDecoration(
 labelText: 'Owner',
 border: OutlineInputBorder(),
 ),
 onChanged: (v) => owner = v,
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(dialogContext).pop(true),
 child: Text(existing == null ? 'Add layer' : 'Save changes'),
 ),
 ],
 ),
 ),
 );

 if (saved != true) return;
 final item = _StructuralItem(
 id: existing?.id ?? _newId(),
 layer: layerController.text.trim(),
 description: descController.text.trim(),
 specification: specController.text.trim(),
 status: status,
 owner: owner.trim(),
 );
 setState(() {
 if (existing == null) {
 _structuralItems.add(item);
 } else {
 final idx = _structuralItems
 .indexWhere((entry) => entry.id == existing.id);
 if (idx != -1) _structuralItems[idx] = item;
 }
 });
 _scheduleSave();
 _logActivity(
 existing == null ? 'Added structural row' : 'Edited structural row',
 details: {'itemId': item.id},
 );
 }

 // ─── CRUD Operations: Components ──────────────────────────────────────────

 void _removeComponentItem(String id) {
 setState(() => _componentItems.removeWhere((item) => item.id == id));
 _scheduleSave();
 _logActivity('Deleted component row', details: {'itemId': id});
 }

 Future<void> _openComponentItemDialog(
 {_ComponentItem? existing}) async {
 final nameController =
 TextEditingController(text: existing?.component ?? '');
 final respController =
 TextEditingController(text: existing?.responsibility ?? '');
 final ifaceController =
 TextEditingController(text: existing?.interfaceType ?? '');
 String status = existing?.status ?? _componentStatusOptions.first;
 String owner = existing?.owner ?? 'Owner';

 final saved = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (context, setModalState) => AlertDialog(
 title: Text(existing == null
 ? 'Add component'
 : 'Edit component'),
 content: SizedBox(
 width: 520,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: nameController,
 decoration: const InputDecoration(
 labelText: 'Component name',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: respController,
 minLines: 2,
 maxLines: 4,
 decoration: const InputDecoration(
 labelText: 'Responsibility',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: ifaceController,
 decoration: const InputDecoration(
 labelText: 'Interface type',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: _componentStatusOptions.contains(status)
 ? status
 : _componentStatusOptions.first,
 items: _componentStatusOptions
 .map((o) =>
 DropdownMenuItem(value: o, child: Text(o)))
 .toList(),
 onChanged: (v) {
 if (v == null) return;
 setModalState(() => status = v);
 },
 decoration: const InputDecoration(
 labelText: 'Status',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: TextEditingController(text: owner),
 decoration: const InputDecoration(
 labelText: 'Owner',
 border: OutlineInputBorder(),
 ),
 onChanged: (v) => owner = v,
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(dialogContext).pop(true),
 child:
 Text(existing == null ? 'Add component' : 'Save changes'),
 ),
 ],
 ),
 ),
 );

 if (saved != true) return;
 final item = _ComponentItem(
 id: existing?.id ?? _newId(),
 component: nameController.text.trim(),
 responsibility: respController.text.trim(),
 interfaceType: ifaceController.text.trim(),
 status: status,
 owner: owner.trim(),
 );
 setState(() {
 if (existing == null) {
 _componentItems.add(item);
 } else {
 final idx = _componentItems
 .indexWhere((entry) => entry.id == existing.id);
 if (idx != -1) _componentItems[idx] = item;
 }
 });
 _scheduleSave();
 _logActivity(
 existing == null ? 'Added component row' : 'Edited component row',
 details: {'itemId': item.id},
 );
 }

 // ─── CRUD Operations: Calculations ────────────────────────────────────────

 void _removeCalculationItem(String id) {
 setState(() => _calculationItems.removeWhere((item) => item.id == id));
 _scheduleSave();
 _logActivity('Deleted calculation row', details: {'itemId': id});
 }

 Future<void> _openCalculationItemDialog(
 {_CalculationItem? existing}) async {
 final calcController =
 TextEditingController(text: existing?.calculation ?? '');
 final typeController =
 TextEditingController(text: existing?.type ?? '');
 final stdController =
 TextEditingController(text: existing?.standard ?? '');
 String status = existing?.status ?? _calculationStatusOptions.first;
 String peStamp = existing?.peStamp ?? _peStampOptions.first;
 String reviewer = existing?.reviewer ?? 'Reviewer';

 final saved = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (context, setModalState) => AlertDialog(
 title: Text(existing == null
 ? 'Add calculation'
 : 'Edit calculation'),
 content: SizedBox(
 width: 520,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: calcController,
 decoration: const InputDecoration(
 labelText: 'Calculation name',
 border: OutlineInputBorder(),
 ),
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
 controller: stdController,
 decoration: const InputDecoration(
 labelText: 'Standard',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: _calculationStatusOptions.contains(status)
 ? status
 : _calculationStatusOptions.first,
 items: _calculationStatusOptions
 .map((o) =>
 DropdownMenuItem(value: o, child: Text(o)))
 .toList(),
 onChanged: (v) {
 if (v == null) return;
 setModalState(() => status = v);
 },
 decoration: const InputDecoration(
 labelText: 'Status',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: _peStampOptions.contains(peStamp)
 ? peStamp
 : _peStampOptions.first,
 items: _peStampOptions
 .map((o) =>
 DropdownMenuItem(value: o, child: Text(o)))
 .toList(),
 onChanged: (v) {
 if (v == null) return;
 setModalState(() => peStamp = v);
 },
 decoration: const InputDecoration(
 labelText: 'PE Stamp',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: TextEditingController(text: reviewer),
 decoration: const InputDecoration(
 labelText: 'Reviewer',
 border: OutlineInputBorder(),
 ),
 onChanged: (v) => reviewer = v,
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(dialogContext).pop(true),
 child: Text(
 existing == null ? 'Add calculation' : 'Save changes'),
 ),
 ],
 ),
 ),
 );

 if (saved != true) return;
 final item = _CalculationItem(
 id: existing?.id ?? _newId(),
 calculation: calcController.text.trim(),
 type: typeController.text.trim(),
 standard: stdController.text.trim(),
 status: status,
 peStamp: peStamp,
 reviewer: reviewer.trim(),
 );
 setState(() {
 if (existing == null) {
 _calculationItems.add(item);
 } else {
 final idx = _calculationItems
 .indexWhere((entry) => entry.id == existing.id);
 if (idx != -1) _calculationItems[idx] = item;
 }
 });
 _scheduleSave();
 _logActivity(
 existing == null ? 'Added calculation row' : 'Edited calculation row',
 details: {'itemId': item.id},
 );
 }

 // ─── CRUD Operations: Compliance ──────────────────────────────────────────

 void _removeComplianceItem(String id) {
 setState(() => _complianceItems.removeWhere((item) => item.id == id));
 _scheduleSave();
 _logActivity('Deleted compliance row', details: {'itemId': id});
 }

 Future<void> _openComplianceItemDialog(
 {_ComplianceItem? existing}) async {
 final stdController =
 TextEditingController(text: existing?.standard ?? '');
 final scopeController =
 TextEditingController(text: existing?.scope ?? '');
 final applController =
 TextEditingController(text: existing?.applicability ?? '');
 String complianceStatus =
 existing?.complianceStatus ?? _complianceStatusOptions.first;
 String evidence = existing?.evidence ?? '';
 String owner = existing?.owner ?? 'Owner';

 final saved = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (context, setModalState) => AlertDialog(
 title: Text(existing == null
 ? 'Add compliance standard'
 : 'Edit compliance standard'),
 content: SizedBox(
 width: 520,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: stdController,
 decoration: const InputDecoration(
 labelText: 'Standard',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: scopeController,
 decoration: const InputDecoration(
 labelText: 'Scope',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: applController,
 decoration: const InputDecoration(
 labelText: 'Applicability',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: _complianceStatusOptions.contains(complianceStatus)
 ? complianceStatus
 : _complianceStatusOptions.first,
 items: _complianceStatusOptions
 .map((o) =>
 DropdownMenuItem(value: o, child: Text(o)))
 .toList(),
 onChanged: (v) {
 if (v == null) return;
 setModalState(() => complianceStatus = v);
 },
 decoration: const InputDecoration(
 labelText: 'Compliance status',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: TextEditingController(text: evidence),
 decoration: const InputDecoration(
 labelText: 'Evidence',
 border: OutlineInputBorder(),
 ),
 onChanged: (v) => evidence = v,
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: TextEditingController(text: owner),
 decoration: const InputDecoration(
 labelText: 'Owner',
 border: OutlineInputBorder(),
 ),
 onChanged: (v) => owner = v,
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(dialogContext).pop(true),
 child: Text(existing == null
 ? 'Add standard'
 : 'Save changes'),
 ),
 ],
 ),
 ),
 );

 if (saved != true) return;
 final item = _ComplianceItem(
 id: existing?.id ?? _newId(),
 standard: stdController.text.trim(),
 scope: scopeController.text.trim(),
 applicability: applController.text.trim(),
 complianceStatus: complianceStatus,
 evidence: evidence.trim(),
 owner: owner.trim(),
 );
 setState(() {
 if (existing == null) {
 _complianceItems.add(item);
 } else {
 final idx = _complianceItems
 .indexWhere((entry) => entry.id == existing.id);
 if (idx != -1) _complianceItems[idx] = item;
 }
 });
 _scheduleSave();
 _logActivity(
 existing == null ? 'Added compliance row' : 'Edited compliance row',
 details: {'itemId': item.id},
 );
 }

 // ─── CRUD Operations: ECN ─────────────────────────────────────────────────

 void _removeEcnItem(String id) {
 setState(() => _ecnItems.removeWhere((item) => item.id == id));
 _scheduleSave();
 _logActivity('Deleted ECN row', details: {'itemId': id});
 }

 Future<void> _openEcnItemDialog({_EcnItem? existing}) async {
 final ecnIdController =
 TextEditingController(text: existing?.ecnId ?? '');
 final titleController =
 TextEditingController(text: existing?.title ?? '');
 String priority = existing?.priority ?? _ecnPriorityOptions.first;
 String status = existing?.status ?? _ecnStatusOptions.first;
 String originator = existing?.originator ?? 'Originator';
 String approver = existing?.approver ?? 'Approver';
 String date = existing?.date ?? '';

 final saved = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (context, setModalState) => AlertDialog(
 title: Text(
 existing == null ? 'Add ECN' : 'Edit ECN'),
 content: SizedBox(
 width: 520,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: ecnIdController,
 decoration: const InputDecoration(
 labelText: 'ECN ID',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: titleController,
 decoration: const InputDecoration(
 labelText: 'Title',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: _ecnPriorityOptions.contains(priority)
 ? priority
 : _ecnPriorityOptions.first,
 items: _ecnPriorityOptions
 .map((o) =>
 DropdownMenuItem(value: o, child: Text(o)))
 .toList(),
 onChanged: (v) {
 if (v == null) return;
 setModalState(() => priority = v);
 },
 decoration: const InputDecoration(
 labelText: 'Priority',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: _ecnStatusOptions.contains(status)
 ? status
 : _ecnStatusOptions.first,
 items: _ecnStatusOptions
 .map((o) =>
 DropdownMenuItem(value: o, child: Text(o)))
 .toList(),
 onChanged: (v) {
 if (v == null) return;
 setModalState(() => status = v);
 },
 decoration: const InputDecoration(
 labelText: 'Status',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: TextEditingController(text: originator),
 decoration: const InputDecoration(
 labelText: 'Originator',
 border: OutlineInputBorder(),
 ),
 onChanged: (v) => originator = v,
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: TextEditingController(text: approver),
 decoration: const InputDecoration(
 labelText: 'Approver',
 border: OutlineInputBorder(),
 ),
 onChanged: (v) => approver = v,
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: TextEditingController(text: date),
 decoration: const InputDecoration(
 labelText: 'Date',
 border: OutlineInputBorder(),
 hintText: 'YYYY-MM-DD',
 ),
 onChanged: (v) => date = v,
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(dialogContext).pop(true),
 child: Text(existing == null ? 'Add ECN' : 'Save changes'),
 ),
 ],
 ),
 ),
 );

 if (saved != true) return;
 final item = _EcnItem(
 id: existing?.id ?? _newId(),
 ecnId: ecnIdController.text.trim(),
 title: titleController.text.trim(),
 priority: priority,
 status: status,
 originator: originator.trim(),
 approver: approver.trim(),
 date: date.trim(),
 );
 setState(() {
 if (existing == null) {
 _ecnItems.add(item);
 } else {
 final idx =
 _ecnItems.indexWhere((entry) => entry.id == existing.id);
 if (idx != -1) _ecnItems[idx] = item;
 }
 });
 _scheduleSave();
 _logActivity(
 existing == null ? 'Added ECN row' : 'Edited ECN row',
 details: {'itemId': item.id},
 );
 }

 // ─── CRUD Operations: Readiness Gates ─────────────────────────────────────

 void _removeReadinessGate(String id) {
 setState(() => _readinessGates.removeWhere((item) => item.id == id));
 _scheduleSave();
 _logActivity('Deleted readiness gate', details: {'itemId': id});
 }

 Future<void> _openReadinessGateDialog({_ReadinessGate? existing}) async {
 final gateController =
 TextEditingController(text: existing?.gate ?? '');
 String owner = existing?.owner ?? 'Owner';
 String status = existing?.status ?? _readinessStatusOptions.first;

 final saved = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (context, setModalState) => AlertDialog(
 title: Text(existing == null
 ? 'Add approval gate'
 : 'Edit approval gate'),
 content: SizedBox(
 width: 480,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: gateController,
 decoration: const InputDecoration(
 labelText: 'Gate name',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: TextEditingController(text: owner),
 decoration: const InputDecoration(
 labelText: 'Owner',
 border: OutlineInputBorder(),
 ),
 onChanged: (v) => owner = v,
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: _readinessStatusOptions.contains(status)
 ? status
 : _readinessStatusOptions.first,
 items: _readinessStatusOptions
 .map((o) =>
 DropdownMenuItem(value: o, child: Text(o)))
 .toList(),
 onChanged: (v) {
 if (v == null) return;
 setModalState(() => status = v);
 },
 decoration: const InputDecoration(
 labelText: 'Status',
 border: OutlineInputBorder(),
 ),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(dialogContext).pop(true),
 child: Text(
 existing == null ? 'Add gate' : 'Save changes'),
 ),
 ],
 ),
 ),
 );

 if (saved != true) return;
 final item = _ReadinessGate(
 id: existing?.id ?? _newId(),
 gate: gateController.text.trim(),
 owner: owner.trim(),
 status: status,
 );
 setState(() {
 if (existing == null) {
 _readinessGates.add(item);
 } else {
 final idx = _readinessGates
 .indexWhere((entry) => entry.id == existing.id);
 if (idx != -1) _readinessGates[idx] = item;
 }
 });
 _scheduleSave();
 _logActivity(
 existing == null ? 'Added readiness gate' : 'Edited readiness gate',
 details: {'itemId': item.id},
 );
 }

 // ─── Build ─────────────────────────────────────────────────────────────────

 @override
 Widget build(BuildContext context) {
 final padding = AppBreakpoints.pagePadding(context);

 return ResponsiveScaffold(
 activeItemLabel: 'Engineering',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: Column(
 children: [
 PlanningPhaseHeader(
 title: 'Engineering',
showNavigationButtons: false, onExportPdf: _exportPdf),
 Expanded(
 child: SingleChildScrollView(
 padding: EdgeInsets.all(padding),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (_isLoading) const LinearProgressIndicator(minHeight: 2),
 if (_isLoading) const SizedBox(height: 16),
 _buildFrameworkGuide(),
 const SizedBox(height: 24),
 _buildStructuralRegister(),
 const SizedBox(height: 20),
 _buildComponentsRegister(),
 const SizedBox(height: 20),
 _buildCalculationsRegister(),
 const SizedBox(height: 20),
 _buildComplianceRegister(),
 const SizedBox(height: 20),
 _buildEcnRegister(),
 const SizedBox(height: 20),
 _buildReadinessGatesPanel(),
 const SizedBox(height: 20),
 _buildEngineeringBriefCard(),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Backend Design',
 nextLabel: 'Next: Technical Development',
 onBack: () => context.go('/backend-design'),
 onNext: () => context.go('/technical-development'),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }

 // ─── Framework Guide ───────────────────────────────────────────────────────

 Widget _buildFrameworkGuide() {
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
 // Clickable header row
 InkWell(
 onTap: () => setState(() => _frameworkGuideExpanded = !_frameworkGuideExpanded),
 borderRadius: BorderRadius.circular(16),
 child: Padding(
 padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
 child: Row(
 children: [
 const Expanded(
 child: Text(
 'Engineering standards & best practices',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827)),
 ),
 ),
 AnimatedRotation(
 duration: const Duration(milliseconds: 200),
 turns: _frameworkGuideExpanded ? 0.5 : 0,
 child: Icon(Icons.expand_more, size: 22, color: const Color(0xFF6B7280)),
 ),
 ],
 ),
 ),
 ),
 // Collapsible content
 AnimatedCrossFade(
 firstChild: const SizedBox(width: double.infinity, height: 0),
 secondChild: Padding(
 padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Grounded in ISO 9001 Quality Management, AISC 360 Structural Steel, '
 'ASCE 7 Minimum Design Loads, and PMI PMBOK Design processes. '
 'Effective engineering control ensures that structural integrity, '
 'interface compatibility, calculation accuracy, and code compliance '
 'remain visible and verifiable throughout the project lifecycle.',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 height: 1.5),
 ),
 const SizedBox(height: 18),
 _buildGuideCard(
 Icons.architecture_outlined,
 'Architecture & Layering',
 'Define system layers and their responsibilities before detailing '
 'interfaces. Each layer must have a clear specification standard '
 'and designated owner. Verify layer completeness before integration.',
 const Color(0xFF0EA5E9),
 ),
 const SizedBox(height: 12),
 _buildGuideCard(
 Icons.calculate_outlined,
 'Calculations & Analysis',
 'All structural, geotechnical, and performance calculations must '
 'reference a governing standard. PE-stamped calculations require '
 'independent reviewer sign-off before approval.',
 const Color(0xFF10B981),
 ),
 const SizedBox(height: 12),
 _buildGuideCard(
 Icons.verified_outlined,
 'Compliance & Evidence',
 'Map each applicable standard to project deliverables. Maintain '
 'audit-ready evidence artifacts. Track partial compliance '
 'with clear remediation actions and owners.',
 const Color(0xFFF59E0B),
 ),
 const SizedBox(height: 12),
 _buildGuideCard(
 Icons.sync_alt_outlined,
 'Change Control (ECN)',
 'Engineering changes must follow the ECN process: identify impact, '
 'assess priority, route to approver, and update affected '
 'calculations and compliance evidence before implementation.',
 const Color(0xFFEF4444),
 ),
 ],
 ),
 ),
 crossFadeState: _frameworkGuideExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
 duration: const Duration(milliseconds: 250),
 sizeCurve: Curves.easeInOut,
 ),
 ],
 ),
 );
 }

 Widget _buildGuideCard(
 IconData icon, String title, String description, Color color) {
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

 // ─── Table Column Header Style ─────────────────────────────────────────────

 Widget _tableColHeader(String text,
 {int flex = 1, double? width, TextAlign align = TextAlign.left}) {
 final child = Text(
 text,
 style: const TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8,
 ),
 textAlign: align,
 );
 if (width != null) {
 return SizedBox(width: width, child: child);
 }
 return Expanded(flex: flex, child: child);
 }

 // ─── Structural & Architecture Register ────────────────────────────────────

 Widget _buildStructuralRegister() {
 return _PanelShell(
 title: 'Structural & Architecture Register',
 subtitle:
 'System layers, specifications, and ownership for architecture control',
 trailing: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CsvTableImportButton(
 compact: true,
 tableTitle: 'Structural Architecture',
 columns: [
 CsvColumnSpec(key: 'layer', label: 'LAYER', required: true),
 CsvColumnSpec(key: 'description', label: 'DESCRIPTION', required: true),
 CsvColumnSpec(key: 'specification', label: 'SPECIFICATION'),
 CsvColumnSpec(key: 'status', label: 'STATUS', allowedValues: ['Planned', 'In Design', 'Designed', 'Reviewed', 'Approved'], defaultValue: 'Planned'),
 CsvColumnSpec(key: 'owner', label: 'OWNER'),
 ],
 onImport: (rows) {
 setState(() {
 for (final row in rows) {
 _structuralItems.add(_StructuralItem(
 id: _newId(),
 layer: row['layer'] ?? '',
 description: row['description'] ?? '',
 specification: row['specification'] ?? '',
 status: row['status'] ?? 'Planned',
 owner: row['owner'] ?? '',
 ));
 }
 });
 _scheduleSave();
 },
 ),
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: () => _openStructuralItemDialog(),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add layer',
 style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF475569),
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 padding:
 const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ],
 ),
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration:
 const BoxDecoration(color: Color(0xFFF8FAFC)),
 child: Row(
 children: [
 _tableColHeader('LAYER', flex: 3),
 _tableColHeader('DESCRIPTION', flex: 4),
 _tableColHeader('SPECIFICATION', flex: 3),
 _tableColHeader('STATUS', width: 130),
 _tableColHeader('OWNER', flex: 2),
 const SizedBox(width: 60, child: Text('')),
 ],
 ),
 ),
 if (_structuralItems.isEmpty)
 const Padding(
 padding: EdgeInsets.all(24),
 child: Text('No structural items. Add a layer to begin.',
 style: TextStyle(color: Color(0xFF6B7280))),
 )
 else
 ...List.generate(_structuralItems.length, (index) {
 final item = _structuralItems[index];
 final isLast = index == _structuralItems.length - 1;
 return Column(
 children: [
 Padding(
 padding: const EdgeInsets.symmetric(
 horizontal: 20, vertical: 12),
 child: Row(
 children: [
 Expanded(
 flex: 3,
 child: Text(item.layer,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827))),
 ),
 Expanded(
 flex: 4,
 child: Text(item.description,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF64748B),
 height: 1.4)),
 ),
 Expanded(
 flex: 3,
 child: Text(item.specification,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: Color(0xFF475569))),
 ),
 SizedBox(
 width: 130,
 child: _buildStatusTag(
 item.status, _statusColor(item.status)),
 ),
 Expanded(
 flex: 2,
 child: Text(item.owner,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF475569)),
 textAlign: TextAlign.center),
 ),
 SizedBox(
 width: 90,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 onPressed: () =>
 _openStructuralItemDialog(
 existing: item),
 icon: const Icon(Icons.edit_outlined,
 size: 16, color: Color(0xFF2563EB)),
 padding: EdgeInsets.zero,
 constraints:
 const BoxConstraints(minWidth: 28),
 ),
 IconButton(
 onPressed: () =>
 _removeStructuralItem(item.id),
 icon: const Icon(
 Icons.delete_outline,
 size: 16,
 color: Color(0xFFEF4444)),
 padding: EdgeInsets.zero,
 constraints:
 const BoxConstraints(minWidth: 28),
 ),
IconButton(
                                    onPressed: () => _kazAiForRow(),
                                    icon: const Icon(Icons.auto_awesome,
                                        size: 16, color: Color(0xFFF59E0B)),
                                    tooltip: 'KAZ AI',
                                    padding: EdgeInsets.zero,
                                    constraints:
                                        const BoxConstraints(minWidth: 28),
                                  ),
 ],
 ),
 ),
 ],
 ),
 ),
 if (!isLast)
 const Divider(
 height: 1,
 thickness: 1,
 color: Color(0xFFF1F5F9)),
 ],
 );
 }),
 ],
 ),
 );
 }

 // ─── Components & Interfaces Register ──────────────────────────────────────

 Widget _buildComponentsRegister() {
 return _PanelShell(
 title: 'Components & Interfaces Register',
 subtitle:
 'Interface specifications, responsibilities, and ownership for component control',
 trailing: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CsvTableImportButton(
 compact: true,
 tableTitle: 'Component Interface',
 columns: [
 CsvColumnSpec(key: 'component', label: 'COMPONENT', required: true),
 CsvColumnSpec(key: 'responsibility', label: 'RESPONSIBILITY', required: true),
 CsvColumnSpec(key: 'interfaceType', label: 'INTERFACE TYPE'),
 CsvColumnSpec(key: 'status', label: 'STATUS', allowedValues: ['Planned', 'In Design', 'Designed', 'Reviewed', 'Approved'], defaultValue: 'Planned'),
 CsvColumnSpec(key: 'owner', label: 'OWNER'),
 ],
 onImport: (rows) {
 setState(() {
 for (final row in rows) {
 _componentItems.add(_ComponentItem(
 id: _newId(),
 component: row['component'] ?? '',
 responsibility: row['responsibility'] ?? '',
 interfaceType: row['interfaceType'] ?? '',
 status: row['status'] ?? 'Planned',
 owner: row['owner'] ?? '',
 ));
 }
 });
 _scheduleSave();
 },
 ),
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: () => _openComponentItemDialog(),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add component',
 style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF475569),
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 padding:
 const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ],
 ),
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration:
 const BoxDecoration(color: Color(0xFFF8FAFC)),
 child: Row(
 children: [
 _tableColHeader('COMPONENT', flex: 3),
 _tableColHeader('RESPONSIBILITY', flex: 4),
 _tableColHeader('INTERFACE TYPE', flex: 2),
 _tableColHeader('STATUS', width: 130),
 _tableColHeader('OWNER', flex: 2),
 const SizedBox(width: 60, child: Text('')),
 ],
 ),
 ),
 if (_componentItems.isEmpty)
 const Padding(
 padding: EdgeInsets.all(24),
 child: Text(
 'No components defined. Add a component to begin.',
 style: TextStyle(color: Color(0xFF6B7280))),
 )
 else
 ...List.generate(_componentItems.length, (index) {
 final item = _componentItems[index];
 final isLast = index == _componentItems.length - 1;
 return Column(
 children: [
 Padding(
 padding: const EdgeInsets.symmetric(
 horizontal: 20, vertical: 12),
 child: Row(
 children: [
 Expanded(
 flex: 3,
 child: Text(item.component,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827))),
 ),
 Expanded(
 flex: 4,
 child: Text(item.responsibility,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF64748B),
 height: 1.4)),
 ),
 Expanded(
 flex: 2,
 child: Text(item.interfaceType,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: Color(0xFF475569))),
 ),
 SizedBox(
 width: 130,
 child: _buildStatusTag(
 item.status, _statusColor(item.status)),
 ),
 Expanded(
 flex: 2,
 child: Text(item.owner,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF475569)),
 textAlign: TextAlign.center),
 ),
 SizedBox(
 width: 90,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 onPressed: () =>
 _openComponentItemDialog(
 existing: item),
 icon: const Icon(Icons.edit_outlined,
 size: 16, color: Color(0xFF2563EB)),
 padding: EdgeInsets.zero,
 constraints:
 const BoxConstraints(minWidth: 28),
 ),
 IconButton(
 onPressed: () =>
 _removeComponentItem(item.id),
 icon: const Icon(
 Icons.delete_outline,
 size: 16,
 color: Color(0xFFEF4444)),
 padding: EdgeInsets.zero,
 constraints:
 const BoxConstraints(minWidth: 28),
 ),
IconButton(
                                    onPressed: () => _kazAiForRow(),
                                    icon: const Icon(Icons.auto_awesome,
                                        size: 16, color: Color(0xFFF59E0B)),
                                    tooltip: 'KAZ AI',
                                    padding: EdgeInsets.zero,
                                    constraints:
                                        const BoxConstraints(minWidth: 28),
                                  ),
 ],
 ),
 ),
 ],
 ),
 ),
 if (!isLast)
 const Divider(
 height: 1,
 thickness: 1,
 color: Color(0xFFF1F5F9)),
 ],
 );
 }),
 ],
 ),
 );
 }

 // ─── Calculations & Analysis Register ──────────────────────────────────────

 Widget _buildCalculationsRegister() {
 return _PanelShell(
 title: 'Calculations & Analysis Register',
 subtitle:
 'Structural, geotechnical, and performance calculations with PE stamp tracking',
 trailing: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CsvTableImportButton(
 compact: true,
 tableTitle: 'Calculations & Analysis',
 columns: [
 CsvColumnSpec(key: 'calculation', label: 'CALCULATION', required: true),
 CsvColumnSpec(key: 'type', label: 'TYPE'),
 CsvColumnSpec(key: 'standard', label: 'STANDARD'),
 CsvColumnSpec(key: 'status', label: 'STATUS', allowedValues: ['Planned', 'In Design', 'Designed', 'Reviewed', 'Approved'], defaultValue: 'Planned'),
 CsvColumnSpec(key: 'peStamp', label: 'PE STAMP', allowedValues: ['Yes', 'No', 'N/A'], defaultValue: 'No'),
 CsvColumnSpec(key: 'reviewer', label: 'REVIEWER'),
 ],
 onImport: (rows) {
 setState(() {
 for (final row in rows) {
 _calculationItems.add(_CalculationItem(
 id: _newId(),
 calculation: row['calculation'] ?? '',
 type: row['type'] ?? '',
 standard: row['standard'] ?? '',
 status: row['status'] ?? 'Planned',
 peStamp: row['peStamp'] ?? 'No',
 reviewer: row['reviewer'] ?? '',
 ));
 }
 });
 _scheduleSave();
 },
 ),
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: () => _openCalculationItemDialog(),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add calculation',
 style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF475569),
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 padding:
 const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ],
 ),
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration:
 const BoxDecoration(color: Color(0xFFF8FAFC)),
 child: Row(
 children: [
 _tableColHeader('CALCULATION', flex: 3),
 _tableColHeader('TYPE', width: 130),
 _tableColHeader('STANDARD', width: 130),
 _tableColHeader('STATUS', width: 130),
 _tableColHeader('PE STAMP', width: 110),
 _tableColHeader('REVIEWER', flex: 2),
 const SizedBox(width: 60, child: Text('')),
 ],
 ),
 ),
 if (_calculationItems.isEmpty)
 const Padding(
 padding: EdgeInsets.all(24),
 child: Text(
 'No calculations registered. Add a calculation to begin.',
 style: TextStyle(color: Color(0xFF6B7280))),
 )
 else
 ...List.generate(_calculationItems.length, (index) {
 final item = _calculationItems[index];
 final isLast = index == _calculationItems.length - 1;
 return Column(
 children: [
 Padding(
 padding: const EdgeInsets.symmetric(
 horizontal: 20, vertical: 12),
 child: Row(
 children: [
 Expanded(
 flex: 3,
 child: Text(item.calculation,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827))),
 ),
 SizedBox(
 width: 130,
 child: Text(item.type,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF475569))),
 ),
 SizedBox(
 width: 130,
 child: Text(item.standard,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: Color(0xFF475569))),
 ),
 SizedBox(
 width: 130,
 child: _buildStatusTag(
 item.status, _statusColor(item.status)),
 ),
 SizedBox(
 width: 110,
 child: _buildStatusTag(
 item.peStamp,
 item.peStamp == 'Yes'
 ? const Color(0xFF10B981)
 : item.peStamp == 'N/A'
 ? const Color(0xFF6B7280)
 : const Color(0xFFF59E0B)),
 ),
 Expanded(
 flex: 2,
 child: Text(item.reviewer,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF475569)),
 textAlign: TextAlign.center),
 ),
 SizedBox(
 width: 90,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 onPressed: () =>
 _openCalculationItemDialog(
 existing: item),
 icon: const Icon(Icons.edit_outlined,
 size: 16, color: Color(0xFF2563EB)),
 padding: EdgeInsets.zero,
 constraints:
 const BoxConstraints(minWidth: 28),
 ),
 IconButton(
 onPressed: () =>
 _removeCalculationItem(item.id),
 icon: const Icon(
 Icons.delete_outline,
 size: 16,
 color: Color(0xFFEF4444)),
 padding: EdgeInsets.zero,
 constraints:
 const BoxConstraints(minWidth: 28),
 ),
IconButton(
                                    onPressed: () => _kazAiForRow(),
                                    icon: const Icon(Icons.auto_awesome,
                                        size: 16, color: Color(0xFFF59E0B)),
                                    tooltip: 'KAZ AI',
                                    padding: EdgeInsets.zero,
                                    constraints:
                                        const BoxConstraints(minWidth: 28),
                                  ),
 ],
 ),
 ),
 ],
 ),
 ),
 if (!isLast)
 const Divider(
 height: 1,
 thickness: 1,
 color: Color(0xFFF1F5F9)),
 ],
 );
 }),
 ],
 ),
 );
 }

 // ─── Compliance & Standards Register ───────────────────────────────────────

 Widget _buildComplianceRegister() {
 return _PanelShell(
 title: 'Compliance & Standards Register',
 subtitle:
 'Applicable standards, compliance tracking, and evidence mapping',
 trailing: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CsvTableImportButton(
 compact: true,
 tableTitle: 'Compliance',
 columns: [
 CsvColumnSpec(key: 'standard', label: 'STANDARD', required: true),
 CsvColumnSpec(key: 'scope', label: 'SCOPE'),
 CsvColumnSpec(key: 'applicability', label: 'APPLICABILITY'),
 CsvColumnSpec(key: 'complianceStatus', label: 'STATUS', allowedValues: ['Compliant', 'Partial', 'In Review', 'Not Started'], defaultValue: 'Not Started'),
 CsvColumnSpec(key: 'evidence', label: 'EVIDENCE'),
 CsvColumnSpec(key: 'owner', label: 'OWNER'),
 ],
 onImport: (rows) {
 setState(() {
 for (final row in rows) {
 _complianceItems.add(_ComplianceItem(
 id: _newId(),
 standard: row['standard'] ?? '',
 scope: row['scope'] ?? '',
 applicability: row['applicability'] ?? '',
 complianceStatus: row['complianceStatus'] ?? 'Not Started',
 evidence: row['evidence'] ?? '',
 owner: row['owner'] ?? '',
 ));
 }
 });
 _scheduleSave();
 },
 ),
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: () => _openComplianceItemDialog(),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add standard',
 style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF475569),
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 padding:
 const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ],
 ),
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration:
 const BoxDecoration(color: Color(0xFFF8FAFC)),
 child: Row(
 children: [
 _tableColHeader('STANDARD', flex: 2),
 _tableColHeader('SCOPE', flex: 2),
 _tableColHeader('APPLICABILITY', flex: 2),
 _tableColHeader('COMPLIANCE', width: 130),
 _tableColHeader('EVIDENCE', flex: 2),
 _tableColHeader('OWNER', flex: 2),
 const SizedBox(width: 60, child: Text('')),
 ],
 ),
 ),
 if (_complianceItems.isEmpty)
 const Padding(
 padding: EdgeInsets.all(24),
 child: Text(
 'No compliance items. Add a standard to begin.',
 style: TextStyle(color: Color(0xFF6B7280))),
 )
 else
 ...List.generate(_complianceItems.length, (index) {
 final item = _complianceItems[index];
 final isLast = index == _complianceItems.length - 1;
 return Column(
 children: [
 Padding(
 padding: const EdgeInsets.symmetric(
 horizontal: 20, vertical: 12),
 child: Row(
 children: [
 Expanded(
 flex: 2,
 child: Text(item.standard,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827))),
 ),
 Expanded(
 flex: 2,
 child: Text(item.scope,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF64748B))),
 ),
 Expanded(
 flex: 2,
 child: Text(item.applicability,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF64748B))),
 ),
 SizedBox(
 width: 130,
 child: _buildStatusTag(
 item.complianceStatus,
 _statusColor(item.complianceStatus)),
 ),
 Expanded(
 flex: 2,
 child: Text(item.evidence,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF475569))),
 ),
 Expanded(
 flex: 2,
 child: Text(item.owner,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF475569)),
 textAlign: TextAlign.center),
 ),
 SizedBox(
 width: 90,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 onPressed: () =>
 _openComplianceItemDialog(
 existing: item),
 icon: const Icon(Icons.edit_outlined,
 size: 16, color: Color(0xFF2563EB)),
 padding: EdgeInsets.zero,
 constraints:
 const BoxConstraints(minWidth: 28),
 ),
 IconButton(
 onPressed: () =>
 _removeComplianceItem(item.id),
 icon: const Icon(
 Icons.delete_outline,
 size: 16,
 color: Color(0xFFEF4444)),
 padding: EdgeInsets.zero,
 constraints:
 const BoxConstraints(minWidth: 28),
 ),
IconButton(
                                    onPressed: () => _kazAiForRow(),
                                    icon: const Icon(Icons.auto_awesome,
                                        size: 16, color: Color(0xFFF59E0B)),
                                    tooltip: 'KAZ AI',
                                    padding: EdgeInsets.zero,
                                    constraints:
                                        const BoxConstraints(minWidth: 28),
                                  ),
 ],
 ),
 ),
 ],
 ),
 ),
 if (!isLast)
 const Divider(
 height: 1,
 thickness: 1,
 color: Color(0xFFF1F5F9)),
 ],
 );
 }),
 ],
 ),
 );
 }

 // ─── ECN Register ──────────────────────────────────────────────────────────

 Widget _buildEcnRegister() {
 return _PanelShell(
 title: 'Engineering Change Notices Register',
 subtitle:
 'Change control tracking aligned with design change management processes',
 trailing: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CsvTableImportButton(
 compact: true,
 tableTitle: 'ECN',
 columns: [
 CsvColumnSpec(key: 'ecnId', label: 'ECN ID', required: true),
 CsvColumnSpec(key: 'title', label: 'TITLE', required: true),
 CsvColumnSpec(key: 'priority', label: 'PRIORITY', allowedValues: ['High', 'Medium', 'Low'], defaultValue: 'Medium'),
 CsvColumnSpec(key: 'status', label: 'STATUS', allowedValues: ['Approved', 'Under Review', 'Pending', 'Draft'], defaultValue: 'Draft'),
 CsvColumnSpec(key: 'originator', label: 'ORIGINATOR'),
 CsvColumnSpec(key: 'approver', label: 'APPROVER'),
 CsvColumnSpec(key: 'date', label: 'DATE'),
 ],
 onImport: (rows) {
 setState(() {
 for (final row in rows) {
 _ecnItems.add(_EcnItem(
 id: _newId(),
 ecnId: row['ecnId'] ?? '',
 title: row['title'] ?? '',
 priority: row['priority'] ?? 'Medium',
 status: row['status'] ?? 'Draft',
 originator: row['originator'] ?? '',
 approver: row['approver'] ?? '',
 date: row['date'] ?? '',
 ));
 }
 });
 _scheduleSave();
 },
 ),
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: () => _openEcnItemDialog(),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add ECN',
 style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF475569),
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 padding:
 const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ],
 ),
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration:
 const BoxDecoration(color: Color(0xFFF8FAFC)),
 child: Row(
 children: [
 _tableColHeader('ECN ID', width: 110),
 _tableColHeader('TITLE', flex: 3),
 _tableColHeader('PRIORITY', width: 110),
 _tableColHeader('STATUS', width: 130),
 _tableColHeader('ORIGINATOR', flex: 2),
 _tableColHeader('APPROVER', flex: 2),
 _tableColHeader('DATE', width: 120),
 const SizedBox(width: 60, child: Text('')),
 ],
 ),
 ),
 if (_ecnItems.isEmpty)
 const Padding(
 padding: EdgeInsets.all(24),
 child: Text('No ECNs registered. Add an ECN to begin.',
 style: TextStyle(color: Color(0xFF6B7280))),
 )
 else
 ...List.generate(_ecnItems.length, (index) {
 final item = _ecnItems[index];
 final isLast = index == _ecnItems.length - 1;
 return Column(
 children: [
 Padding(
 padding: const EdgeInsets.symmetric(
 horizontal: 20, vertical: 12),
 child: Row(
 children: [
 SizedBox(
 width: 130,
 child: Text(item.ecnId,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 ),
 Expanded(
 flex: 3,
 child: Text(item.title,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: Color(0xFF1F2937))),
 ),
 SizedBox(
 width: 110,
 child: _buildStatusTag(
 item.priority, _priorityColor(item.priority)),
 ),
 SizedBox(
 width: 130,
 child: _buildStatusTag(
 item.status, _statusColor(item.status)),
 ),
 Expanded(
 flex: 2,
 child: Text(item.originator,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF475569)),
 textAlign: TextAlign.center),
 ),
 Expanded(
 flex: 2,
 child: Text(item.approver,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF475569)),
 textAlign: TextAlign.center),
 ),
 SizedBox(
 width: 120,
 child: Text(item.date,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF64748B))),
 ),
 SizedBox(
 width: 90,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 onPressed: () =>
 _openEcnItemDialog(existing: item),
 icon: const Icon(Icons.edit_outlined,
 size: 16, color: Color(0xFF2563EB)),
 padding: EdgeInsets.zero,
 constraints:
 const BoxConstraints(minWidth: 28),
 ),
 IconButton(
 onPressed: () =>
 _removeEcnItem(item.id),
 icon: const Icon(
 Icons.delete_outline,
 size: 16,
 color: Color(0xFFEF4444)),
 padding: EdgeInsets.zero,
 constraints:
 const BoxConstraints(minWidth: 28),
 ),
IconButton(
                                    onPressed: () => _kazAiForRow(),
                                    icon: const Icon(Icons.auto_awesome,
                                        size: 16, color: Color(0xFFF59E0B)),
                                    tooltip: 'KAZ AI',
                                    padding: EdgeInsets.zero,
                                    constraints:
                                        const BoxConstraints(minWidth: 28),
                                  ),
 ],
 ),
 ),
 ],
 ),
 ),
 if (!isLast)
 const Divider(
 height: 1,
 thickness: 1,
 color: Color(0xFFF1F5F9)),
 ],
 );
 }),
 ],
 ),
 );
 }

 // ─── Readiness & Approval Gates Panel ──────────────────────────────────────

 Widget _buildReadinessGatesPanel() {
 return _PanelShell(
 title: 'Engineering Readiness & Approval Gates',
 subtitle:
 'Approval gates aligned with design sign-off and authorization processes',
 trailing: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CsvTableImportButton(
 compact: true,
 tableTitle: 'Readiness Gates',
 columns: [
 CsvColumnSpec(key: 'gate', label: 'GATE', required: true),
 CsvColumnSpec(key: 'owner', label: 'OWNER'),
 CsvColumnSpec(key: 'status', label: 'STATUS', allowedValues: ['Not Started', 'In Progress', 'Pending', 'Complete'], defaultValue: 'Not Started'),
 ],
 onImport: (rows) {
 setState(() {
 for (final row in rows) {
 _readinessGates.add(_ReadinessGate(
 id: _newId(),
 gate: row['gate'] ?? '',
 owner: row['owner'] ?? '',
 status: row['status'] ?? 'Not Started',
 ));
 }
 });
 _scheduleSave();
 },
 ),
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: () => _openReadinessGateDialog(),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add gate',
 style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF475569),
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 padding:
 const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ],
 ),
 child: Padding(
 padding: const EdgeInsets.all(20),
 child: _readinessGates.isEmpty
 ? const Center(
 child: Padding(
 padding: EdgeInsets.all(24.0),
 child: Text('No approval gates defined.',
 style: TextStyle(color: Color(0xFF6B7280))),
 ),
 )
 : Wrap(
 spacing: 12,
 runSpacing: 12,
 children: _readinessGates.map((gate) {
 return Container(
 width: 280,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(
 color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Text(
 gate.gate,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ),
 IconButton(
 onPressed: () =>
 _openReadinessGateDialog(
 existing: gate),
 icon: const Icon(Icons.edit_outlined,
 size: 14,
 color: Color(0xFF2563EB)),
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(
 minWidth: 24, minHeight: 24),
 ),
 IconButton(
 onPressed: () =>
 _removeReadinessGate(gate.id),
 icon: const Icon(Icons.delete_outline,
 size: 14,
 color: Color(0xFFEF4444)),
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(
 minWidth: 24, minHeight: 24),
 ),
 ],
 ),
 const SizedBox(height: 8),
 Row(
 children: [
 Icon(Icons.person_outline,
 size: 14,
 color: Colors.grey[500]),
 const SizedBox(width: 4),
 Text(gate.owner,
 style: TextStyle(
 fontSize: 12,
 color: Colors.grey[600])),
 ],
 ),
 const SizedBox(height: 8),
 _buildStatusTag(
 gate.status, _statusColor(gate.status)),
 ],
 ),
 );
 }).toList(),
 ),
 ),
 );
 }

 // ─── Engineering Brief & Key Decisions ─────────────────────────────────────

 Widget _buildEngineeringBriefCard() {
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
 children: [
 Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: const Color(0xFF0EA5E9).withOpacity(0.12),
 borderRadius: BorderRadius.circular(8),
 ),
 child: const Icon(Icons.edit_note_outlined,
 size: 20, color: Color(0xFF0EA5E9)),
 ),
 const SizedBox(width: 12),
 const Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Engineering Brief & Key Decisions',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 SizedBox(height: 2),
 Text(
 'Working notes and technical decision log behind the structured registers',
 style: TextStyle(
 fontSize: 12, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 VoiceTextField(
 controller: _notesController,
 maxLines: 3,
 decoration: InputDecoration(
 hintText:
 'Capture engineering assumptions, code requirements, detailing notes, and unresolved technical questions.',
 filled: true,
 fillColor: const Color(0xFFF8FAFC),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12)),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide:
 const BorderSide(color: Color(0xFFE2E8F0)),
 ),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: _keyDecisionsController,
 maxLines: 3,
 decoration: InputDecoration(
 hintText:
 'Record key approvals, calculation assumptions, sign-off gates, and coordination decisions.',
 filled: true,
 fillColor: const Color(0xFFF8FAFC),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12)),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide:
 const BorderSide(color: Color(0xFFE2E8F0)),
 ),
 ),
 ),
 ],
 ),
 );
 }
}
