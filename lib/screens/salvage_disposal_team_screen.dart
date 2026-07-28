import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ndu_project/screens/deliver_project_closure_screen.dart';
import 'package:ndu_project/screens/identify_staff_ops_team_screen.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/salvage_service.dart';
import 'package:ndu_project/utils/execution_phase_ai_seed.dart';
import 'package:ndu_project/widgets/launch_editable_section.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_modal.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/widgets/csv_import_dialog.dart';
import 'package:ndu_project/theme.dart';
class SalvageDisposalTeamScreen extends StatefulWidget {
 const SalvageDisposalTeamScreen({super.key});

 static void open(BuildContext context) => Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const SalvageDisposalTeamScreen()),
 );

 @override
 State<SalvageDisposalTeamScreen> createState() =>
 _SalvageDisposalTeamScreenState();
}

class _SalvageDisposalTeamScreenState extends State<SalvageDisposalTeamScreen> {
 int _selectedTab = 0;
 final List<String> _tabs = [
 'Overview',
 'Asset Inventory',
 'Disposal Queue',
 'Team Allocation'
 ];

 String? _getProjectId() {
 try {
 final provider = ProjectDataInherited.maybeOf(context);
 return provider?.projectData.projectId;
 } catch (e) {
 return null;
 }
 }

 bool _autoGenerationTriggered = false;
 bool _isAutoGenerating = false;

 final List<_StatItem> _overviewStats = [];
 final List<_StatItem> _inventoryStats = [];
 final List<_StatItem> _queueStats = [];
 final List<_StatItem> _allocationStats = [];
 final List<_QueueBoardItem> _queueBoardItems = [];
 final List<_AllocationItem> _allocationItems = [];
 final List<_CapacityItem> _capacityItems = [];
 final List<_ComplianceRegulationRow> _complianceRows = [];
 bool _isLoadingCompliance = false;

 static const List<_StatItem> _defaultOverviewStats = [
 _StatItem('Team Members', '5 active', Icons.people, Colors.blue),
 _StatItem('Assets Pending', '12 items', Icons.inventory, Colors.orange),
 _StatItem(
 'Total Salvage Value', '\$73,350', Icons.attach_money, Colors.green),
 _StatItem('Disposal Progress', '68%', Icons.pie_chart, Color(0xFF8B5CF6)),
 _StatItem('Compliance Score', '94/100', Icons.verified, Colors.teal),
 ];

 static const List<_StatItem> _defaultInventoryStats = [
 _StatItem(
 'Tracked Assets', '86', Icons.inventory_2_outlined, Color(0xFF0284C7)),
 _StatItem('Ready for Disposal', '24', Icons.fact_check_outlined,
 Color(0xFF10B981)),
 _StatItem('Estimated Value', '\$128.4K', Icons.savings_outlined,
 Color(0xFF16A34A)),
 _StatItem('Reuse Potential', '41%', Icons.autorenew, Color(0xFF7C3AED)),
 ];

 static const List<_StatItem> _defaultQueueStats = [
 _StatItem('Queue Items', '18', Icons.list_alt_outlined, Color(0xFF0EA5E9)),
 _StatItem('High Priority', '6', Icons.priority_high, Color(0xFFEF4444)),
 _StatItem(
 'Auction Value', '\$52.7K', Icons.sell_outlined, Color(0xFFF59E0B)),
 _StatItem(
 'Compliance Ready', '82%', Icons.verified_outlined, Color(0xFF14B8A6)),
 ];

 static const List<_StatItem> _defaultAllocationStats = [
 _StatItem(
 'Active Specialists', '12', Icons.groups_outlined, Color(0xFF0EA5E9)),
 _StatItem(
 'Utilization', '74%', Icons.donut_large_outlined, Color(0xFF6366F1)),
 _StatItem(
 'Open Roles', '3', Icons.person_search_outlined, Color(0xFFFB7185)),
 _StatItem('Training Due', '2', Icons.school_outlined, Color(0xFFF59E0B)),
 ];

 static const List<_TeamMember> _defaultTeamMembers = [
 _TeamMember('Sarah Mitchell', 'Team Lead', 'sarah.m@company.com', 'Active',
 12, Colors.green),
 _TeamMember('James Rodriguez', 'Asset Specialist', 'james.r@company.com',
 'Active', 8, Colors.green),
 _TeamMember('Emily Chen', 'Logistics Coordinator', 'emily.c@company.com',
 'On Leave', 5, Colors.orange),
 _TeamMember('Michael Thompson', 'Disposal Technician',
 'michael.t@company.com', 'Active', 15, Colors.green),
 _TeamMember('Lisa Park', 'Compliance Officer', 'lisa.p@company.com',
 'Active', 9, Colors.green),
 ];

 static const List<_InventoryItem> _defaultInventoryItems = [
 _InventoryItem('SVG-019', 'Server Rack Set', 'Electronics', 'Excellent',
 'Data Center', 'Ready', '\$18,400', Colors.green),
 _InventoryItem('SVG-023', 'Operations Console', 'Hardware', 'Good',
 'Control Room', 'Pending', '\$6,750', Colors.orange),
 _InventoryItem('SVG-031', 'Hazmat Storage', 'Safety', 'Good', 'Warehouse B',
 'Review', '\$4,200', Colors.blue),
 _InventoryItem('SVG-044', 'Generator Unit', 'Power', 'Fair', 'Substation',
 'Flagged', '\$12,300', Colors.red),
 _InventoryItem('SVG-052', 'Network Switches', 'Electronics', 'Excellent',
 'Data Center', 'Ready', '\$7,980', Colors.green),
 ];

 static const List<_DisposalItem> _defaultDisposalItems = [
 _DisposalItem('SVG-001', 'Server Equipment', 'Electronics',
 'Pending Review', '\$12,500', 'High', Colors.red),
 _DisposalItem('SVG-002', 'Office Furniture', 'Furniture', 'Approved',
 '\$3,200', 'Medium', Colors.orange),
 _DisposalItem('SVG-003', 'Construction Materials', 'Raw Materials',
 'In Progress', '\$8,750', 'Low', Colors.green),
 _DisposalItem('SVG-004', 'Vehicle Fleet (3 units)', 'Vehicles',
 'Pending Auction', '\$45,000', 'High', Colors.red),
 _DisposalItem('SVG-005', 'IT Peripherals', 'Electronics', 'Completed',
 '\$1,800', 'Low', Colors.green),
 _DisposalItem('SVG-006', 'Safety Equipment', 'PPE', 'Approved', '\$2,100',
 'Medium', Colors.orange),
 ];

 static const List<_QueueBoardItem> _defaultQueueBoardItems = [
 _QueueBoardItem(
 'SVG-014', 'Industrial Sensors', 'Review', 'High', '\$9,500'),
 _QueueBoardItem('SVG-018', 'Control Panels', 'Review', 'Medium', '\$4,200'),
 _QueueBoardItem('SVG-022', 'Office Fixtures', 'Approved', 'Low', '\$2,800'),
 _QueueBoardItem('SVG-027', 'Cooling Units', 'Approved', 'High', '\$13,400'),
 _QueueBoardItem('SVG-033', 'Vehicle Fleet', 'Auction', 'High', '\$45,000'),
 _QueueBoardItem('SVG-038', 'Copper Wiring', 'Auction', 'Medium', '\$6,150'),
 ];

 static const List<_AllocationItem> _defaultAllocationItems = [
 _AllocationItem(
 'Sarah Mitchell', 'Team Lead', 'Compliance + Reporting', 82, 'Active'),
 _AllocationItem(
 'James Rodriguez', 'Asset Specialist', 'Inventory Audit', 68, 'Active'),
 _AllocationItem('Emily Chen', 'Logistics Coordinator', 'Vendor Liaison', 45,
 'On Leave'),
 _AllocationItem(
 'Michael Thompson', 'Disposal Technician', 'Field Ops', 76, 'Active'),
 _AllocationItem(
 'Lisa Park', 'Compliance Officer', 'Regulatory Review', 64, 'Active'),
 ];

 static const List<_CapacityItem> _defaultCapacityItems = [
 _CapacityItem('Field Ops', 0.78, Colors.blue),
 _CapacityItem('Compliance', 0.64, Colors.green),
 _CapacityItem('Logistics', 0.52, Colors.orange),
 _CapacityItem('Reporting', 0.83, Colors.purple),
 ];

 static const List<_ComplianceRegulationRow> _defaultComplianceRows = [
 _ComplianceRegulationRow(
 regulation: 'EPA 40 CFR 260-270 (RCRA)',
 category: 'Environmental',
 complianceStatus: 'Compliant',
 complianceScore: 96,
 lastAuditDate: 'Apr 15, 2026',
 nextAuditDue: 'Jul 15, 2026',
 daysToExpiry: 70,
 responsibleParty: 'Environmental Manager',
 riskLevel: 'Low',
 findings: 0,
 correctiveActions: 0,
 priority: 'P3',
 status: 'Active',
 lastUpdated: '2 hrs ago',
 ),
 _ComplianceRegulationRow(
 regulation: 'OSHA 29 CFR 1910 (General Industry)',
 category: 'Safety',
 complianceStatus: 'Compliant',
 complianceScore: 94,
 lastAuditDate: 'Apr 10, 2026',
 nextAuditDue: 'Oct 10, 2026',
 daysToExpiry: 157,
 responsibleParty: 'Safety Officer',
 riskLevel: 'Low',
 findings: 1,
 correctiveActions: 1,
 priority: 'P3',
 status: 'Active',
 lastUpdated: '5 hrs ago',
 ),
 _ComplianceRegulationRow(
 regulation: 'ISO 14001:2015 (Environmental Mgmt)',
 category: 'Environmental',
 complianceStatus: 'Conditional',
 complianceScore: 82,
 lastAuditDate: 'Mar 28, 2026',
 nextAuditDue: 'Jun 28, 2026',
 daysToExpiry: 53,
 responsibleParty: 'Compliance Lead',
 riskLevel: 'Medium',
 findings: 3,
 correctiveActions: 2,
 priority: 'P2',
 status: 'Under Review',
 lastUpdated: '1 day ago',
 ),
 _ComplianceRegulationRow(
 regulation: 'Hazmat 49 CFR 171-180 (DOT)',
 category: 'Safety',
 complianceStatus: 'Renewal Due',
 complianceScore: 71,
 lastAuditDate: 'Feb 20, 2026',
 nextAuditDue: 'May 20, 2026',
 daysToExpiry: 14,
 responsibleParty: 'Hazmat Coordinator',
 riskLevel: 'High',
 findings: 5,
 correctiveActions: 4,
 priority: 'P1',
 status: 'Under Review',
 lastUpdated: '3 hrs ago',
 ),
 _ComplianceRegulationRow(
 regulation: 'ISO 45001:2018 (OH&S Mgmt)',
 category: 'Health',
 complianceStatus: 'Compliant',
 complianceScore: 91,
 lastAuditDate: 'Apr 5, 2026',
 nextAuditDue: 'Oct 5, 2026',
 daysToExpiry: 152,
 responsibleParty: 'HSE Manager',
 riskLevel: 'Low',
 findings: 1,
 correctiveActions: 0,
 priority: 'P3',
 status: 'Active',
 lastUpdated: '1 week ago',
 ),
 _ComplianceRegulationRow(
 regulation: 'NEPA (Environmental Impact)',
 category: 'Environmental',
 complianceStatus: 'Pending',
 complianceScore: 55,
 lastAuditDate: 'Jan 15, 2026',
 nextAuditDue: 'May 15, 2026',
 daysToExpiry: 9,
 responsibleParty: 'Environmental Manager',
 riskLevel: 'High',
 findings: 7,
 correctiveActions: 5,
 priority: 'P1',
 status: 'Under Review',
 lastUpdated: '6 hrs ago',
 ),
 _ComplianceRegulationRow(
 regulation: 'Clean Air Act (CAA) Title V',
 category: 'Environmental',
 complianceStatus: 'Compliant',
 complianceScore: 88,
 lastAuditDate: 'Mar 1, 2026',
 nextAuditDue: 'Sep 1, 2026',
 daysToExpiry: 118,
 responsibleParty: 'Air Quality Engineer',
 riskLevel: 'Low',
 findings: 2,
 correctiveActions: 1,
 priority: 'P2',
 status: 'Active',
 lastUpdated: '2 days ago',
 ),
 _ComplianceRegulationRow(
 regulation: 'Clean Water Act (CWA) NPDES',
 category: 'Environmental',
 complianceStatus: 'Compliant',
 complianceScore: 93,
 lastAuditDate: 'Apr 12, 2026',
 nextAuditDue: 'Jul 12, 2026',
 daysToExpiry: 67,
 responsibleParty: 'Water Quality Specialist',
 riskLevel: 'Low',
 findings: 0,
 correctiveActions: 0,
 priority: 'P3',
 status: 'Active',
 lastUpdated: '4 hrs ago',
 ),
 _ComplianceRegulationRow(
 regulation: 'RCRA Hazardous Waste Manifest',
 category: 'Environmental',
 complianceStatus: 'Non-Compliant',
 complianceScore: 42,
 lastAuditDate: 'Apr 1, 2026',
 nextAuditDue: 'May 1, 2026',
 daysToExpiry: -5,
 responsibleParty: 'Waste Management Lead',
 riskLevel: 'Critical',
 findings: 9,
 correctiveActions: 7,
 priority: 'P1',
 status: 'Under Review',
 lastUpdated: '30 min ago',
 ),
 _ComplianceRegulationRow(
 regulation: 'OSHA 29 CFR 1926 (Construction)',
 category: 'Safety',
 complianceStatus: 'Compliant',
 complianceScore: 90,
 lastAuditDate: 'Mar 20, 2026',
 nextAuditDue: 'Jun 20, 2026',
 daysToExpiry: 45,
 responsibleParty: 'Construction Safety Lead',
 riskLevel: 'Low',
 findings: 2,
 correctiveActions: 1,
 priority: 'P2',
 status: 'Active',
 lastUpdated: '1 day ago',
 ),
 _ComplianceRegulationRow(
 regulation: 'EPCRA Section 313 (TRI Reporting)',
 category: 'Legal',
 complianceStatus: 'Compliant',
 complianceScore: 97,
 lastAuditDate: 'Feb 28, 2026',
 nextAuditDue: 'Jul 1, 2026',
 daysToExpiry: 56,
 responsibleParty: 'Regulatory Affairs',
 riskLevel: 'Low',
 findings: 0,
 correctiveActions: 0,
 priority: 'P3',
 status: 'Active',
 lastUpdated: '3 days ago',
 ),
 _ComplianceRegulationRow(
 regulation: 'Asset Transfer & Disposal Records',
 category: 'Financial',
 complianceStatus: 'Compliant',
 complianceScore: 95,
 lastAuditDate: 'Apr 8, 2026',
 nextAuditDue: 'Oct 8, 2026',
 daysToExpiry: 155,
 responsibleParty: 'Finance Controller',
 riskLevel: 'Low',
 findings: 0,
 correctiveActions: 0,
 priority: 'P3',
 status: 'Active',
 lastUpdated: '12 hrs ago',
 ),
 ];

 @override
 void initState() {
 super.initState();
 _applyDefaults();
 WidgetsBinding.instance.addPostFrameCallback((_) {
 _autoPopulateIfNeeded();
 _loadComplianceFromFirestore();
 });
 }

 
 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Salvage & Disposal Team',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['salvage_disposal_team_screen'] ?? 'No data recorded.'),
 ],
 );
 }
void _applyDefaults() {
 _overviewStats
 ..clear()
 ..addAll(_defaultOverviewStats);
 _inventoryStats
 ..clear()
 ..addAll(_defaultInventoryStats);
 _queueStats
 ..clear()
 ..addAll(_defaultQueueStats);
 _allocationStats
 ..clear()
 ..addAll(_defaultAllocationStats);
 _queueBoardItems
 ..clear()
 ..addAll(_defaultQueueBoardItems);
 _allocationItems
 ..clear()
 ..addAll(_defaultAllocationItems);
 _capacityItems
 ..clear()
 ..addAll(_defaultCapacityItems);
 _complianceRows
 ..clear()
 ..addAll(_defaultComplianceRows);
 }

 Future<void> _autoPopulateIfNeeded() async {
 if (!mounted || _autoGenerationTriggered || _isAutoGenerating) return;
 final projectId = _getProjectId();
 if (projectId == null || projectId.isEmpty) return;

 _autoGenerationTriggered = true;

 final inventorySnap = await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('salvage_inventory')
 .limit(1)
 .get();
 final disposalSnap = await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('salvage_disposal')
 .limit(1)
 .get();
 final teamSnap = await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('salvage_team_members')
 .limit(1)
 .get();

 final needsInventory = inventorySnap.docs.isEmpty;
 final needsDisposal = disposalSnap.docs.isEmpty;
 final needsTeam = teamSnap.docs.isEmpty;

 if (!needsInventory && !needsDisposal && !needsTeam) return;

 if (mounted) {
 setState(() => _isAutoGenerating = true);
 } else {
 _isAutoGenerating = true;
 }

 Map<String, List<LaunchEntry>> generated = {};
 try {
 generated = await ExecutionPhaseAiSeed.generateEntries(
 context: context,
 section: 'Salvage & Disposal',
 sections: const {
 'team_members':
 'Salvage/disposal team members with role, focus area, email, status, and items handled',
 'inventory':
 'Inventory items with asset ID, category, condition, location, status, and estimated value',
 'disposal':
 'Disposal queue items with asset ID, category, status, priority, and estimated value',
 },
 itemsPerSection: 4,
 );
 } catch (e) {
 debugPrint('Salvage AI seed failed: $e');
 }

 final teamSeeds = _mapTeamSeeds(generated['team_members']);
 final inventorySeeds = _mapInventorySeeds(generated['inventory']);
 final disposalSeeds = _mapDisposalSeeds(generated['disposal']);

 final fallbackTeam = teamSeeds.isNotEmpty ? teamSeeds : _defaultTeamMembers;
 final fallbackInventory =
 inventorySeeds.isNotEmpty ? inventorySeeds : _defaultInventoryItems;
 final fallbackDisposal =
 disposalSeeds.isNotEmpty ? disposalSeeds : _defaultDisposalItems;

 try {
 if (needsTeam) {
 for (final seed in fallbackTeam) {
 await SalvageService.createTeamMember(
 projectId: projectId,
 name: seed.name,
 role: seed.role,
 email: seed.email,
 status: seed.status,
 itemsHandled: seed.tasks,
 );
 }
 }
 if (needsInventory) {
 for (final seed in fallbackInventory) {
 await SalvageService.createInventoryItem(
 projectId: projectId,
 assetId: seed.id,
 name: seed.name,
 category: seed.category,
 condition: seed.condition,
 location: seed.location,
 status: seed.status,
 estimatedValue: seed.value,
 );
 }
 }
 if (needsDisposal) {
 for (final seed in fallbackDisposal) {
 await SalvageService.createDisposalItem(
 projectId: projectId,
 assetId: seed.id,
 name: seed.description,
 category: seed.category,
 condition: '',
 location: '',
 disposalMethod: _disposalMethodFromStatus(seed.status),
 status: seed.status,
 estimatedValue: seed.value,
 disposalCost: '',
 priority: seed.priority,
 assignedTo: '',
 targetDate: '',
 );
 }
 }

 // Auto-seed timeline if empty
 final timelineSnap = await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('salvage_timeline')
 .limit(1)
 .get();
 if (timelineSnap.docs.isEmpty) {
 final defaultTimeline = [
 ('Asset Audit Complete', 'Complete physical inventory and condition assessment of all assets', 'Planning', 'Completed', 'Environmental Manager', '2026-03-01', '2026-03-15', 100, 'High'),
 ('Vendor Bidding Opens', 'Issue RFPs and open bidding for disposal vendors', 'Execution', 'Completed', 'Procurement Lead', '2026-03-16', '2026-03-20', 100, 'High'),
 ('Auction Date', 'Conduct public auction for high-value assets', 'Execution', 'In Progress', 'Auction Coordinator', '2026-03-21', '2026-03-28', 65, 'Critical'),
 ('Final Disposal Report', 'Compile final disposal documentation and reconciliation report', 'Review', 'Not Started', 'Compliance Officer', '2026-03-29', '2026-04-05', 0, 'High'),
 ('Project Closure', 'Formal project sign-off and archive disposal records', 'Closure', 'Not Started', 'Project Manager', '2026-04-06', '2026-04-15', 0, 'Medium'),
 ];
 for (final t in defaultTimeline) {
 await SalvageService.createTimelineItem(
 projectId: projectId,
 milestone: t.$1,
 description: t.$2,
 phase: t.$3,
 status: t.$4,
 owner: t.$5,
 startDate: t.$6,
 dueDate: t.$7,
 progress: t.$8,
 priority: t.$9,
 );
 }
 }

 if (mounted) {
 setState(() {
 _queueBoardItems
 ..clear()
 ..addAll(_mapQueueBoardItems(fallbackDisposal));
 _allocationItems
 ..clear()
 ..addAll(_mapAllocationItems(fallbackTeam));
 _isAutoGenerating = false;
 });
 } else {
 _isAutoGenerating = false;
 }
 } catch (e) {
 debugPrint('Salvage auto-seed write failed: $e');
 if (mounted) {
 setState(() => _isAutoGenerating = false);
 } else {
 _isAutoGenerating = false;
 }
 }
 }

 Future<void> _loadComplianceFromFirestore() async {
 final projectId = _getProjectId();
 if (projectId == null || projectId.isEmpty) return;
 setState(() => _isLoadingCompliance = true);
 try {
 final doc = await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('salvage_compliance')
 .doc('compliance_regulations')
 .get();
 final data = doc.data();
 if (data != null && data['rows'] != null) {
 final rows = (data['rows'] as List)
 .map((e) => _ComplianceRegulationRow.fromMap(e as Map<String, dynamic>))
 .toList();
 if (rows.isNotEmpty) {
 setState(() {
 _complianceRows
 ..clear()
 ..addAll(rows);
 });
 }
 }
 } catch (e) {
 debugPrint('Compliance load error: $e');
 } finally {
 if (mounted) setState(() => _isLoadingCompliance = false);
 }
 }

 Future<void> _saveComplianceToFirestore() async {
 final projectId = _getProjectId();
 if (projectId == null || projectId.isEmpty) return;
 try {
 await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('salvage_compliance')
 .doc('compliance_regulations')
 .set({
 'rows': _complianceRows.map((e) => e.toMap()).toList(),
 'updatedAt': FieldValue.serverTimestamp(),
 }, SetOptions(merge: true));
 } catch (e) {
 debugPrint('Compliance save error: $e');
 }
 }

 List<_TeamMember> _mapTeamSeeds(List<LaunchEntry>? entries) {
 if (entries == null) return [];
 var index = 0;
 return entries.map((entry) {
 index += 1;
 final details = entry.details;
 final name = entry.title.trim().isNotEmpty
 ? entry.title.trim()
 : 'Team Member $index';
 final role = _extractField(details, ['Role', 'Position']);
 final email = _extractField(details, ['Email', 'Contact']);
 final status = entry.status?.trim().isNotEmpty == true
 ? entry.status!.trim()
 : _extractField(details, ['Status']);
 final itemsText =
 _extractField(details, ['Items Handled', 'Handled', 'Items']);
 final itemsHandled = _parseInt(itemsText, fallback: 6 + index);
 final normalizedRole = role.isNotEmpty ? role : 'Operations Specialist';
 final normalizedStatus = status.isNotEmpty ? status : 'Active';
 final normalizedEmail = email.isNotEmpty ? email : _fallbackEmail(name);
 final statusColor = normalizedStatus.toLowerCase().contains('leave')
 ? Colors.orange
 : Colors.green;
 return _TeamMember(name, normalizedRole, normalizedEmail,
 normalizedStatus, itemsHandled, statusColor);
 }).toList();
 }

 List<_InventoryItem> _mapInventorySeeds(List<LaunchEntry>? entries) {
 if (entries == null) return [];
 var index = 0;
 return entries.map((entry) {
 index += 1;
 final details = entry.details;
 final assetId = _extractField(details, ['Asset ID', 'Asset', 'ID']);
 final resolvedAssetId =
 assetId.isNotEmpty ? assetId : _buildAssetId(index);
 final name = entry.title.trim().isNotEmpty
 ? entry.title.trim()
 : 'Asset $resolvedAssetId';
 final category =
 _extractField(details, ['Category', 'Type']).trim().isNotEmpty
 ? _extractField(details, ['Category', 'Type']).trim()
 : 'General';
 final condition = _extractField(details, ['Condition']).trim().isNotEmpty
 ? _extractField(details, ['Condition']).trim()
 : 'Good';
 final location =
 _extractField(details, ['Location', 'Site']).trim().isNotEmpty
 ? _extractField(details, ['Location', 'Site']).trim()
 : 'Main Site';
 final status = _extractField(details, ['Status']).trim().isNotEmpty
 ? _extractField(details, ['Status']).trim()
 : 'Ready';
 final value = _normalizeMoney(
 _extractField(details, ['Value', 'Estimated Value', 'Estimated']));
 final normalizedValue =
 value.isNotEmpty ? value : _normalizeMoney('${4000 + index * 1200}');
 return _InventoryItem(resolvedAssetId, name, category, condition,
 location, status, normalizedValue, _statusColor(status));
 }).toList();
 }

 List<_DisposalItem> _mapDisposalSeeds(List<LaunchEntry>? entries) {
 if (entries == null) return [];
 var index = 0;
 return entries.map((entry) {
 index += 1;
 final details = entry.details;
 final assetId = _extractField(details, ['Asset ID', 'Asset', 'ID']);
 final resolvedAssetId =
 assetId.isNotEmpty ? assetId : _buildAssetId(index + 10);
 final description = entry.title.trim().isNotEmpty
 ? entry.title.trim()
 : 'Asset $resolvedAssetId';
 final category =
 _extractField(details, ['Category', 'Type']).trim().isNotEmpty
 ? _extractField(details, ['Category', 'Type']).trim()
 : 'General';
 final status = entry.status?.trim().isNotEmpty == true
 ? entry.status!.trim()
 : _extractField(details, ['Status']);
 final priority =
 _normalizePriority(_extractField(details, ['Priority', 'Urgency']));
 final value = _normalizeMoney(
 _extractField(details, ['Value', 'Estimated Value', 'Estimated']));
 final normalizedStatus = status.isNotEmpty ? status : 'Pending Review';
 final normalizedPriority = priority.isNotEmpty ? priority : 'Medium';
 final normalizedValue =
 value.isNotEmpty ? value : _normalizeMoney('${3500 + index * 900}');
 return _DisposalItem(
 resolvedAssetId,
 description,
 category,
 normalizedStatus,
 normalizedValue,
 normalizedPriority,
 _priorityColor(normalizedPriority));
 }).toList();
 }

 List<_QueueBoardItem> _mapQueueBoardItems(List<_DisposalItem> items) {
 return items.take(6).map((item) {
 return _QueueBoardItem(
 item.id,
 item.description,
 _queueLaneFor(item.status),
 item.priority,
 item.value,
 );
 }).toList();
 }

 List<_AllocationItem> _mapAllocationItems(List<_TeamMember> members) {
 return members.map((member) {
 final focus = _focusFromRole(member.role);
 final workload = _workloadFromTasks(member.tasks);
 return _AllocationItem(
 member.name, member.role, focus, workload, member.status);
 }).toList();
 }

 List<_QueueBoardItem> _mapQueueBoardFromModels(
 List<SalvageDisposalItemModel> items) {
 return items.take(6).map((item) {
 return _QueueBoardItem(
 item.assetId,
 item.name,
 _queueLaneFor(item.status),
 _normalizePriority(item.priority),
 item.estimatedValue,
 );
 }).toList();
 }

 List<_AllocationItem> _mapAllocationFromMembers(
 List<SalvageTeamMemberModel> members) {
 return members.map((member) {
 final focus = _focusFromRole(member.role);
 final workload = _workloadFromTasks(member.itemsHandled);
 return _AllocationItem(
 member.name, member.role, focus, workload, member.status);
 }).toList();
 }

 String _extractField(String? text, List<String> keys) {
 if (text == null || text.trim().isEmpty) return '';
 final parts = text.split(RegExp(r'[|\\n]'));
 for (final raw in parts) {
 final part = raw.trim();
 for (final key in keys) {
 final regex = RegExp('^${RegExp.escape(key)}\\s*:?\\s*(.+)\$',
 caseSensitive: false);
 final match = regex.firstMatch(part);
 if (match != null) {
 return match.group(1)?.trim() ?? '';
 }
 }
 }
 return '';
 }

 int _parseInt(String text, {int fallback = 0}) {
 final match = RegExp(r'\\d+').firstMatch(text);
 if (match == null) return fallback;
 return int.tryParse(match.group(0) ?? '') ?? fallback;
 }

 String _normalizeMoney(String value) {
 final trimmed = value.trim();
 if (trimmed.isEmpty) return '';
 if (trimmed.contains('\$')) return trimmed;
 return '\$$trimmed';
 }

 String _fallbackEmail(String name) {
 final slug = name.trim().toLowerCase().replaceAll(RegExp(r'\\s+'), '.');
 return slug.isEmpty ? 'ops@company.com' : '$slug@company.com';
 }

 String _buildAssetId(int index) {
 final padded = index.toString().padLeft(3, '0');
 return 'SVG-$padded';
 }

 String _normalizePriority(String value) {
 final lower = value.toLowerCase();
 if (lower.contains('high')) return 'High';
 if (lower.contains('low')) return 'Low';
 if (lower.contains('medium')) return 'Medium';
 return value.trim().isNotEmpty ? value.trim() : '';
 }

 String _queueLaneFor(String status) {
 final lower = status.toLowerCase();
 if (lower.contains('auction')) return 'Auction';
 if (lower.contains('approved')) return 'Approved';
 return 'Review';
 }

 String _disposalMethodFromStatus(String status) {
 final lower = status.toLowerCase();
 if (lower.contains('auction')) return 'Auction';
 if (lower.contains('completed')) return 'Resell';
 if (lower.contains('approved')) return 'Recycle';
 if (lower.contains('progress')) return 'Resell';
 return 'Auction';
 }

 String _focusFromRole(String role) {
 final lower = role.toLowerCase();
 if (lower.contains('compliance')) return 'Regulatory Review';
 if (lower.contains('logistics')) return 'Vendor Liaison';
 if (lower.contains('asset')) return 'Inventory Audit';
 if (lower.contains('disposal') || lower.contains('field')) {
 return 'Field Ops';
 }
 if (lower.contains('lead') || lower.contains('manager')) {
 return 'Compliance + Reporting';
 }
 return 'Operations Support';
 }

 int _workloadFromTasks(int tasks) {
 final workload = (tasks * 6).clamp(35, 95);
 return workload;
 }

 Color _statusColor(String status) {
 final lower = status.toLowerCase();
 if (lower.contains('flag') || lower.contains('review')) {
 return Colors.red;
 }
 if (lower.contains('pending')) {
 return Colors.orange;
 }
 return Colors.green;
 }

 Color _priorityColor(String priority) {
 switch (priority.toLowerCase()) {
 case 'high':
 return Colors.red;
 case 'low':
 return Colors.green;
 case 'medium':
 default:
 return Colors.orange;
 }
 }

 @override
 Widget build(BuildContext context) {
 final isNarrow = MediaQuery.sizeOf(context).width < 900;
 final padding = AppBreakpoints.pagePadding(context);

 return ResponsiveScaffold(
 activeItemLabel: 'Salvage and/or Disposal Plan',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: SingleChildScrollView(
 padding: EdgeInsets.all(padding),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(
 title: 'Salvage and Disposal Team',
showNavigationButtons: false, onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 _buildHeader(isNarrow),
 const SizedBox(height: 24),
 _buildTabBar(),
 const SizedBox(height: 24),
 _buildTabContent(isNarrow),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Identify & Staff Ops Team',
 nextLabel: 'Next: Deliver Project Closure',
 onBack: () => IdentifyStaffOpsTeamScreen.open(context),
 onNext: () => DeliverProjectClosureScreen.open(context),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildTabContent(bool isNarrow) {
 switch (_selectedTab) {
 case 1:
 return _buildAssetInventoryContent(isNarrow);
 case 2:
 return _buildDisposalQueueContent(isNarrow);
 case 3:
 return _buildTeamAllocationContent(isNarrow);
 case 0:
 default:
 return _buildOverviewContent(isNarrow);
 }
 }

 Widget _buildHeader(bool isNarrow) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Salvage & Disposal Team Management',
 style: TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.w700,
 color: Color(0xFF1A1D1F)),
 ),
 const SizedBox(height: 8),
 Text(
 'Manage salvage operations, asset disposal workflows, and team assignments for project decommissioning.',
 style: TextStyle(fontSize: 14, color: Colors.grey[600]),
 ),
 ],
 ),
 ),
 if (!isNarrow) ...[
 const SizedBox(width: 16),
 ],
 ],
 ),
 if (isNarrow) ...[
 const SizedBox(height: 16),
 ],
 ],
 );
 }

 Widget _buildTabBar() {
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: Row(
 children: List.generate(_tabs.length, (index) {
 final isSelected = _selectedTab == index;
 return Padding(
 padding: const EdgeInsets.only(right: 8),
 child: InkWell(
 onTap: () => setState(() => _selectedTab = index),
 borderRadius: BorderRadius.circular(20),
 child: Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
 decoration: BoxDecoration(
 color:
 isSelected ? const Color(0xFF0EA5E9) : Colors.transparent,
 borderRadius: BorderRadius.circular(20),
 border: isSelected
 ? null
 : Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Text(
 _tabs[index],
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: isSelected ? Colors.white : const Color(0xFF64748B),
 ),
 ),
 ),
 ),
 );
 }),
 ),
 );
 }

 Widget _buildOverviewContent(bool isNarrow) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildStatsRow(isNarrow, _overviewStats),
 const SizedBox(height: 24),
 _buildInsightsRow(isNarrow),
 const SizedBox(height: 24),
 if (isNarrow) ...[
 _buildTeamManagementPanel(),
 const SizedBox(height: 24),
 _buildDisposalQueuePanel(),
 const SizedBox(height: 24),
 _buildCompliancePanel(),
 const SizedBox(height: 24),
 _buildTimelinePanel(),
 ] else ...[
 _buildTeamManagementPanel(),
 const SizedBox(height: 24),
 _buildCompliancePanel(),
 const SizedBox(height: 24),
 _buildDisposalQueuePanel(),
 const SizedBox(height: 24),
 _buildTimelinePanel(),
 ],
 ],
 );
 }

 Widget _buildAssetInventoryContent(bool isNarrow) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildStatsRow(isNarrow, _inventoryStats),
 const SizedBox(height: 24),
 if (isNarrow)
 _buildInventoryTable()
 else
 _buildInventoryTable(),
 ],
 );
 }

 Widget _buildDisposalQueueContent(bool isNarrow) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildStatsRow(isNarrow, _queueStats),
 const SizedBox(height: 24),
 Column(
 children: [
 _buildQueueBoard(),
 const SizedBox(height: 24),
 _buildDisposalQueuePanel(),
 const SizedBox(height: 24),
 _buildCompliancePanel(),
 const SizedBox(height: 24),
 _buildTimelinePanel(),
 ],
 ),
 ],
 );
 }

 Widget _buildTeamAllocationContent(bool isNarrow) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildStatsRow(isNarrow, _allocationStats),
 const SizedBox(height: 24),
 if (isNarrow)
 Column(
 children: [
 _buildAllocationTable(),
 const SizedBox(height: 24),
 _buildCapacityPanel(),
 const SizedBox(height: 24),
 _buildCoveragePanel(),
 ],
 )
 else
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildAllocationTable(),
 const SizedBox(height: 24),
 _buildCapacityPanel(),
 const SizedBox(height: 24),
 _buildCoveragePanel(),
 ],
 ),
 ],
 );
 }

 Widget _buildActionButtons() {
 return Wrap(
 spacing: 12,
 runSpacing: 8,
 children: [
 _buildActionButton(Icons.person_add, 'Add Team Member', onTap: () {
 _showAddTeamMemberDialog(context);
 }),
 _buildActionButton(Icons.inventory_2, 'New Asset Entry', onTap: () {
 _showAddInventoryDialog(context);
 }),
 _buildActionButton(Icons.assessment, 'Generate Report',
 onTap: _showSnapshotReport),
 _buildPrimaryActionButton('Start Disposal Process', onTap: () {
 setState(() => _selectedTab = 2);
 }),
 ],
 );
 }

 Widget _buildActionButton(IconData icon, String label,
 {VoidCallback? onTap}) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(8),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(icon, size: 16, color: const Color(0xFF64748B)),
 const SizedBox(width: 8),
 Text(label,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: Color(0xFF64748B))),
 ],
 ),
 ),
 );
 }

 Widget _buildPrimaryActionButton(String label, {VoidCallback? onTap}) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(8),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
 decoration: BoxDecoration(
 color: const Color(0xFF0EA5E9),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.play_arrow, size: 16, color: Colors.white),
 const SizedBox(width: 8),
 Text(label,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Colors.white)),
 ],
 ),
 ),
 );
 }

 Widget _buildStatsRow(bool isNarrow, List<_StatItem> stats) {
 if (isNarrow) {
 return Wrap(
 spacing: 12,
 runSpacing: 12,
 children:
 stats.map((stat) => _buildStatCard(stat, flex: false)).toList(),
 );
 }

 return Row(
 children: stats
 .map((stat) => Expanded(
 child: Padding(
 padding: const EdgeInsets.only(right: 12),
 child: _buildStatCard(stat),
 ),
 ))
 .toList(),
 );
 }

 Widget _buildStatCard(_StatItem stat, {bool flex = true}) {
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: stat.color.withOpacity(0.1),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Icon(stat.icon, size: 18, color: stat.color),
 ),
 const Spacer(),
 Icon(Icons.trending_up, size: 14, color: Colors.green[400]),
 ],
 ),
 const SizedBox(height: 12),
 Text(stat.value,
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: stat.color)),
 const SizedBox(height: 4),
 Text(stat.label,
 style: TextStyle(fontSize: 12, color: Colors.grey[600])),
 ],
 ),
 );
 }

 Widget _buildInventoryTable() {
 return Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Asset Inventory',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1A1D1F))),
 SizedBox(height: 4),
 Text(
 'Track active assets, condition, and disposal readiness',
 style:
 TextStyle(fontSize: 13, color: Color(0xFF64748B))),
 ],
 ),
 ),
 ElevatedButton(
 onPressed: () => _showAddInventoryDialog(context),
 style: ElevatedButton.styleFrom(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
 backgroundColor: const Color(0xFFF59E0B),
 foregroundColor: Colors.white,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(10),
 ),
 elevation: 0,
 ),
 child: const Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.add, size: 18),
 SizedBox(width: 6),
 Text(
 'Add Item',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: () async {
 final rows = await showCsvImportDialog(context, tableTitle: 'Asset Inventory', columns: [
 CsvColumnSpec(key: 'assetId', label: 'Asset ID', sampleValue: 'SVG-001'),
 CsvColumnSpec(key: 'name', label: 'Asset Name', sampleValue: 'Server Rack'),
 CsvColumnSpec(key: 'category', label: 'Category', sampleValue: 'Physical Infrastructure'),
 CsvColumnSpec(key: 'condition', label: 'Condition', sampleValue: 'Good', allowedValues: ['Excellent', 'Good', 'Fair', 'Needs Review']),
 CsvColumnSpec(key: 'location', label: 'Location', sampleValue: 'Main Site'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Ready', allowedValues: ['Ready', 'Pending', 'Flagged']),
 CsvColumnSpec(key: 'estimatedValue', label: 'Est. Value', sampleValue: '5200'),
 ]);
 if (rows == null || !mounted) return;
 final pid = _getProjectId();
 if (pid == null) return;
 for (final row in rows) {
 await SalvageService.createInventoryItem(projectId: pid, assetId: row['assetId'] ?? '', name: row['name'] ?? '', category: row['category'] ?? '', condition: row['condition'] ?? 'Good', location: row['location'] ?? '', status: row['status'] ?? 'Ready', estimatedValue: row['estimatedValue'] ?? '0');
 }
 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${rows.length} items imported'), backgroundColor: Colors.green));
 },
 icon: const Icon(Icons.upload_file_outlined, size: 16),
 label: const Text('Import CSV'),
 style: OutlinedButton.styleFrom(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(10),
 ),
 foregroundColor: const Color(0xFF2563EB),
 side: const BorderSide(color: Color(0xFF93C5FD)),
 ),
 ),
 ],
 ),
 const SizedBox(height: 20),
 _buildInventoryTableContent(),
 ],
 ),
 );
 }

 Widget _buildInventoryTableContent() {
 final projectId = _getProjectId();
 if (projectId == null) {
 return const Center(
 child: Padding(
 padding: EdgeInsets.all(24.0),
 child: Text('No project selected. Please open a project first.',
 style: TextStyle(color: Color(0xFF64748B))),
 ),
 );
 }

 return StreamBuilder<List<SalvageInventoryItemModel>>(
 stream: SalvageService.streamInventoryItems(projectId),
 builder: (context, snapshot) {
 if (snapshot.connectionState == ConnectionState.waiting) {
 return const Center(
 child: Padding(
 padding: EdgeInsets.all(24.0),
 child: CircularProgressIndicator()));
 }

 if (snapshot.hasError) {
 return Center(
 child: Padding(
 padding: const EdgeInsets.all(24.0),
 child: Text('Error: ${snapshot.error}',
 style: const TextStyle(color: Colors.red)),
 ),
 );
 }

 final items = snapshot.data ?? [];

 return LayoutBuilder(
 builder: (context, constraints) {
 return ConstrainedBox(
 constraints: BoxConstraints(minWidth: constraints.maxWidth),
 child: SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: ConstrainedBox(
 constraints: BoxConstraints(minWidth: constraints.maxWidth),
 child: DataTable(
 headingRowColor: WidgetStateProperty.all(const Color(0xFF1F2937)),
 columnSpacing: 24,
 horizontalMargin: 16,
 dataRowMinHeight: 56,
 dataRowMaxHeight: 72,
 columns: const [
 DataColumn(
 label: Text('Asset',
 style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white))),
 DataColumn(
 label: Text('Category',
 style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white))),
 DataColumn(
 label: Text('Condition',
 style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white))),
 DataColumn(
 label: Text('Location',
 style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white))),
 DataColumn(
 label: Text('Status',
 style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white))),
 DataColumn(
 label: Text('Est. Value',
 style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white))),
 DataColumn(
 label: Text('Actions',
 style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white))),
 ],
 rows: items.isEmpty
 ? [
 const DataRow(cells: [
 DataCell(Text('No inventory items added yet',
 style: TextStyle(
 color: Color(0xFF64748B),
 fontStyle: FontStyle.italic))),
 DataCell(SizedBox()),
 DataCell(SizedBox()),
 DataCell(SizedBox()),
 DataCell(SizedBox()),
 DataCell(SizedBox()),
 DataCell(SizedBox()),
 ]),
 ]
 : items.map((item) {
 Color statusColor;
 switch (item.status.toLowerCase()) {
 case 'ready':
 statusColor = Colors.green;
 break;
 case 'pending':
 statusColor = Colors.orange;
 break;
 case 'flagged':
 statusColor = Colors.red;
 break;
 default:
 statusColor = Colors.blue;
 }

 return DataRow(
 cells: [
 DataCell(Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Text(item.assetId,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF0EA5E9),
 fontWeight: FontWeight.w600)),
 ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 180),
 child: Text(item.name,
 style: const TextStyle(fontSize: 13),
 softWrap: true,
 maxLines: 2,
 overflow: TextOverflow.ellipsis)),
 ],
 )),
 DataCell(ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 160),
 child: _buildCategoryChip(item.category))),
 DataCell(Text(item.condition,
 style: const TextStyle(fontSize: 13))),
 DataCell(Text(item.location,
 style: const TextStyle(
 fontSize: 13, color: Color(0xFF64748B)))),
 DataCell(_buildStatusBadge(item.status, statusColor)),
 DataCell(Text(item.estimatedValue,
 style: const TextStyle(
 fontSize: 13, fontWeight: FontWeight.w600))),
 DataCell(Row(
 children: [
 IconButton(
 icon: const Icon(Icons.edit, size: 16),
 onPressed: () =>
 _showEditInventoryDialog(context, item),
 color: const Color(0xFF64748B),
 ),
 IconButton(
 icon: const Icon(Icons.delete, size: 16),
 onPressed: () =>
 _showDeleteInventoryDialog(context, item),
 color: Colors.red,
 ),
 ],
 )),
 ],
 );
 }).toList(),
 ),
 ),
 ),
 );
 },
 );
 },
 );
 }

 void _showEditInventoryDialog(
 BuildContext context, SalvageInventoryItemModel item) {
 final projectId = _getProjectId();
 if (projectId == null) return;

 final assetIdController = TextEditingController(text: item.assetId);
 final nameController = TextEditingController(text: item.name);
 final categoryController = TextEditingController(text: item.category);
 final conditionController = TextEditingController(text: item.condition);
 final locationController = TextEditingController(text: item.location);
 final statusController = TextEditingController(text: item.status);
 final valueController = TextEditingController(text: item.estimatedValue);

 showDialog(
 context: context,
 barrierDismissible: true,
 builder: (ctx) => LaunchModalShell(
 icon: Icons.edit_rounded,
 accent: const Color(0xFF0EA5E9),
 title: 'Edit Inventory Item',
 subtitle: 'Update the salvage inventory item details.',
 body: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 LaunchModalTextField(
 label: 'Asset ID *',
 controller: assetIdController,
 hint: 'Unique asset identifier',
 ),
 const SizedBox(height: 12),
 LaunchModalTextField(
 label: 'Name *',
 controller: nameController,
 hint: 'Asset name or description',
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalTextField(
 label: 'Category *',
 controller: categoryController,
 hint: 'e.g. Electronics',
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalTextField(
 label: 'Condition *',
 controller: conditionController,
 hint: 'e.g. Good',
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalTextField(
 label: 'Location *',
 controller: locationController,
 hint: 'Where it is stored',
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalTextField(
 label: 'Status *',
 controller: statusController,
 hint: 'Pending / Disposed / etc.',
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 LaunchModalTextField(
 label: 'Estimated Value *',
 controller: valueController,
 hint: 'e.g. 1500.00',
 keyboardType: TextInputType.text,
 ),
 ],
 ),
 actions: [
 LaunchModalCancelButton(
 label: 'Cancel',
 onPressed: () => Navigator.pop(ctx),
 ),
 LaunchModalPrimaryButton(
 label: 'Update',
 icon: Icons.check_rounded,
 onPressed: () async {
 try {
 await SalvageService.updateInventoryItem(
 projectId: projectId,
 itemId: item.id,
 assetId: assetIdController.text,
 name: nameController.text,
 category: categoryController.text,
 condition: conditionController.text,
 location: locationController.text,
 status: statusController.text,
 estimatedValue: valueController.text,
 );
 if (ctx.mounted) {
 Navigator.pop(ctx);
 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
 content: Text('Item updated successfully')));
 }
 } catch (e) {
 if (ctx.mounted) {
 ScaffoldMessenger.of(context)
 .showSnackBar(SnackBar(content: Text('Error: $e')));
 }
 }
 },
 ),
 ],
 ),
 );
 }

 void _showAddInventoryDialog(BuildContext context) {
 final projectId = _getProjectId();
 if (projectId == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('No project selected. Please open a project first.')),
 );
 return;
 }

 final assetIdController = TextEditingController();
 final nameController = TextEditingController();
 final categoryController = TextEditingController();
 final conditionController = TextEditingController();
 final locationController = TextEditingController();
 final statusController = TextEditingController(text: 'Pending');
 final valueController = TextEditingController();

 showDialog(
 context: context,
 barrierDismissible: true,
 builder: (ctx) => LaunchModalShell(
 icon: Icons.inventory_2_rounded,
 accent: const Color(0xFF0EA5E9),
 title: 'Add Inventory Item',
 subtitle: 'Capture a new salvageable inventory item.',
 body: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 LaunchModalTextField(
 label: 'Asset ID *',
 controller: assetIdController,
 hint: 'Unique asset identifier',
 ),
 const SizedBox(height: 12),
 LaunchModalTextField(
 label: 'Name *',
 controller: nameController,
 hint: 'Asset name or description',
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalTextField(
 label: 'Category *',
 controller: categoryController,
 hint: 'e.g. Electronics',
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalTextField(
 label: 'Condition *',
 controller: conditionController,
 hint: 'e.g. Good',
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalTextField(
 label: 'Location *',
 controller: locationController,
 hint: 'Where it is stored',
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalTextField(
 label: 'Status *',
 controller: statusController,
 hint: 'Pending / Disposed / etc.',
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 LaunchModalTextField(
 label: 'Estimated Value *',
 controller: valueController,
 hint: 'e.g. 1500.00',
 keyboardType: TextInputType.text,
 ),
 ],
 ),
 actions: [
 LaunchModalCancelButton(
 label: 'Cancel',
 onPressed: () => Navigator.pop(ctx),
 ),
 LaunchModalPrimaryButton(
 label: 'Add Item',
 icon: Icons.add_rounded,
 onPressed: () async {
 if (assetIdController.text.isEmpty ||
 nameController.text.isEmpty ||
 categoryController.text.isEmpty ||
 conditionController.text.isEmpty ||
 locationController.text.isEmpty ||
 statusController.text.isEmpty ||
 valueController.text.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Please fill in all required fields')),
 );
 return;
 }

 try {
 await SalvageService.createInventoryItem(
 projectId: projectId,
 assetId: assetIdController.text,
 name: nameController.text,
 category: categoryController.text,
 condition: conditionController.text,
 location: locationController.text,
 status: statusController.text,
 estimatedValue: valueController.text,
 );
 if (ctx.mounted) {
 Navigator.pop(ctx);
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Item added successfully')));
 }
 } catch (e) {
 if (ctx.mounted) {
 ScaffoldMessenger.of(context)
 .showSnackBar(SnackBar(content: Text('Error: $e')));
 }
 }
 },
 ),
 ],
 ),
 );
 }

 void _showDeleteInventoryDialog(
 BuildContext context, SalvageInventoryItemModel item) {
 final projectId = _getProjectId();
 if (projectId == null) return;

 showDialog(
 context: context,
 barrierDismissible: true,
 builder: (ctx) => LaunchModalShell(
 icon: Icons.delete_outline_rounded,
 accent: const Color(0xFFEF4444),
 title: 'Delete Inventory Item',
 subtitle: 'This action cannot be undone.',
 body: Text(
 'Are you sure you want to delete "${item.name}"? '
 'Once removed, the inventory record cannot be recovered.',
 style: const TextStyle(
 fontSize: 14,
 color: Color(0xFF4B5563),
 height: 1.5,
 ),
 ),
 actions: [
 LaunchModalCancelButton(
 label: 'Cancel',
 onPressed: () => Navigator.pop(ctx),
 ),
 LaunchModalDangerButton(
 label: 'Delete',
 onPressed: () async {
 try {
 await SalvageService.deleteInventoryItem(
 projectId: projectId, itemId: item.id);
 if (ctx.mounted) {
 Navigator.pop(ctx);
 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
 content: Text('Item deleted successfully')));
 }
 } catch (e) {
 if (ctx.mounted) {
 ScaffoldMessenger.of(context)
 .showSnackBar(SnackBar(content: Text('Error: $e')));
 }
 }
 },
 ),
 ],
 ),
 );
 }

 void _showSnapshotReport() {
 final teamCount = _allocationItems.length;
 final inventoryStatCount = _inventoryStats.length;
 final queueCount = _queueBoardItems.length;
 final report = '''
Execution snapshot:
- Team allocation rows: $teamCount
- Inventory stat cards: $inventoryStatCount
- Disposal queue cards visible: $queueCount
- Disposal progress indicator: 67%
''';
 showDialog<void>(
 context: context,
 barrierDismissible: true,
 builder: (dialogContext) => LaunchModalShell(
 icon: Icons.insights_rounded,
 accent: const Color(0xFF0EA5E9),
 title: 'Salvage & Disposal Snapshot',
 subtitle: 'A quick summary of execution readiness.',
 body: Text(
 report.trim(),
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF4B5563),
 height: 1.6,
 fontFamily: 'monospace',
 ),
 ),
 actions: [
 LaunchModalPrimaryButton(
 label: 'Close',
 icon: Icons.check_rounded,
 onPressed: () => Navigator.of(dialogContext).pop(),
 ),
 ],
 ),
 );
 }

 void _showAddTeamMemberDialog(BuildContext context) {
 _showTeamMemberDialog(context, null);
 }

 void _showEditTeamMemberDialog(
 BuildContext context, SalvageTeamMemberModel member) {
 _showTeamMemberDialog(context, member);
 }

 void _showTeamMemberDialog(
 BuildContext context, SalvageTeamMemberModel? member) {
 final projectId = _getProjectId();
 if (projectId == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('No project selected. Please open a project first.')),
 );
 return;
 }

 final isEdit = member != null;
 final nameController = TextEditingController(text: member?.name ?? '');
 final roleController = TextEditingController(text: member?.role ?? '');
 final emailController = TextEditingController(text: member?.email ?? '');
 final itemsHandledController =
 TextEditingController(text: (member?.itemsHandled ?? 0).toString());
 var selectedStatus = member?.status ?? 'Active';

 showDialog<void>(
 context: context,
 barrierDismissible: true,
 builder: (dialogContext) => StatefulBuilder(
 builder: (dialogContext, setDialogState) => LaunchModalShell(
 icon: isEdit ? Icons.edit_rounded : Icons.group_add_rounded,
 accent: const Color(0xFF10B981),
 title: isEdit ? 'Edit Team Member' : 'Add Team Member',
 subtitle: isEdit
 ? 'Update the salvage team member profile.'
 : 'Capture a new salvage team member with role and contact.',
 body: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 LaunchModalTextField(
 label: 'Name *',
 controller: nameController,
 hint: 'Full name of the team member',
 ),
 const SizedBox(height: 12),
 LaunchModalTextField(
 label: 'Role *',
 controller: roleController,
 hint: 'e.g. Salvage Lead',
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalTextField(
 label: 'Email *',
 controller: emailController,
 hint: 'name@company.com',
 keyboardType: TextInputType.emailAddress,
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalDropdown<String>(
 label: 'Status',
 value: selectedStatus,
 items: const ['Active', 'On Leave', 'Inactive'],
 onChanged: (value) {
 if (value != null) {
 setDialogState(() => selectedStatus = value);
 }
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 LaunchModalTextField(
 label: 'Items Handled',
 controller: itemsHandledController,
 hint: 'Number of items handled',
 keyboardType: TextInputType.number,
 ),
 ],
 ),
 actions: [
 LaunchModalCancelButton(
 label: 'Cancel',
 onPressed: () => Navigator.of(dialogContext).pop(),
 ),
 LaunchModalPrimaryButton(
 label: isEdit ? 'Update' : 'Add Member',
 icon: isEdit ? Icons.check_rounded : Icons.add_rounded,
 onPressed: () async {
 if (nameController.text.trim().isEmpty ||
 roleController.text.trim().isEmpty ||
 emailController.text.trim().isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Please complete all required fields.')),
 );
 return;
 }

 try {
 if (isEdit) {
 await SalvageService.updateTeamMember(
 projectId: projectId,
 memberId: member.id,
 name: nameController.text.trim(),
 role: roleController.text.trim(),
 email: emailController.text.trim(),
 status: selectedStatus,
 itemsHandled:
 int.tryParse(itemsHandledController.text.trim()) ?? 0,
 );
 } else {
 await SalvageService.createTeamMember(
 projectId: projectId,
 name: nameController.text.trim(),
 role: roleController.text.trim(),
 email: emailController.text.trim(),
 status: selectedStatus,
 itemsHandled:
 int.tryParse(itemsHandledController.text.trim()) ?? 0,
 );
 }
 if (!context.mounted) return;
 Navigator.of(dialogContext).pop();
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 isEdit
 ? 'Team member updated successfully.'
 : 'Team member added successfully.',
 ),
 ),
 );
 } catch (e) {
 if (!context.mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error: $e')),
 );
 }
 },
 ),
 ],
 ),
 ),
 );
 }

 void _showDeleteTeamMemberDialog(
 BuildContext context, SalvageTeamMemberModel member) {
 final projectId = _getProjectId();
 if (projectId == null) return;

 showDialog<void>(
 context: context,
 barrierDismissible: true,
 builder: (dialogContext) => LaunchModalShell(
 icon: Icons.delete_outline_rounded,
 accent: const Color(0xFFEF4444),
 title: 'Delete Team Member',
 subtitle: 'This action cannot be undone.',
 body: Text(
 'Are you sure you want to delete "${member.name}"? '
 'Once removed, the member record cannot be recovered.',
 style: const TextStyle(
 fontSize: 14,
 color: Color(0xFF4B5563),
 height: 1.5,
 ),
 ),
 actions: [
 LaunchModalCancelButton(
 label: 'Cancel',
 onPressed: () => Navigator.of(dialogContext).pop(),
 ),
 LaunchModalDangerButton(
 label: 'Delete',
 onPressed: () async {
 try {
 await SalvageService.deleteTeamMember(
 projectId: projectId,
 memberId: member.id,
 );
 if (!context.mounted) return;
 Navigator.of(dialogContext).pop();
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Team member deleted.')),
 );
 } catch (e) {
 if (!context.mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error deleting member: $e')),
 );
 }
 },
 ),
 ],
 ),
 );
 }

 void _showAddDisposalDialog(BuildContext context) {
 _showDisposalDialog(context, null);
 }

 void _showEditDisposalDialog(
 BuildContext context, SalvageDisposalItemModel item) {
 _showDisposalDialog(context, item);
 }

 void _showDisposalDialog(
 BuildContext context, SalvageDisposalItemModel? item) {
 final projectId = _getProjectId();
 if (projectId == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('No project selected. Please open a project first.')),
 );
 return;
 }

 final isEdit = item != null;
 final assetIdController = TextEditingController(text: item?.assetId ?? '');
 final nameController = TextEditingController(text: item?.name ?? '');
 final categoryController =
 TextEditingController(text: item?.category ?? '');
 final conditionController =
 TextEditingController(text: item?.condition ?? '');
 final locationController =
 TextEditingController(text: item?.location ?? '');
 final valueController =
 TextEditingController(text: item?.estimatedValue ?? '');
 final disposalCostController =
 TextEditingController(text: item?.disposalCost ?? '');
 final assignedToController =
 TextEditingController(text: item?.assignedTo ?? '');
 final targetDateController =
 TextEditingController(text: item?.targetDate ?? '');
 var selectedStatus = item?.status ?? 'Pending Review';
 var selectedPriority = item?.priority ?? 'Medium';
 var selectedDisposalMethod = item?.disposalMethod.isNotEmpty == true ? item!.disposalMethod : 'Auction';

 showDialog<void>(
 context: context,
 barrierDismissible: true,
 builder: (dialogContext) => StatefulBuilder(
 builder: (dialogContext, setDialogState) => LaunchModalShell(
 icon: isEdit ? Icons.edit_rounded : Icons.recycling_rounded,
 accent: const Color(0xFF0EA5E9),
 title: isEdit ? 'Edit Disposal Item' : 'Add Disposal Item',
 subtitle: isEdit
 ? 'Update the disposal queue item details.'
 : 'Capture a new asset for disposal processing.',
 body: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalTextField(
 label: 'Asset ID *',
 controller: assetIdController,
 hint: 'Unique asset ID',
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 flex: 2,
 child: LaunchModalTextField(
 label: 'Description *',
 controller: nameController,
 hint: 'Asset description',
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalTextField(
 label: 'Category *',
 controller: categoryController,
 hint: 'e.g. Electronics',
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalDropdown<String>(
 label: 'Condition',
 value: conditionController.text.isEmpty
 ? 'Good'
 : conditionController.text,
 items: const [
 'Excellent', 'Good', 'Fair', 'Poor', 'Non-Functional'
 ],
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => conditionController.text = v);
 }
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalTextField(
 label: 'Location',
 controller: locationController,
 hint: 'Current location',
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalDropdown<String>(
 label: 'Disposal Method',
 value: selectedDisposalMethod,
 items: const [
 'Auction', 'Recycle', 'Donate', 'Scrap', 'Resell', 'Trade-In', 'Transfer'
 ],
 onChanged: (v) {
 if (v != null) setDialogState(() => selectedDisposalMethod = v);
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalDropdown<String>(
 label: 'Status',
 value: selectedStatus,
 items: const [
 'Pending Review',
 'Approved',
 'In Progress',
 'Pending Disposal',
 'Completed',
 'On Hold',
 'Cancelled',
 ],
 onChanged: (v) {
 if (v != null) setDialogState(() => selectedStatus = v);
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalDropdown<String>(
 label: 'Priority',
 value: selectedPriority,
 items: const ['Critical', 'High', 'Medium', 'Low'],
 onChanged: (v) {
 if (v != null) setDialogState(() => selectedPriority = v);
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalTextField(
 label: 'Estimated Value *',
 controller: valueController,
 hint: '0.00',
 keyboardType: TextInputType.text,
 suffixText: '\$',
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalTextField(
 label: 'Disposal Cost',
 controller: disposalCostController,
 hint: '0.00',
 keyboardType: TextInputType.text,
 suffixText: '\$',
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalTextField(
 label: 'Assigned To',
 controller: assignedToController,
 hint: 'Team member responsible',
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalTextField(
 label: 'Target Date',
 controller: targetDateController,
 hint: 'e.g. 2026-06-15',
 ),
 ),
 ],
 ),
 ],
 ),
 actions: [
 LaunchModalCancelButton(
 label: 'Cancel',
 onPressed: () => Navigator.of(dialogContext).pop(),
 ),
 LaunchModalPrimaryButton(
 label: isEdit ? 'Update' : 'Add Item',
 icon: isEdit ? Icons.check_rounded : Icons.add_rounded,
 onPressed: () async {
 if (assetIdController.text.trim().isEmpty ||
 nameController.text.trim().isEmpty ||
 categoryController.text.trim().isEmpty ||
 valueController.text.trim().isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Please complete all required fields.')),
 );
 return;
 }

 try {
 if (isEdit) {
 await SalvageService.updateDisposalItem(
 projectId: projectId,
 itemId: item.id,
 assetId: assetIdController.text.trim(),
 name: nameController.text.trim(),
 category: categoryController.text.trim(),
 condition: conditionController.text.trim(),
 location: locationController.text.trim(),
 disposalMethod: selectedDisposalMethod,
 status: selectedStatus,
 priority: selectedPriority,
 estimatedValue: valueController.text.trim(),
 disposalCost: disposalCostController.text.trim(),
 assignedTo: assignedToController.text.trim(),
 targetDate: targetDateController.text.trim(),
 );
 } else {
 await SalvageService.createDisposalItem(
 projectId: projectId,
 assetId: assetIdController.text.trim(),
 name: nameController.text.trim(),
 category: categoryController.text.trim(),
 condition: conditionController.text.trim(),
 location: locationController.text.trim(),
 disposalMethod: selectedDisposalMethod,
 status: selectedStatus,
 priority: selectedPriority,
 estimatedValue: valueController.text.trim(),
 disposalCost: disposalCostController.text.trim(),
 assignedTo: assignedToController.text.trim(),
 targetDate: targetDateController.text.trim(),
 );
 }
 if (!context.mounted) return;
 Navigator.of(dialogContext).pop();
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 isEdit
 ? 'Disposal item updated successfully.'
 : 'Disposal item added successfully.',
 ),
 backgroundColor: const Color(0xFF0EA5E9),
 behavior: SnackBarBehavior.floating,
 ),
 );
 } catch (e) {
 if (!context.mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error: $e')),
 );
 }
 },
 ),
 ],
 ),
 ),
 );
 }

 void _showDeleteDisposalDialog(
 BuildContext context, SalvageDisposalItemModel item) {
 final projectId = _getProjectId();
 if (projectId == null) return;

 showDialog<void>(
 context: context,
 barrierDismissible: true,
 builder: (dialogContext) => LaunchModalShell(
 icon: Icons.delete_outline_rounded,
 accent: const Color(0xFFEF4444),
 title: 'Delete Disposal Item',
 subtitle: 'This action cannot be undone.',
 body: Text(
 'Are you sure you want to delete "${item.name}"? '
 'Once removed, the disposal record cannot be recovered.',
 style: const TextStyle(
 fontSize: 14,
 color: Color(0xFF4B5563),
 height: 1.5,
 ),
 ),
 actions: [
 LaunchModalCancelButton(
 label: 'Cancel',
 onPressed: () => Navigator.of(dialogContext).pop(),
 ),
 LaunchModalDangerButton(
 label: 'Delete',
 onPressed: () async {
 try {
 await SalvageService.deleteDisposalItem(
 projectId: projectId,
 itemId: item.id,
 );
 if (!context.mounted) return;
 Navigator.of(dialogContext).pop();
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Disposal item deleted.')),
 );
 } catch (e) {
 if (!context.mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error deleting item: $e')),
 );
 }
 },
 ),
 ],
 ),
 );
 }

 Widget _buildInventorySignalsPanel() {
 return Column(
 children: [
 _buildSignalCard(
 title: 'Category Mix',
 subtitle: 'Distribution of assets by category',
 child: Column(
 children: const [
 _SignalBar(
 label: 'Electronics', value: 0.42, color: Color(0xFF0EA5E9)),
 _SignalBar(
 label: 'Infrastructure',
 value: 0.28,
 color: Color(0xFF6366F1)),
 _SignalBar(
 label: 'Safety', value: 0.16, color: Color(0xFFF59E0B)),
 _SignalBar(
 label: 'Vehicles', value: 0.14, color: Color(0xFF22C55E)),
 ],
 ),
 ),
 const SizedBox(height: 20),
 _buildSignalCard(
 title: 'Condition Snapshot',
 subtitle: 'Asset readiness by condition',
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: const [
 _ConditionItem(
 label: 'Excellent',
 count: '28 assets',
 color: Color(0xFF22C55E)),
 _ConditionItem(
 label: 'Good', count: '34 assets', color: Color(0xFF10B981)),
 _ConditionItem(
 label: 'Fair', count: '18 assets', color: Color(0xFFF59E0B)),
 _ConditionItem(
 label: 'Needs Review',
 count: '6 assets',
 color: Color(0xFFEF4444)),
 ],
 ),
 ),
 ],
 );
 }

 Widget _buildSignalCard(
 {required String title,
 required String subtitle,
 required Widget child}) {
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
 Text(title,
 style:
 const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
 const SizedBox(height: 4),
 Text(subtitle,
 style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
 const SizedBox(height: 16),
 child,
 ],
 ),
 );
 }

 Widget _buildQueueBoard() {
 final projectId = _getProjectId();
 if (projectId == null) {
 return _buildQueueBoardBody(_queueBoardItems);
 }

 return StreamBuilder<List<SalvageDisposalItemModel>>(
 stream: SalvageService.streamDisposalItems(projectId),
 builder: (context, snapshot) {
 final items = snapshot.data ?? [];
 final queueItems = items.isNotEmpty
 ? _mapQueueBoardFromModels(items)
 : _queueBoardItems;
 return _buildQueueBoardBody(queueItems);
 },
 );
 }

 Widget _buildQueueBoardBody(List<_QueueBoardItem> items) {
 return Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('Queue Pipeline',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1A1D1F))),
 const SizedBox(height: 4),
 Text('Stage assets by review status and auction readiness',
 style: TextStyle(fontSize: 13, color: Colors.grey[600])),
 const SizedBox(height: 20),
 LayoutBuilder(
 builder: (context, constraints) {
 final isStacked = constraints.maxWidth < 700;
 final lanes = [
 _buildQueueLane('Review', const Color(0xFFFDE68A), items),
 _buildQueueLane('Approved', const Color(0xFFBFDBFE), items),
 _buildQueueLane('Auction', const Color(0xFFBBF7D0), items),
 ];

 if (isStacked) {
 return Column(
 children: lanes
 .map((lane) => Padding(
 padding: const EdgeInsets.only(bottom: 16),
 child: lane,
 ))
 .toList(),
 );
 }

 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: lanes
 .map((lane) => Expanded(
 child: Padding(
 padding: const EdgeInsets.only(right: 16),
 child: lane,
 ),
 ))
 .toList(),
 );
 },
 ),
 ],
 ),
 );
 }

 Widget _buildQueueLane(
 String status, Color accent, List<_QueueBoardItem> items) {
 final filtered = items.where((item) => item.status == status).toList();
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: accent,
 borderRadius: BorderRadius.circular(12),
 ),
 child: Text(status,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1A1D1F))),
 ),
 const SizedBox(height: 12),
 for (final item in filtered) ...[
 _buildQueueCard(item),
 const SizedBox(height: 10),
 ],
 if (filtered.isEmpty)
 Text('No items',
 style: TextStyle(fontSize: 12, color: Colors.grey[500])),
 ],
 ),
 );
 }

 Widget _buildQueueCard(_QueueBoardItem item) {
 final priorityColor = item.priority == 'High'
 ? const Color(0xFFEF4444)
 : item.priority == 'Medium'
 ? const Color(0xFFF59E0B)
 : const Color(0xFF22C55E);

 return Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(item.id,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFF0EA5E9))),
 const SizedBox(height: 4),
 Text(item.title,
 style:
 const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
 const SizedBox(height: 8),
 Row(
 children: [
 _buildPriorityBadge(item.priority, priorityColor),
 const Spacer(),
 Text(item.value,
 style: const TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600)),
 ],
 ),
 ],
 ),
 );
 }

 Widget _buildAllocationTable() {
 final projectId = _getProjectId();
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Team Allocation',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1A1D1F))),
 SizedBox(height: 4),
 Text('Workload balance by role and focus area',
 style:
 TextStyle(fontSize: 13, color: Color(0xFF64748B))),
 ],
 ),
 ),
 ElevatedButton(
 onPressed: () => _showAddTeamMemberDialog(context),
 style: ElevatedButton.styleFrom(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
 backgroundColor: const Color(0xFFF59E0B),
 foregroundColor: Colors.white,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(10),
 ),
 elevation: 0,
 ),
 child: const Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.add, size: 18),
 SizedBox(width: 6),
 Text(
 'Add Member',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: () async {
 final rows = await showCsvImportDialog(context, tableTitle: 'Team Allocation', columns: [
 CsvColumnSpec(key: 'name', label: 'Member Name', sampleValue: 'John Doe'),
 CsvColumnSpec(key: 'role', label: 'Role', sampleValue: 'Product Owner'),
 CsvColumnSpec(key: 'focus', label: 'Focus Area', sampleValue: 'Operations Support'),
 CsvColumnSpec(key: 'workload', label: 'Workload %', sampleValue: '48'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Active', allowedValues: ['Active', 'On Leave']),
 ]);
 if (rows == null || !mounted) return;
 setState(() {
 for (final row in rows) {
 _allocationItems.add(_AllocationItem(
 row['name'] ?? '',
 row['role'] ?? '',
 row['focus'] ?? '',
 int.tryParse(row['workload'] ?? '0') ?? 0,
 row['status'] ?? 'Active',
 ));
 }
 });
 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${rows.length} members imported'), backgroundColor: Colors.green));
 },
 icon: const Icon(Icons.upload_file_outlined, size: 16),
 label: const Text('Import CSV'),
 style: OutlinedButton.styleFrom(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(10),
 ),
 foregroundColor: const Color(0xFF2563EB),
 side: const BorderSide(color: Color(0xFF93C5FD)),
 ),
 ),
 ],
 ),
 const SizedBox(height: 20),
 LayoutBuilder(
 builder: (context, constraints) {
 Widget buildTable(List<_AllocationItem> items) {
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: ConstrainedBox(
 constraints: BoxConstraints(minWidth: constraints.maxWidth),
 child: DataTable(
 headingRowColor:
 WidgetStateProperty.all(const Color(0xFFF8FAFC)),
 columnSpacing: 24,
 horizontalMargin: 16,
 dataRowMinHeight: 56,
 dataRowMaxHeight: 72,
 columns: const [
 DataColumn(
 label: Text('Name',
 style: TextStyle(fontWeight: FontWeight.w600))),
 DataColumn(
 label: Text('Role',
 style: TextStyle(fontWeight: FontWeight.w600))),
 DataColumn(
 label: Text('Focus Area',
 style: TextStyle(fontWeight: FontWeight.w600))),
 DataColumn(
 label: Text('Workload',
 style: TextStyle(fontWeight: FontWeight.w600))),
 DataColumn(
 label: Text('Status',
 style: TextStyle(fontWeight: FontWeight.w600))),
 DataColumn(
 label: Text('Actions',
 style: TextStyle(fontWeight: FontWeight.w600))),
 ],
 rows: items.map((item) {
 final statusColor = item.status == 'Active'
 ? Colors.green
 : Colors.orange;
 return DataRow(cells: [
 DataCell(ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 200),
 child: Text(item.name,
 style: const TextStyle(fontSize: 13),
 softWrap: true,
 maxLines: 2,
 overflow: TextOverflow.ellipsis))),
 DataCell(ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 140),
 child: Text(item.role,
 style: const TextStyle(fontSize: 13),
 softWrap: true,
 maxLines: 2,
 overflow: TextOverflow.ellipsis))),
 DataCell(ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 160),
 child: Text(item.focus,
 style: const TextStyle(
 fontSize: 13, color: Color(0xFF64748B)),
 softWrap: true,
 maxLines: 2,
 overflow: TextOverflow.ellipsis))),
 DataCell(_buildWorkloadChip(item.workload)),
 DataCell(_buildStatusBadge(item.status, statusColor)),
 DataCell(Row(
 children: [
 IconButton(
 icon: const Icon(Icons.edit, size: 16),
 onPressed: () {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Edit allocation actions are available from the Team Roster section.')),
 );
 },
 color: const Color(0xFF64748B)),
 IconButton(
 icon: const Icon(Icons.more_horiz, size: 16),
 onPressed: () {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'More allocation actions will be added in the next refinement pass.')),
 );
 },
 color: const Color(0xFF64748B)),
 ],
 )),
 ]);
 }).toList(),
 ),
 ),
 );
 }

 if (projectId == null) {
 return buildTable(_allocationItems);
 }

 return StreamBuilder<List<SalvageTeamMemberModel>>(
 stream: SalvageService.streamTeamMembers(projectId),
 builder: (context, snapshot) {
 final members = snapshot.data ?? [];
 final items = members.isNotEmpty
 ? _mapAllocationFromMembers(members)
 : _allocationItems;
 return buildTable(items);
 },
 );
 },
 ),
 ],
 ),
 );
 }

 Widget _buildWorkloadChip(int workload) {
 final color = workload >= 80
 ? const Color(0xFFEF4444)
 : workload >= 65
 ? const Color(0xFFF59E0B)
 : const Color(0xFF22C55E);
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: color.withOpacity(0.1),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Text('$workload%',
 style: TextStyle(
 fontSize: 11, fontWeight: FontWeight.w600, color: color)),
 );
 }

 Widget _buildCapacityPanel() {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('Capacity Health',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
 const SizedBox(height: 4),
 Text('Allocation by function',
 style: TextStyle(fontSize: 12, color: Colors.grey[600])),
 const SizedBox(height: 16),
 for (final item in _capacityItems) ...[
 _CapacityBar(item: item),
 const SizedBox(height: 12),
 ],
 ],
 ),
 );
 }

 Widget _buildCoveragePanel() {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('Shift Coverage',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
 const SizedBox(height: 4),
 Text('Upcoming availability and handoffs',
 style: TextStyle(fontSize: 12, color: Colors.grey[600])),
 const SizedBox(height: 16),
 _buildCoverageRow(
 'Field Ops', 'Mon - Thu', 'On-site', const Color(0xFF38BDF8)),
 _buildCoverageRow(
 'Compliance', 'Tue - Fri', 'Remote', const Color(0xFF34D399)),
 _buildCoverageRow(
 'Logistics', 'Wed - Sat', 'Hybrid', const Color(0xFFF59E0B)),
 ],
 ),
 );
 }

 Widget _buildCoverageRow(
 String label, String window, String mode, Color color) {
 return Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 children: [
 Container(
 width: 10,
 height: 10,
 decoration: BoxDecoration(color: color, shape: BoxShape.circle),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label,
 style: const TextStyle(
 fontSize: 13, fontWeight: FontWeight.w600)),
 Text(window,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF64748B))),
 ],
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: color.withOpacity(0.12),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Text(mode,
 style: TextStyle(
 fontSize: 11, fontWeight: FontWeight.w600, color: color)),
 ),
 ],
 ),
 );
 }

 Widget _buildTeamManagementPanel() {
 final projectId = _getProjectId();
 return Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Team Roster',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1A1D1F))),
 SizedBox(height: 4),
 Text('Manage disposal team members and assignments',
 style:
 TextStyle(fontSize: 13, color: Color(0xFF64748B))),
 ],
 ),
 ),
 _buildActionButton(Icons.person_add, 'Add Team Member',
 onTap: () {
 _showAddTeamMemberDialog(context);
 }),
 ],
 ),
 const SizedBox(height: 20),
 if (projectId == null)
 const Center(
 child: Padding(
 padding: EdgeInsets.all(20),
 child: Text(
 'No project selected. Please open a project first.',
 style: TextStyle(color: Color(0xFF64748B)),
 ),
 ),
 )
 else
 StreamBuilder<List<SalvageTeamMemberModel>>(
 stream: SalvageService.streamTeamMembers(projectId),
 builder: (context, snapshot) {
 if (snapshot.connectionState == ConnectionState.waiting) {
 return const Center(
 child: Padding(
 padding: EdgeInsets.all(24),
 child: CircularProgressIndicator(),
 ),
 );
 }
 if (snapshot.hasError) {
 return Center(
 child: Padding(
 padding: const EdgeInsets.all(24),
 child: Text(
 'Error loading team members: ${snapshot.error}',
 style: const TextStyle(color: Colors.red),
 ),
 ),
 );
 }

 final members = snapshot.data ?? [];
 if (members.isEmpty) {
 return Center(
 child: Padding(
 padding: const EdgeInsets.all(24),
 child: Column(
 children: [
 const Text(
 'No team members added yet.',
 style: TextStyle(color: Color(0xFF64748B)),
 ),
 const SizedBox(height: 12),
 ElevatedButton.icon(
 onPressed: () => _showAddTeamMemberDialog(context),
 icon: const Icon(Icons.add, size: 18),
 label: const Text('Add First Team Member'),
 ),
 ],
 ),
 ),
 );
 }

 return LayoutBuilder(
 builder: (context, constraints) {
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: ConstrainedBox(
 constraints:
 BoxConstraints(minWidth: constraints.maxWidth),
 child: DataTable(
 headingRowColor:
 WidgetStateProperty.all(const Color(0xFFF8FAFC)),
 columnSpacing: 24,
 horizontalMargin: 16,
 dataRowMinHeight: 56,
 dataRowMaxHeight: 72,
 columns: const [
 DataColumn(
 label: Text('Name',
 style: TextStyle(
 fontWeight: FontWeight.w600))),
 DataColumn(
 label: Text('Role',
 style: TextStyle(
 fontWeight: FontWeight.w600))),
 DataColumn(
 label: Text('Email',
 style: TextStyle(
 fontWeight: FontWeight.w600))),
 DataColumn(
 label: Text('Status',
 style: TextStyle(
 fontWeight: FontWeight.w600))),
 DataColumn(
 label: Text('Items Handled',
 style: TextStyle(
 fontWeight: FontWeight.w600))),
 DataColumn(
 label: Text('Actions',
 style: TextStyle(
 fontWeight: FontWeight.w600))),
 ],
 rows: members.map((member) {
 final statusColor =
 member.status.toLowerCase() == 'active'
 ? Colors.green
 : Colors.orange;
 final initial = member.name.trim().isEmpty
 ? '?'
 : member.name.trim()[0].toUpperCase();
 return DataRow(
 cells: [
 DataCell(
 Row(
 children: [
 CircleAvatar(
 radius: 14,
 backgroundColor: const Color(0xFF0EA5E9)
 .withOpacity(0.1),
 child: Text(
 initial,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF0EA5E9),
 ),
 ),
 ),
 const SizedBox(width: 8),
 Text(member.name,
 style: const TextStyle(fontSize: 13)),
 ],
 ),
 ),
 DataCell(ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 140),
 child: Text(member.role,
 style: const TextStyle(fontSize: 13),
 softWrap: true,
 maxLines: 2,
 overflow: TextOverflow.ellipsis))),
 DataCell(
 Text(
 member.email,
 style: const TextStyle(
 fontSize: 13, color: Color(0xFF64748B)),
 ),
 ),
 DataCell(_buildStatusBadge(
 member.status, statusColor)),
 DataCell(Text('${member.itemsHandled}',
 style: const TextStyle(fontSize: 13))),
 DataCell(
 Row(
 children: [
 IconButton(
 icon: const Icon(Icons.edit, size: 16),
 onPressed: () =>
 _showEditTeamMemberDialog(
 context, member),
 color: const Color(0xFF64748B),
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline,
 size: 16),
 onPressed: () =>
 _showDeleteTeamMemberDialog(
 context, member),
 color: const Color(0xFFEF4444),
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
 ),
 ),
 ],
 );
 }).toList(),
 ),
 ),
 );
 },
 );
 },
 ),
 ],
 ),
 );
 }

 Widget _buildDisposalQueuePanel() {
 final projectId = _getProjectId();
 return Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Disposal Queue',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1A1D1F))),
 SizedBox(height: 4),
 Text('Track assets through the disposal workflow per ITAD / ISO 14001 / NIST SP 800-88 standards',
 style:
 TextStyle(fontSize: 13, color: Color(0xFF64748B))),
 ],
 ),
 ),
 _buildActionButton(Icons.add, 'Add Item', onTap: () {
 _showAddDisposalDialog(context);
 }),
 ],
 ),
 const SizedBox(height: 20),
 if (projectId == null)
 const Center(
 child: Padding(
 padding: EdgeInsets.all(20),
 child: Text(
 'No project selected. Please open a project first.',
 style: TextStyle(color: Color(0xFF64748B)),
 ),
 ),
 )
 else
 StreamBuilder<List<SalvageDisposalItemModel>>(
 stream: SalvageService.streamDisposalItems(projectId),
 builder: (context, snapshot) {
 if (snapshot.connectionState == ConnectionState.waiting) {
 return const Center(
 child: Padding(
 padding: EdgeInsets.all(24),
 child: CircularProgressIndicator(),
 ),
 );
 }
 if (snapshot.hasError) {
 return Center(
 child: Padding(
 padding: const EdgeInsets.all(24),
 child: Text(
 'Error loading disposal queue: ${snapshot.error}',
 style: const TextStyle(color: Colors.red),
 ),
 ),
 );
 }

 final items = snapshot.data ?? [];
 return LayoutBuilder(
 builder: (context, constraints) {
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: ConstrainedBox(
 constraints:
 BoxConstraints(minWidth: constraints.maxWidth),
 child: DataTable(
 headingRowColor:
 WidgetStateProperty.all(const Color(0xFFF1F5F9)),
 headingRowHeight: 32,
 dataRowMinHeight: 28,
 dataRowMaxHeight: 40,
 headingTextStyle: const TextStyle(
 fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569), letterSpacing: 0.3,
 ),
 dataTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
 columnSpacing: 10,
 horizontalMargin: 10,
 columns: const [
 DataColumn(label: Text('Asset ID')),
 DataColumn(label: Text('Description')),
 DataColumn(label: Text('Category')),
 DataColumn(label: Text('Condition')),
 DataColumn(label: Text('Disposal Method')),
 DataColumn(label: Text('Status')),
 DataColumn(label: Text('Priority')),
 DataColumn(label: Text('Est. Value'), numeric: true),
 DataColumn(label: Text('Disp. Cost'), numeric: true),
 DataColumn(label: Text('Assigned To')),
 DataColumn(label: Text('Target Date')),
 DataColumn(label: Text('Location')),
 DataColumn(label: Text('Actions')),
 ],
 rows: items.isEmpty
 ? [
 DataRow(cells: [
 DataCell(Text(
 'No disposal items added yet.',
 style: TextStyle(
 color: const Color(0xFF64748B),
 fontStyle: FontStyle.italic))),
 for (var i = 0; i < 12; i++) const DataCell(SizedBox()),
 ]),
 ]
 : items.map((item) {
 final priorityColor = _priorityColorFor(item.priority);
 return DataRow(
 cells: [
 DataCell(Text(item.assetId,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0EA5E9)))),
 DataCell(ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 160),
 child: Text(item.name,
 style: const TextStyle(fontSize: 12),
 overflow: TextOverflow.ellipsis),
 )),
 DataCell(_buildCategoryChip(item.category)),
 DataCell(_buildConditionChip(item.condition)),
 DataCell(_buildDisposalMethodChip(item.disposalMethod)),
 DataCell(_buildStatusPill(item.status)),
 DataCell(_buildPriorityBadge(item.priority, priorityColor)),
 DataCell(Text(item.estimatedValue,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700))),
 DataCell(Text(item.disposalCost.isNotEmpty ? item.disposalCost : '-',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: item.disposalCost.isNotEmpty ? const Color(0xFFEF4444) : const Color(0xFF94A3B8)))),
 DataCell(Text(item.assignedTo.isNotEmpty ? item.assignedTo : '-',
 style: TextStyle(
 fontSize: 11,
 color: item.assignedTo.isNotEmpty ? const Color(0xFF1E293B) : const Color(0xFF94A3B8)))),
 DataCell(Text(item.targetDate.isNotEmpty ? item.targetDate : '-',
 style: TextStyle(
 fontSize: 11,
 color: item.targetDate.isNotEmpty ? const Color(0xFF1E293B) : const Color(0xFF94A3B8)))),
 DataCell(Text(item.location.isNotEmpty ? item.location : '-',
 style: TextStyle(
 fontSize: 11,
 color: item.location.isNotEmpty ? const Color(0xFF475569) : const Color(0xFF94A3B8)))),
 DataCell(
 Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 icon: const Icon(Icons.edit_outlined, size: 16),
 onPressed: () =>
 _showEditDisposalDialog(context, item),
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 color: const Color(0xFF64748B),
 ),
 IconButton(
 icon: const Icon(Icons.visibility_outlined, size: 16),
 onPressed: () =>
 _showDisposalItemDetailDialog(context, item),
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 color: const Color(0xFF0EA5E9),
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline, size: 16),
 onPressed: () =>
 _showDeleteDisposalDialog(context, item),
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 color: const Color(0xFFEF4444),
 ),
 ],
 ),
 ),
 ],
 );
 }).toList(),
 ),
 ),
 );
 },
 );
 },
 ),
 ],
 ),
 );
 }

 Color _priorityColorFor(String priority) {
 switch (priority.toLowerCase()) {
 case 'critical':
 return const Color(0xFF991B1B);
 case 'high':
 return const Color(0xFFEF4444);
 case 'medium':
 return const Color(0xFFF59E0B);
 case 'low':
 return const Color(0xFF22C55E);
 default:
 return const Color(0xFF64748B);
 }
 }

 Widget _buildConditionChip(String condition) {
 Color bg; Color fg;
 switch (condition.toLowerCase()) {
 case 'excellent':
 bg = const Color(0xFFF0FDF4); fg = const Color(0xFF16A34A); break;
 case 'good':
 bg = const Color(0xFFDBEAFE); fg = const Color(0xFF2563EB); break;
 case 'fair':
 bg = const Color(0xFFFFFBEB); fg = const Color(0xFFD97706); break;
 case 'poor':
 bg = const Color(0xFFFEF2F2); fg = const Color(0xFFDC2626); break;
 case 'non-functional':
 bg = const Color(0xFFF1F5F9); fg = const Color(0xFF64748B); break;
 default:
 bg = const Color(0xFFF1F5F9); fg = const Color(0xFF475569);
 }
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
 child: Text(condition.isNotEmpty ? condition : '-',
 style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
 );
 }

 Widget _buildDisposalMethodChip(String method) {
 Color bg; Color fg; IconData icon;
 switch (method.toLowerCase()) {
 case 'auction':
 bg = const Color(0xFFFDF4FF); fg = const Color(0xFF9333EA); icon = Icons.gavel; break;
 case 'recycle':
 bg = const Color(0xFFF0FDF4); fg = const Color(0xFF16A34A); icon = Icons.recycling; break;
 case 'donate':
 bg = const Color(0xFFEFF6FF); fg = const Color(0xFF2563EB); icon = Icons.volunteer_activism; break;
 case 'scrap':
 bg = const Color(0xFFFEF2F2); fg = const Color(0xFFDC2626); icon = Icons.delete_forever; break;
 case 'resell':
 bg = const Color(0xFFFFFBEB); fg = const Color(0xFFD97706); icon = Icons.sell; break;
 case 'trade-in':
 bg = const Color(0xFFE0F2FE); fg = const Color(0xFF0284C7); icon = Icons.swap_horiz; break;
 case 'transfer':
 bg = const Color(0xFFF1F5F9); fg = const Color(0xFF475569); icon = Icons.forward; break;
 default:
 bg = const Color(0xFFF1F5F9); fg = const Color(0xFF64748B); icon = Icons.help_outline;
 }
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
 child: Row(mainAxisSize: MainAxisSize.min, children: [
 Icon(icon, size: 10, color: fg),
 const SizedBox(width: 3),
 Text(method.isNotEmpty ? method : '-',
 style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
 ]),
 );
 }

 void _showDisposalItemDetailDialog(BuildContext context, SalvageDisposalItemModel item) {
 showDialog(
 context: context,
 barrierDismissible: true,
 builder: (ctx) => LaunchModalShell(
 icon: Icons.inventory_2_outlined,
 accent: const Color(0xFF0EA5E9),
 title: item.name,
 subtitle: 'Disposal item details and audit trail.',
 body: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _detailRow('Asset ID', item.assetId),
 _detailRow('Category', item.category),
 _detailRow('Condition', item.condition.isNotEmpty ? item.condition : 'Not specified'),
 _detailRow('Location', item.location.isNotEmpty ? item.location : 'Not specified'),
 _detailRow('Disposal Method', item.disposalMethod.isNotEmpty ? item.disposalMethod : 'Not specified'),
 _detailRow('Status', item.status),
 _detailRow('Priority', item.priority),
 _detailRow('Estimated Value', item.estimatedValue),
 _detailRow('Disposal Cost', item.disposalCost.isNotEmpty ? item.disposalCost : 'Not specified'),
 _detailRow('Assigned To', item.assignedTo.isNotEmpty ? item.assignedTo : 'Unassigned'),
 _detailRow('Target Date', item.targetDate.isNotEmpty ? item.targetDate : 'Not set'),
 const Divider(height: 24),
 _detailRow('Created By', item.createdByName),
 _detailRow('Created At', _formatDate(item.createdAt)),
 _detailRow('Updated At', _formatDate(item.updatedAt)),
 ],
 ),
 actions: [
 LaunchModalCancelButton(
 label: 'Close',
 onPressed: () => Navigator.pop(ctx),
 ),
 LaunchModalPrimaryButton(
 label: 'Edit',
 icon: Icons.edit_rounded,
 onPressed: () {
 Navigator.pop(ctx);
 _showEditDisposalDialog(context, item);
 },
 ),
 ],
 ),
 );
 }

 Widget _detailRow(String label, String value) {
 return Padding(
 padding: const EdgeInsets.symmetric(vertical: 4),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 SizedBox(
 width: 130,
 child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
 ),
 Expanded(
 child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1E293B))),
 ),
 ],
 ),
 );
 }

 String _formatDate(DateTime dt) {
 return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
 }

 Widget _buildCompliancePanel() {
 final totalRegs = _complianceRows.length;
 final compliantCount = _complianceRows.where((r) => r.complianceStatus == 'Compliant').length;
 final nonCompliantCount = _complianceRows.where((r) => r.complianceStatus == 'Non-Compliant').length;
 final renewalDueCount = _complianceRows.where((r) => r.complianceStatus == 'Renewal Due').length;
 final pendingCount = _complianceRows.where((r) => r.complianceStatus == 'Pending').length;
 final criticalRiskCount = _complianceRows.where((r) => r.riskLevel == 'Critical' || r.riskLevel == 'High').length;
 final avgScore = totalRegs > 0 ? _complianceRows.fold<int>(0, (sum, r) => sum + r.complianceScore) / totalRegs : 0.0;
 final totalFindings = _complianceRows.fold<int>(0, (sum, r) => sum + r.findings);
 final totalCorrective = _complianceRows.fold<int>(0, (sum, r) => sum + r.correctiveActions);
 final expiringSoon = _complianceRows.where((r) => r.daysToExpiry >= 0 && r.daysToExpiry <= 30).length;
 final expired = _complianceRows.where((r) => r.daysToExpiry < 0).length;

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Title
 const Text('Compliance & Regulations',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF1A1D1F))),
 const SizedBox(height: 2),
 Text('Environmental, safety, health, legal, and financial regulatory compliance tracking with audit scheduling, risk flagging, and corrective action management.',
 style: TextStyle(fontSize: 11, color: Colors.grey[600])),
 const SizedBox(height: 10),
 // Summary bar
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Wrap(
 spacing: 20,
 runSpacing: 8,
 alignment: WrapAlignment.start,
 children: [
 _complianceMetric(label: 'Total Regs', value: '$totalRegs', color: const Color(0xFF1E293B)),
 _complianceMetric(label: 'Compliant', value: '$compliantCount', color: const Color(0xFF22C55E)),
 _complianceMetric(label: 'Non-Compliant', value: '$nonCompliantCount', color: const Color(0xFFEF4444)),
 _complianceMetric(label: 'Renewal Due', value: '$renewalDueCount', color: const Color(0xFFF59E0B)),
 _complianceMetric(label: 'Pending', value: '$pendingCount', color: const Color(0xFF0EA5E9)),
 _complianceMetric(label: 'Avg Score', value: '${avgScore.toStringAsFixed(0)}%', color: const Color(0xFF7C3AED)),
 _complianceMetric(label: 'Open Findings', value: '$totalFindings', color: const Color(0xFFEA580C)),
 _complianceMetric(label: 'Corrective Actions', value: '$totalCorrective', color: const Color(0xFF0284C7)),
 _complianceMetric(label: 'Critical/High Risk', value: '$criticalRiskCount', color: const Color(0xFFEF4444)),
 _complianceMetric(label: 'Expiring Soon', value: '$expiringSoon', color: const Color(0xFFF59E0B)),
 if (expired > 0) _complianceMetric(label: 'Expired', value: '$expired', color: const Color(0xFFDC2626)),
 const SizedBox(width: 8),
 FilledButton.icon(
 onPressed: () => _showComplianceRegulationDialog(context),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add Regulation'),
 style: FilledButton.styleFrom(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 backgroundColor: const Color(0xFF0EA5E9),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 10),
 // Alert banners
 if (nonCompliantCount > 0 || expired > 0)
 Container(
 margin: const EdgeInsets.only(bottom: 10),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 color: const Color(0xFFFEF2F2),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: const Color(0xFFFECACA)),
 ),
 child: Row(
 children: [
 const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 '$nonCompliantCount non-compliant regulation(s) and $expired expired. Immediate corrective action required.',
 style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
 ),
 ),
 ],
 ),
 ),
 if (renewalDueCount > 0 || expiringSoon > 0)
 Container(
 margin: const EdgeInsets.only(bottom: 10),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 color: const Color(0xFFFFFBEB),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: const Color(0xFFFDE68A)),
 ),
 child: Row(
 children: [
 const Icon(Icons.warning_amber, size: 16, color: Color(0xFFD97706)),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 '$renewalDueCount renewal(s) due and $expiringSoon regulation(s) expiring within 30 days. Schedule renewals promptly.',
 style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
 ),
 ),
 ],
 ),
 ),
 // Full-width DataTable
 if (_isLoadingCompliance)
 const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
 else
 LayoutBuilder(
 builder: (context, constraints) {
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: ConstrainedBox(
 constraints: BoxConstraints(minWidth: constraints.maxWidth),
 child: DataTable(
 headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
 headingRowHeight: 36,
 dataRowMinHeight: 32,
 dataRowMaxHeight: 48,
 headingTextStyle: const TextStyle(
 fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569), letterSpacing: 0.4,
 ),
 dataTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
 columnSpacing: 16,
 horizontalMargin: 12,
 columns: const [
 DataColumn(label: Text('Regulation/Standard')),
 DataColumn(label: Text('Category')),
 DataColumn(label: Text('Status')),
 DataColumn(label: Text('Score %'), numeric: true),
 DataColumn(label: Text('Last Audit')),
 DataColumn(label: Text('Next Audit')),
 DataColumn(label: Text('Days to Exp.'), numeric: true),
 DataColumn(label: Text('Responsible')),
 DataColumn(label: Text('Risk')),
 DataColumn(label: Text('Findings'), numeric: true),
 DataColumn(label: Text('Corr. Actions'), numeric: true),
 DataColumn(label: Text('Priority')),
 DataColumn(label: Text('Workflow')),
 DataColumn(label: Text('Updated')),
 DataColumn(label: Text('Actions')),
 ],
 rows: _complianceRows.asMap().entries.map((entry) {
 final idx = entry.key;
 final row = entry.value;
 return DataRow(cells: [
 DataCell(Text(row.regulation, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
 DataCell(_buildComplianceCategoryChip(row.category)),
 DataCell(_buildComplianceStatusChip(row.complianceStatus)),
 DataCell(Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 SizedBox(
 width: 36,
 child: ClipRRect(
 borderRadius: BorderRadius.circular(3),
 child: LinearProgressIndicator(
 value: row.complianceScore / 100,
 backgroundColor: const Color(0xFFE2E8F0),
 valueColor: AlwaysStoppedAnimation(
 row.complianceScore >= 90 ? const Color(0xFF22C55E) :
 row.complianceScore >= 70 ? const Color(0xFF2563EB) :
 row.complianceScore >= 50 ? const Color(0xFFF59E0B) :
 const Color(0xFFEF4444),
 ),
 minHeight: 4,
 ),
 ),
 ),
 const SizedBox(width: 4),
 Text('${row.complianceScore}', style: TextStyle(
 fontWeight: FontWeight.w700, fontSize: 11,
 color: row.complianceScore >= 90 ? const Color(0xFF22C55E) :
 row.complianceScore >= 70 ? const Color(0xFF2563EB) :
 row.complianceScore >= 50 ? const Color(0xFFF59E0B) :
 const Color(0xFFEF4444),
 )),
 ],
 )),
 DataCell(Text(row.lastAuditDate, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)))),
 DataCell(Text(row.nextAuditDue, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)))),
 DataCell(Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(
 color: row.daysToExpiry < 0 ? const Color(0xFFFEF2F2) :
 row.daysToExpiry <= 14 ? const Color(0xFFFFFBEB) :
 row.daysToExpiry <= 30 ? const Color(0xFFFFFBEB) :
 const Color(0xFFF0FDF4),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(
 row.daysToExpiry < 0 ? '${row.daysToExpiry}d (EXPIRED)' :
 row.daysToExpiry <= 14 ? '${row.daysToExpiry}d' :
 '${row.daysToExpiry}d',
 style: TextStyle(
 fontWeight: FontWeight.w700, fontSize: 10,
 color: row.daysToExpiry < 0 ? const Color(0xFFDC2626) :
 row.daysToExpiry <= 14 ? const Color(0xFFD97706) :
 row.daysToExpiry <= 30 ? const Color(0xFFF59E0B) :
 const Color(0xFF22C55E),
 ),
 ),
 )),
 DataCell(Text(row.responsibleParty, style: const TextStyle(fontSize: 10))),
 DataCell(_buildComplianceRiskChip(row.riskLevel)),
 DataCell(Text('${row.findings}', style: TextStyle(
 fontWeight: FontWeight.w700,
 color: row.findings > 5 ? const Color(0xFFEF4444) :
 row.findings > 0 ? const Color(0xFFF59E0B) :
 const Color(0xFF22C55E),
 ))),
 DataCell(Text('${row.correctiveActions}', style: TextStyle(
 fontWeight: FontWeight.w700,
 color: row.correctiveActions > 3 ? const Color(0xFFEF4444) :
 row.correctiveActions > 0 ? const Color(0xFF2563EB) :
 const Color(0xFF22C55E),
 ))),
 DataCell(_buildCompliancePriorityChip(row.priority)),
 DataCell(_buildComplianceWorkflowChip(row.status)),
 DataCell(Text(row.lastUpdated, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)))),
 DataCell(Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 icon: const Icon(Icons.edit_outlined, size: 14),
 onPressed: () => _showComplianceRegulationDialog(context, editIndex: idx),
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 color: const Color(0xFF64748B),
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline, size: 14),
 onPressed: () => _deleteComplianceRow(idx),
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 color: const Color(0xFFEF4444),
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
 )),
 ]);
 }).toList(),
 ),
 ),
 );
 },
 ),
 ],
 ),
 );
 }

 Widget _complianceMetric({required String label, required String value, required Color color}) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color, fontFeatures: const [FontFeature.tabularFigures()])),
 Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8))),
 ],
 );
 }

 Widget _buildComplianceCategoryChip(String category) {
 Color bg; Color fg;
 switch (category.toLowerCase()) {
 case 'environmental':
 bg = const Color(0xFFF0FDF4); fg = const Color(0xFF16A34A); break;
 case 'safety':
 bg = const Color(0xFFFEF2F2); fg = const Color(0xFFDC2626); break;
 case 'health':
 bg = const Color(0xFFEFF6FF); fg = const Color(0xFF2563EB); break;
 case 'legal':
 bg = const Color(0xFFF5F3FF); fg = const Color(0xFF7C3AED); break;
 case 'financial':
 bg = const Color(0xFFFFFBEB); fg = const Color(0xFFD97706); break;
 case 'quality':
 bg = const Color(0xFFF0F9FF); fg = const Color(0xFF0284C7); break;
 default:
 bg = const Color(0xFFF1F5F9); fg = const Color(0xFF475569);
 }
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
 child: Text(category, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
 );
 }

 Widget _buildComplianceStatusChip(String status) {
 Color bg; Color fg;
 switch (status.toLowerCase()) {
 case 'compliant':
 bg = const Color(0xFFF0FDF4); fg = const Color(0xFF16A34A); break;
 case 'non-compliant':
 bg = const Color(0xFFFEF2F2); fg = const Color(0xFFDC2626); break;
 case 'conditional':
 bg = const Color(0xFFFFFBEB); fg = const Color(0xFFD97706); break;
 case 'renewal due':
 bg = const Color(0xFFFFFBEB); fg = const Color(0xFFEA580C); break;
 case 'pending':
 bg = const Color(0xFFEFF6FF); fg = const Color(0xFF2563EB); break;
 case 'expired':
 bg = const Color(0xFFFEF2F2); fg = const Color(0xFF991B1B); break;
 default:
 bg = const Color(0xFFF1F5F9); fg = const Color(0xFF475569);
 }
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
 child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
 );
 }

 Widget _buildComplianceRiskChip(String risk) {
 Color bg; Color fg;
 switch (risk.toLowerCase()) {
 case 'critical':
 bg = const Color(0xFFFEF2F2); fg = const Color(0xFF991B1B); break;
 case 'high':
 bg = const Color(0xFFFEF2F2); fg = const Color(0xFFDC2626); break;
 case 'medium':
 bg = const Color(0xFFFFFBEB); fg = const Color(0xFFD97706); break;
 case 'low':
 bg = const Color(0xFFF0FDF4); fg = const Color(0xFF16A34A); break;
 default:
 bg = const Color(0xFFF1F5F9); fg = const Color(0xFF475569);
 }
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
 child: Text(risk, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
 );
 }

 Widget _buildCompliancePriorityChip(String priority) {
 Color bg; Color fg;
 switch (priority.toUpperCase()) {
 case 'P1':
 bg = const Color(0xFFFEF2F2); fg = const Color(0xFFDC2626); break;
 case 'P2':
 bg = const Color(0xFFFFFBEB); fg = const Color(0xFFD97706); break;
 case 'P3':
 bg = const Color(0xFFF0FDF4); fg = const Color(0xFF16A34A); break;
 case 'P4':
 bg = const Color(0xFFF1F5F9); fg = const Color(0xFF64748B); break;
 default:
 bg = const Color(0xFFF1F5F9); fg = const Color(0xFF475569);
 }
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
 child: Text(priority, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg)),
 );
 }

 Widget _buildComplianceWorkflowChip(String status) {
 Color bg; Color fg;
 switch (status.toLowerCase()) {
 case 'active':
 bg = const Color(0xFFF0FDF4); fg = const Color(0xFF16A34A); break;
 case 'under review':
 bg = const Color(0xFFFFFBEB); fg = const Color(0xFFD97706); break;
 case 'closed':
 bg = const Color(0xFFF1F5F9); fg = const Color(0xFF64748B); break;
 default:
 bg = const Color(0xFFF1F5F9); fg = const Color(0xFF475569);
 }
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
 child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
 );
 }

 // ── Compliance & Regulations CRUD ──────────────────────────────────

 void _showComplianceRegulationDialog(BuildContext context, {int? editIndex}) {
 final isEdit = editIndex != null;
 final existing = isEdit ? _complianceRows[editIndex] : null;
 final regulationCtrl = TextEditingController(text: existing?.regulation ?? '');
 final lastAuditCtrl = TextEditingController(text: existing?.lastAuditDate ?? '');
 final nextAuditCtrl = TextEditingController(text: existing?.nextAuditDue ?? '');
 final daysToExpiryCtrl = TextEditingController(text: existing != null ? '${existing.daysToExpiry}' : '90');
 final responsibleCtrl = TextEditingController(text: existing?.responsibleParty ?? '');
 final findingsCtrl = TextEditingController(text: existing != null ? '${existing.findings}' : '0');
 final correctiveCtrl = TextEditingController(text: existing != null ? '${existing.correctiveActions}' : '0');
 final scoreCtrl = TextEditingController(text: existing != null ? '${existing.complianceScore}' : '100');
 final lastUpdatedCtrl = TextEditingController(text: existing?.lastUpdated ?? 'Just now');
 String category = existing?.category ?? 'Environmental';
 String complianceStatus = existing?.complianceStatus ?? 'Compliant';
 String riskLevel = existing?.riskLevel ?? 'Low';
 String priority = existing?.priority ?? 'P3';
 String status = existing?.status ?? 'Active';

 showDialog(
 context: context,
 barrierDismissible: true,
 builder: (ctx) => StatefulBuilder(
 builder: (ctx, setDialogState) => LaunchModalShell(
 icon: isEdit ? Icons.edit_rounded : Icons.gavel_rounded,
 accent: const Color(0xFF0EA5E9),
 title: isEdit ? 'Edit Regulation' : 'Add Regulation',
 subtitle: isEdit
 ? 'Update the compliance regulation record.'
 : 'Capture a regulatory compliance requirement for tracking.',
 body: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 LaunchModalTextField(
 label: 'Regulation / Standard',
 controller: regulationCtrl,
 hint: 'e.g. EPA Hazardous Waste Rule',
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalDropdown<String>(
 label: 'Category',
 value: category,
 items: const ['Environmental', 'Safety', 'Health', 'Legal', 'Financial', 'Quality'],
 onChanged: (v) => setDialogState(() => category = v ?? 'Environmental'),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalDropdown<String>(
 label: 'Compliance Status',
 value: complianceStatus,
 items: const ['Compliant', 'Non-Compliant', 'Conditional', 'Renewal Due', 'Pending', 'Expired'],
 onChanged: (v) => setDialogState(() => complianceStatus = v ?? 'Compliant'),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalTextField(
 label: 'Compliance Score %',
 controller: scoreCtrl,
 hint: '0–100',
 keyboardType: TextInputType.number,
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalTextField(
 label: 'Days to Expiry',
 controller: daysToExpiryCtrl,
 hint: 'e.g. 90',
 keyboardType: TextInputType.number,
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalTextField(
 label: 'Last Audit Date',
 controller: lastAuditCtrl,
 hint: 'e.g. 2025-01-15',
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalTextField(
 label: 'Next Audit Due',
 controller: nextAuditCtrl,
 hint: 'e.g. 2026-01-15',
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 LaunchModalTextField(
 label: 'Responsible Party',
 controller: responsibleCtrl,
 hint: 'Person or team accountable',
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalDropdown<String>(
 label: 'Risk Level',
 value: riskLevel,
 items: const ['Critical', 'High', 'Medium', 'Low'],
 onChanged: (v) => setDialogState(() => riskLevel = v ?? 'Low'),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalDropdown<String>(
 label: 'Priority',
 value: priority,
 items: const ['P1', 'P2', 'P3', 'P4'],
 onChanged: (v) => setDialogState(() => priority = v ?? 'P3'),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalDropdown<String>(
 label: 'Workflow',
 value: status,
 items: const ['Active', 'Under Review', 'Closed'],
 onChanged: (v) => setDialogState(() => status = v ?? 'Active'),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalTextField(
 label: 'Open Findings',
 controller: findingsCtrl,
 hint: '0',
 keyboardType: TextInputType.number,
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalTextField(
 label: 'Corrective Actions',
 controller: correctiveCtrl,
 hint: '0',
 keyboardType: TextInputType.number,
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalTextField(
 label: 'Last Updated',
 controller: lastUpdatedCtrl,
 hint: 'Just now',
 ),
 ),
 ],
 ),
 ],
 ),
 actions: [
 LaunchModalCancelButton(
 label: 'Cancel',
 onPressed: () => Navigator.pop(ctx),
 ),
 LaunchModalPrimaryButton(
 label: isEdit ? 'Update' : 'Add Regulation',
 icon: isEdit ? Icons.check_rounded : Icons.add_rounded,
 onPressed: () {
 final row = _ComplianceRegulationRow(
 regulation: regulationCtrl.text.trim(),
 category: category,
 complianceStatus: complianceStatus,
 complianceScore: int.tryParse(scoreCtrl.text) ?? 0,
 lastAuditDate: lastAuditCtrl.text.trim(),
 nextAuditDue: nextAuditCtrl.text.trim(),
 daysToExpiry: int.tryParse(daysToExpiryCtrl.text) ?? 0,
 responsibleParty: responsibleCtrl.text.trim(),
 riskLevel: riskLevel,
 findings: int.tryParse(findingsCtrl.text) ?? 0,
 correctiveActions: int.tryParse(correctiveCtrl.text) ?? 0,
 priority: priority,
 status: status,
 lastUpdated: lastUpdatedCtrl.text.trim().isNotEmpty ? lastUpdatedCtrl.text.trim() : 'Just now',
 );
 setState(() {
 if (isEdit) {
 _complianceRows[editIndex] = row;
 } else {
 _complianceRows.add(row);
 }
 });
 _saveComplianceToFirestore();
 Navigator.pop(ctx);
 ScaffoldMessenger.of(context).showSnackBar(SnackBar(
 content: Text(isEdit ? 'Regulation updated successfully.' : 'Regulation added successfully.'),
 backgroundColor: const Color(0xFF0EA5E9),
 behavior: SnackBarBehavior.floating,
 ));
 },
 ),
 ],
 ),
 ),
 );
 }

 void _deleteComplianceRow(int index) {
 showDialog(
 context: context,
 barrierDismissible: true,
 builder: (ctx) => LaunchModalShell(
 icon: Icons.delete_outline_rounded,
 accent: const Color(0xFFEF4444),
 title: 'Delete Regulation',
 subtitle: 'This action cannot be undone.',
 body: Text(
 'Are you sure you want to delete "${_complianceRows[index].regulation}"? '
 'Once removed, the regulation record cannot be recovered.',
 style: const TextStyle(
 fontSize: 14,
 color: Color(0xFF4B5563),
 height: 1.5,
 ),
 ),
 actions: [
 LaunchModalCancelButton(
 label: 'Cancel',
 onPressed: () => Navigator.pop(ctx),
 ),
 LaunchModalDangerButton(
 label: 'Delete',
 onPressed: () {
 setState(() => _complianceRows.removeAt(index));
 _saveComplianceToFirestore();
 Navigator.pop(ctx);
 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
 content: Text('Regulation deleted.'),
 backgroundColor: Color(0xFFEF4444),
 behavior: SnackBarBehavior.floating,
 ));
 },
 ),
 ],
 ),
 );
 }

 Widget _buildTimelinePanel() {
 final projectId = _getProjectId();
 return Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Disposal Timeline',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1A1D1F))),
 SizedBox(height: 4),
 Text('Milestone tracking with phases, ownership, and progress per project management standards',
 style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
 ],
 ),
 ),
 _buildActionButton(Icons.add, 'Add Milestone', onTap: () {
 _showAddTimelineDialog(context);
 }),
 ],
 ),
 const SizedBox(height: 20),
 if (projectId == null)
 const Center(
 child: Padding(
 padding: EdgeInsets.all(20),
 child: Text(
 'No project selected. Please open a project first.',
 style: TextStyle(color: Color(0xFF64748B)),
 ),
 ),
 )
 else
 StreamBuilder<List<SalvageTimelineItemModel>>(
 stream: SalvageService.streamTimelineItems(projectId),
 builder: (context, snapshot) {
 if (snapshot.connectionState == ConnectionState.waiting) {
 return const Center(
 child: Padding(
 padding: EdgeInsets.all(24),
 child: CircularProgressIndicator(),
 ),
 );
 }
 if (snapshot.hasError) {
 return Center(
 child: Padding(
 padding: const EdgeInsets.all(24),
 child: Text(
 'Error loading timeline: ${snapshot.error}',
 style: const TextStyle(color: Colors.red),
 ),
 ),
 );
 }

 final items = snapshot.data ?? [];
 // If no data in Firestore, show the default timeline as a visual fallback
 if (items.isEmpty) {
 return _buildDefaultTimelineFallback();
 }

 return LayoutBuilder(
 builder: (context, constraints) {
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: ConstrainedBox(
 constraints: BoxConstraints(minWidth: constraints.maxWidth),
 child: DataTable(
 headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
 headingRowHeight: 32,
 dataRowMinHeight: 28,
 dataRowMaxHeight: 40,
 headingTextStyle: const TextStyle(
 fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569), letterSpacing: 0.3,
 ),
 dataTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
 columnSpacing: 10,
 horizontalMargin: 10,
 columns: const [
 DataColumn(label: Text('Milestone')),
 DataColumn(label: Text('Description')),
 DataColumn(label: Text('Phase')),
 DataColumn(label: Text('Status')),
 DataColumn(label: Text('Owner')),
 DataColumn(label: Text('Start Date')),
 DataColumn(label: Text('Due Date')),
 DataColumn(label: Text('Progress'), numeric: true),
 DataColumn(label: Text('Priority')),
 DataColumn(label: Text('Dependencies')),
 DataColumn(label: Text('Notes')),
 DataColumn(label: Text('Actions')),
 ],
 rows: items.map((item) {
 return DataRow(cells: [
 DataCell(Text(item.milestone,
 style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
 DataCell(ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 140),
 child: Text(item.description.isNotEmpty ? item.description : '-',
 style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
 overflow: TextOverflow.ellipsis),
 )),
 DataCell(_buildPhaseChip(item.phase)),
 DataCell(_buildTimelineStatusChip(item.status)),
 DataCell(Text(item.owner.isNotEmpty ? item.owner : '-',
 style: TextStyle(fontSize: 11,
 color: item.owner.isNotEmpty ? const Color(0xFF1E293B) : const Color(0xFF94A3B8)))),
 DataCell(Text(item.startDate.isNotEmpty ? item.startDate : '-',
 style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
 DataCell(Text(item.dueDate.isNotEmpty ? item.dueDate : '-',
 style: TextStyle(fontSize: 11,
 color: _isOverdue(item.dueDate, item.status) ? const Color(0xFFEF4444) : const Color(0xFF64748B)))),
 DataCell(Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 SizedBox(
 width: 40,
 child: ClipRRect(
 borderRadius: BorderRadius.circular(3),
 child: LinearProgressIndicator(
 value: item.progress / 100,
 backgroundColor: const Color(0xFFE2E8F0),
 valueColor: AlwaysStoppedAnimation(
 item.progress >= 100 ? const Color(0xFF22C55E) :
 item.progress >= 50 ? const Color(0xFF2563EB) :
 const Color(0xFFF59E0B),
 ),
 minHeight: 4,
 ),
 ),
 ),
 const SizedBox(width: 4),
 Text('${item.progress}%',
 style: TextStyle(
 fontWeight: FontWeight.w700, fontSize: 10,
 color: item.progress >= 100 ? const Color(0xFF22C55E) :
 item.progress >= 50 ? const Color(0xFF2563EB) :
 const Color(0xFFF59E0B),
 )),
 ],
 )),
 DataCell(_buildPriorityBadge(item.priority, _priorityColorFor(item.priority))),
 DataCell(ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 100),
 child: Text(item.dependencies.isNotEmpty ? item.dependencies : '-',
 style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
 overflow: TextOverflow.ellipsis),
 )),
 DataCell(ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 100),
 child: Text(item.notes.isNotEmpty ? item.notes : '-',
 style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
 overflow: TextOverflow.ellipsis),
 )),
 DataCell(Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 icon: const Icon(Icons.edit_outlined, size: 14),
 onPressed: () => _showEditTimelineDialog(context, item),
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 color: const Color(0xFF64748B),
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline, size: 14),
 onPressed: () => _showDeleteTimelineDialog(context, item),
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 color: const Color(0xFFEF4444),
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
 )),
 ]);
 }).toList(),
 ),
 ),
 );
 },
 );
 },
 ),
 ],
 ),
 );
 }

 /// Fallback timeline when no Firestore data exists yet
 Widget _buildDefaultTimelineFallback() {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 color: const Color(0xFFFFFBEB),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: const Color(0xFFFDE68A)),
 ),
 child: Row(
 children: [
 const Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
 const SizedBox(width: 8),
 Expanded(
 child: Text('No timeline milestones have been created yet. Click "Add Milestone" to create your first disposal milestone, or the default milestones will be shown below.',
 style: TextStyle(fontSize: 12, color: Colors.amber[800])),
 ),
 ],
 ),
 ),
 const SizedBox(height: 16),
 _buildDefaultTimelineItem('Asset Audit Complete', 'Mar 15', true),
 _buildDefaultTimelineItem('Vendor Bidding Opens', 'Mar 20', true),
 _buildDefaultTimelineItem('Auction Date', 'Mar 28', false),
 _buildDefaultTimelineItem('Final Disposal Report', 'Apr 5', false),
 _buildDefaultTimelineItem('Project Closure', 'Apr 15', false),
 ],
 );
 }

 Widget _buildDefaultTimelineItem(String label, String date, bool completed) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 16),
 child: Row(
 children: [
 Container(
 width: 24,
 height: 24,
 decoration: BoxDecoration(
 color: completed ? Colors.green : const Color(0xFFE2E8F0),
 shape: BoxShape.circle,
 ),
 child: Icon(
 completed ? Icons.check : Icons.circle,
 size: 14,
 color: completed ? Colors.white : const Color(0xFF94A3B8),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label,
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: completed
 ? const Color(0xFF64748B)
 : const Color(0xFF1A1D1F))),
 Text(date,
 style: TextStyle(fontSize: 11, color: Colors.grey[500])),
 ],
 ),
 ),
 if (!completed)
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(
 color: const Color(0xFFE0F2FE),
 borderRadius: BorderRadius.circular(4),
 ),
 child: const Text('Upcoming',
 style: TextStyle(fontSize: 10, color: Color(0xFF0284C7))),
 ),
 ],
 ),
 );
 }

 bool _isOverdue(String dueDate, String status) {
 if (dueDate.isEmpty || status == 'Completed') return false;
 try {
 final parsed = DateTime.tryParse(dueDate);
 if (parsed == null) return false;
 return parsed.isBefore(DateTime.now());
 } catch (e) {
 return false;
 }
 }

 Widget _buildPhaseChip(String phase) {
 Color bg; Color fg;
 switch (phase.toLowerCase()) {
 case 'planning':
 bg = const Color(0xFFEFF6FF); fg = const Color(0xFF2563EB); break;
 case 'execution':
 bg = const Color(0xFFFFFBEB); fg = const Color(0xFFD97706); break;
 case 'review':
 bg = const Color(0xFFF5F3FF); fg = const Color(0xFF7C3AED); break;
 case 'closure':
 bg = const Color(0xFFF0FDF4); fg = const Color(0xFF16A34A); break;
 default:
 bg = const Color(0xFFF1F5F9); fg = const Color(0xFF475569);
 }
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
 child: Text(phase, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
 );
 }

 Widget _buildTimelineStatusChip(String status) {
 Color bg; Color fg;
 switch (status.toLowerCase()) {
 case 'completed':
 bg = const Color(0xFFF0FDF4); fg = const Color(0xFF16A34A); break;
 case 'in progress':
 bg = const Color(0xFFDBEAFE); fg = const Color(0xFF2563EB); break;
 case 'overdue':
 bg = const Color(0xFFFEF2F2); fg = const Color(0xFFDC2626); break;
 case 'on hold':
 bg = const Color(0xFFFFFBEB); fg = const Color(0xFFD97706); break;
 case 'not started':
 bg = const Color(0xFFF1F5F9); fg = const Color(0xFF64748B); break;
 default:
 bg = const Color(0xFFF1F5F9); fg = const Color(0xFF475569);
 }
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
 child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
 );
 }

 // ── Timeline CRUD Dialogs ──────────────────────────────────

 void _showAddTimelineDialog(BuildContext context) {
 _showTimelineDialog(context, null);
 }

 void _showEditTimelineDialog(BuildContext context, SalvageTimelineItemModel item) {
 _showTimelineDialog(context, item);
 }

 void _showTimelineDialog(BuildContext context, SalvageTimelineItemModel? item) {
 final projectId = _getProjectId();
 if (projectId == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('No project selected. Please open a project first.')),
 );
 return;
 }

 final isEdit = item != null;
 final milestoneController = TextEditingController(text: item?.milestone ?? '');
 final descriptionController = TextEditingController(text: item?.description ?? '');
 final ownerController = TextEditingController(text: item?.owner ?? '');
 final startDateController = TextEditingController(text: item?.startDate ?? '');
 final dueDateController = TextEditingController(text: item?.dueDate ?? '');
 final dependenciesController = TextEditingController(text: item?.dependencies ?? '');
 final notesController = TextEditingController(text: item?.notes ?? '');
 var selectedPhase = item?.phase ?? 'Planning';
 var selectedStatus = item?.status ?? 'Not Started';
 var selectedPriority = item?.priority ?? 'Medium';
 var progressValue = item?.progress ?? 0;

 showDialog<void>(
 context: context,
 barrierDismissible: true,
 builder: (dialogContext) => StatefulBuilder(
 builder: (dialogContext, setDialogState) => LaunchModalShell(
 icon: isEdit ? Icons.edit_rounded : Icons.flag_rounded,
 accent: const Color(0xFF0EA5E9),
 title: isEdit ? 'Edit Milestone' : 'Add Milestone',
 subtitle: isEdit
 ? 'Update the disposal timeline milestone.'
 : 'Plan a new milestone on the disposal timeline.',
 body: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 flex: 2,
 child: LaunchModalTextField(
 label: 'Milestone *',
 controller: milestoneController,
 hint: 'e.g. Asset Disposal Kickoff',
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 flex: 3,
 child: LaunchModalTextField(
 label: 'Description',
 controller: descriptionController,
 hint: 'What this milestone covers',
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalDropdown<String>(
 label: 'Phase',
 value: selectedPhase,
 items: const ['Planning', 'Execution', 'Review', 'Closure'],
 onChanged: (v) {
 if (v != null) setDialogState(() => selectedPhase = v);
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalDropdown<String>(
 label: 'Status',
 value: selectedStatus,
 items: const ['Not Started', 'In Progress', 'Completed', 'Overdue', 'On Hold'],
 onChanged: (v) {
 if (v != null) setDialogState(() => selectedStatus = v);
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalTextField(
 label: 'Owner / Responsible',
 controller: ownerController,
 hint: 'Person accountable',
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalDropdown<String>(
 label: 'Priority',
 value: selectedPriority,
 items: const ['Critical', 'High', 'Medium', 'Low'],
 onChanged: (v) {
 if (v != null) setDialogState(() => selectedPriority = v);
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalTextField(
 label: 'Start Date',
 controller: startDateController,
 hint: 'e.g. 2026-05-01',
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalTextField(
 label: 'Due Date',
 controller: dueDateController,
 hint: 'e.g. 2026-06-15',
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 Row(
 children: [
 const LaunchModalLabel('Progress'),
 const Spacer(),
 Text(
 '$progressValue%',
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF1A1D1F),
 ),
 ),
 ],
 ),
 Slider(
 value: progressValue.toDouble(),
 min: 0,
 max: 100,
 divisions: 20,
 label: '$progressValue%',
 activeColor: const Color(0xFFFFC107),
 onChanged: (v) => setDialogState(() => progressValue = v.round()),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalTextField(
 label: 'Dependencies',
 controller: dependenciesController,
 hint: 'e.g. Milestone A, B',
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalTextField(
 label: 'Notes',
 controller: notesController,
 hint: 'Optional context',
 ),
 ),
 ],
 ),
 ],
 ),
 actions: [
 LaunchModalCancelButton(
 label: 'Cancel',
 onPressed: () => Navigator.of(dialogContext).pop(),
 ),
 LaunchModalPrimaryButton(
 label: isEdit ? 'Update' : 'Add Milestone',
 icon: isEdit ? Icons.check_rounded : Icons.add_rounded,
 onPressed: () async {
 if (milestoneController.text.trim().isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Milestone name is required.')),
 );
 return;
 }

 try {
 if (isEdit) {
 await SalvageService.updateTimelineItem(
 projectId: projectId,
 itemId: item.id,
 milestone: milestoneController.text.trim(),
 description: descriptionController.text.trim(),
 phase: selectedPhase,
 status: selectedStatus,
 owner: ownerController.text.trim(),
 startDate: startDateController.text.trim(),
 dueDate: dueDateController.text.trim(),
 progress: progressValue,
 priority: selectedPriority,
 dependencies: dependenciesController.text.trim(),
 notes: notesController.text.trim(),
 );
 } else {
 await SalvageService.createTimelineItem(
 projectId: projectId,
 milestone: milestoneController.text.trim(),
 description: descriptionController.text.trim(),
 phase: selectedPhase,
 status: selectedStatus,
 owner: ownerController.text.trim(),
 startDate: startDateController.text.trim(),
 dueDate: dueDateController.text.trim(),
 progress: progressValue,
 priority: selectedPriority,
 dependencies: dependenciesController.text.trim(),
 notes: notesController.text.trim(),
 );
 }
 if (!context.mounted) return;
 Navigator.of(dialogContext).pop();
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(isEdit ? 'Milestone updated successfully.' : 'Milestone added successfully.'),
 backgroundColor: const Color(0xFF0EA5E9),
 behavior: SnackBarBehavior.floating,
 ),
 );
 } catch (e) {
 if (!context.mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error: $e')),
 );
 }
 },
 ),
 ],
 ),
 ),
 );
 }

 void _showDeleteTimelineDialog(BuildContext context, SalvageTimelineItemModel item) {
 final projectId = _getProjectId();
 if (projectId == null) return;

 showDialog<void>(
 context: context,
 barrierDismissible: true,
 builder: (dialogContext) => LaunchModalShell(
 icon: Icons.delete_outline_rounded,
 accent: const Color(0xFFEF4444),
 title: 'Delete Milestone',
 subtitle: 'This action cannot be undone.',
 body: Text(
 'Are you sure you want to delete "${item.milestone}"? '
 'Once removed, the milestone record cannot be recovered.',
 style: const TextStyle(
 fontSize: 14,
 color: Color(0xFF4B5563),
 height: 1.5,
 ),
 ),
 actions: [
 LaunchModalCancelButton(
 label: 'Cancel',
 onPressed: () => Navigator.of(dialogContext).pop(),
 ),
 LaunchModalDangerButton(
 label: 'Delete',
 onPressed: () async {
 try {
 await SalvageService.deleteTimelineItem(
 projectId: projectId,
 itemId: item.id,
 );
 if (!context.mounted) return;
 Navigator.of(dialogContext).pop();
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Milestone deleted.'),
 backgroundColor: Color(0xFFEF4444),
 behavior: SnackBarBehavior.floating,
 ),
 );
 } catch (e) {
 if (!context.mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error deleting milestone: $e')),
 );
 }
 },
 ),
 ],
 ),
 );
 }

 Widget _buildInsightsRow(bool isNarrow) {
 final insights = [
 _InsightCard(
 'Cost Recovery Potential',
 '\$58,200',
 'Based on current market valuations for salvageable assets.',
 Icons.trending_up,
 Colors.green),
 _InsightCard(
 'Environmental Impact',
 '12.5 tons',
 'CO2 emissions avoided through proper recycling.',
 Icons.eco,
 Colors.teal),
 _InsightCard('Average Disposal Time', '18 days',
 '23% faster than industry benchmark.', Icons.speed, Colors.blue),
 ];

 if (isNarrow) {
 return Column(
 children: insights
 .map((insight) => Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: _buildInsightCard(insight),
 ))
 .toList(),
 );
 }

 return Row(
 children: insights
 .map((insight) => Expanded(
 child: Padding(
 padding: const EdgeInsets.only(right: 16),
 child: _buildInsightCard(insight),
 ),
 ))
 .toList(),
 );
 }

 Widget _buildInsightCard(_InsightCard insight) {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: insight.color.withOpacity(0.1),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Icon(insight.icon, size: 18, color: insight.color),
 ),
 const Spacer(),
 Icon(Icons.info_outline, size: 16, color: Colors.grey[400]),
 ],
 ),
 const SizedBox(height: 12),
 Text(insight.title,
 style: TextStyle(fontSize: 13, color: Colors.grey[600])),
 const SizedBox(height: 4),
 Text(insight.value,
 style: TextStyle(
 fontSize: 22,
 fontWeight: FontWeight.w700,
 color: insight.color)),
 const SizedBox(height: 8),
 Text(insight.description,
 style: TextStyle(fontSize: 12, color: Colors.grey[500])),
 ],
 ),
 );
 }

 Widget _buildStatusBadge(String status, Color color) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: color.withOpacity(0.1),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 width: 6,
 height: 6,
 decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
 const SizedBox(width: 6),
 Text(status,
 style: TextStyle(
 fontSize: 11, fontWeight: FontWeight.w500, color: color)),
 ],
 ),
 );
 }

 Widget _buildCategoryChip(String category) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFFF1F5F9),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(category,
 style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
 softWrap: true,
 maxLines: 2,
 overflow: TextOverflow.ellipsis),
 );
 }

 Widget _buildStatusPill(String status) {
 Color bgColor;
 Color textColor;
 switch (status) {
 case 'Completed':
 bgColor = const Color(0xFFD1FAE5);
 textColor = const Color(0xFF059669);
 break;
 case 'In Progress':
 bgColor = const Color(0xFFDBEAFE);
 textColor = const Color(0xFF2563EB);
 break;
 case 'Pending Auction':
 case 'Pending Disposal':
 bgColor = const Color(0xFFFEF3C7);
 textColor = const Color(0xFFD97706);
 break;
 case 'Approved':
 bgColor = const Color(0xFFE0E7FF);
 textColor = const Color(0xFF4F46E5);
 break;
 case 'On Hold':
 bgColor = const Color(0xFFF5F3FF);
 textColor = const Color(0xFF7C3AED);
 break;
 case 'Cancelled':
 bgColor = const Color(0xFFF1F5F9);
 textColor = const Color(0xFF94A3B8);
 break;
 default:
 bgColor = const Color(0xFFF1F5F9);
 textColor = const Color(0xFF64748B);
 }

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: bgColor, borderRadius: BorderRadius.circular(12)),
 child: Text(status,
 style: TextStyle(
 fontSize: 11, fontWeight: FontWeight.w500, color: textColor)),
 );
 }

 Widget _buildPriorityBadge(String priority, Color color) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: color.withOpacity(0.1),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: color.withOpacity(0.3)),
 ),
 child: Text(priority,
 style: TextStyle(
 fontSize: 11, fontWeight: FontWeight.w600, color: color)),
 );
 }
}

class _TeamMember {
 final String name;
 final String role;
 final String email;
 final String status;
 final int tasks;
 final Color statusColor;

 const _TeamMember(this.name, this.role, this.email, this.status, this.tasks,
 this.statusColor);
}

class _DisposalItem {
 final String id;
 final String description;
 final String category;
 final String status;
 final String value;
 final String priority;
 final Color priorityColor;

 const _DisposalItem(this.id, this.description, this.category, this.status,
 this.value, this.priority, this.priorityColor);
}

class _StatItem {
 final String label;
 final String value;
 final IconData icon;
 final Color color;

 const _StatItem(this.label, this.value, this.icon, this.color);
}

class _InsightCard {
 final String title;
 final String value;
 final String description;
 final IconData icon;
 final Color color;

 const _InsightCard(
 this.title, this.value, this.description, this.icon, this.color);
}

class _SignalBar extends StatelessWidget {
 const _SignalBar(
 {required this.label, required this.value, required this.color});

 final String label;
 final double value;
 final Color color;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Text(label,
 style: const TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600))),
 Text('${(value * 100).round()}%',
 style:
 const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
 ],
 ),
 const SizedBox(height: 6),
 ClipRRect(
 borderRadius: BorderRadius.circular(8),
 child: LinearProgressIndicator(
 value: value,
 minHeight: 8,
 backgroundColor: const Color(0xFFE2E8F0),
 valueColor: AlwaysStoppedAnimation<Color>(color),
 ),
 ),
 ],
 ),
 );
 }
}

class _ConditionItem extends StatelessWidget {
 const _ConditionItem(
 {required this.label, required this.count, required this.color});

 final String label;
 final String count;
 final Color color;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 10),
 child: Row(
 children: [
 Container(
 width: 10,
 height: 10,
 decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
 const SizedBox(width: 10),
 Expanded(
 child: Text(label,
 style: const TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600))),
 Text(count,
 style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
 ],
 ),
 );
 }
}

class _CapacityBar extends StatelessWidget {
 const _CapacityBar({required this.item});

 final _CapacityItem item;

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Text(item.label,
 style: const TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600))),
 Text('${(item.value * 100).round()}%',
 style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
 ],
 ),
 const SizedBox(height: 6),
 ClipRRect(
 borderRadius: BorderRadius.circular(8),
 child: LinearProgressIndicator(
 value: item.value,
 minHeight: 8,
 backgroundColor: const Color(0xFFE2E8F0),
 valueColor: AlwaysStoppedAnimation<Color>(item.color),
 ),
 ),
 ],
 );
 }
}

class _InventoryItem {
 final String id;
 final String name;
 final String category;
 final String condition;
 final String location;
 final String status;
 final String value;
 final Color statusColor;

 const _InventoryItem(this.id, this.name, this.category, this.condition,
 this.location, this.status, this.value, this.statusColor);
}

class _QueueBoardItem {
 final String id;
 final String title;
 final String status;
 final String priority;
 final String value;

 const _QueueBoardItem(
 this.id, this.title, this.status, this.priority, this.value);
}

class _AllocationItem {
 final String name;
 final String role;
 final String focus;
 final int workload;
 final String status;

 const _AllocationItem(
 this.name, this.role, this.focus, this.workload, this.status);
}

class _CapacityItem {
 final String label;
 final double value;
 final Color color;

 const _CapacityItem(this.label, this.value, this.color);
}

class _ComplianceRegulationRow {
 const _ComplianceRegulationRow({
 required this.regulation,
 required this.category,
 required this.complianceStatus,
 required this.complianceScore,
 required this.lastAuditDate,
 required this.nextAuditDue,
 required this.daysToExpiry,
 required this.responsibleParty,
 required this.riskLevel,
 required this.findings,
 required this.correctiveActions,
 required this.priority,
 required this.status,
 this.lastUpdated = '',
 });

 final String regulation;
 final String category;
 final String complianceStatus;
 final int complianceScore;
 final String lastAuditDate;
 final String nextAuditDue;
 final int daysToExpiry;
 final String responsibleParty;
 final String riskLevel;
 final int findings;
 final int correctiveActions;
 final String priority;
 final String status;
 final String lastUpdated;

 Map<String, dynamic> toMap() => {
 'regulation': regulation,
 'category': category,
 'complianceStatus': complianceStatus,
 'complianceScore': complianceScore,
 'lastAuditDate': lastAuditDate,
 'nextAuditDue': nextAuditDue,
 'daysToExpiry': daysToExpiry,
 'responsibleParty': responsibleParty,
 'riskLevel': riskLevel,
 'findings': findings,
 'correctiveActions': correctiveActions,
 'priority': priority,
 'status': status,
 'lastUpdated': lastUpdated,
 };

 static _ComplianceRegulationRow fromMap(Map<String, dynamic> map) => _ComplianceRegulationRow(
 regulation: map['regulation']?.toString() ?? '',
 category: map['category']?.toString() ?? 'Environmental',
 complianceStatus: map['complianceStatus']?.toString() ?? 'Compliant',
 complianceScore: (map['complianceScore'] is int) ? map['complianceScore'] as int : int.tryParse(map['complianceScore'].toString()) ?? 0,
 lastAuditDate: map['lastAuditDate']?.toString() ?? '',
 nextAuditDue: map['nextAuditDue']?.toString() ?? '',
 daysToExpiry: (map['daysToExpiry'] is int) ? map['daysToExpiry'] as int : int.tryParse(map['daysToExpiry'].toString()) ?? 0,
 responsibleParty: map['responsibleParty']?.toString() ?? '',
 riskLevel: map['riskLevel']?.toString() ?? 'Low',
 findings: (map['findings'] is int) ? map['findings'] as int : int.tryParse(map['findings'].toString()) ?? 0,
 correctiveActions: (map['correctiveActions'] is int) ? map['correctiveActions'] as int : int.tryParse(map['correctiveActions'].toString()) ?? 0,
 priority: map['priority']?.toString() ?? 'P3',
 status: map['status']?.toString() ?? 'Active',
 lastUpdated: map['lastUpdated']?.toString() ?? '',
 );
}
