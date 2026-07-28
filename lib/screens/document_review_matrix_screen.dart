import 'package:flutter/material.dart';
import 'package:ndu_project/models/document_review_models.dart';
import 'package:ndu_project/services/document_review_service.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
const Color _kBackground = Color(0xFFF7F8FC);
const Color _kAccent = Color(0xFFFFC812);
const Color _kHeadline = Color(0xFF1A1D1F);
const Color _kMuted = Color(0xFF6B7280);
const Color _kCardBorder = Color(0xFFE4E7EC);

class DocumentReviewMatrixScreen extends StatefulWidget {
 const DocumentReviewMatrixScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const DocumentReviewMatrixScreen()),
 );
 }

 @override
 State<DocumentReviewMatrixScreen> createState() =>
 _DocumentReviewMatrixScreenState();
}

class _DocumentReviewMatrixScreenState extends State<DocumentReviewMatrixScreen> {
 bool _isLoading = true;
 List<DocumentReviewItem> _allDocuments = [];
 List<DocumentReviewItem> _filteredDocuments = [];
 DocumentReviewStatistics? _statistics;

 String _selectedCategory = 'All';
 String _selectedPhase = 'All';
 String _selectedStatus = 'All';
 String _searchQuery = '';

 String? get _projectId {
 try {
 return ProjectDataInherited.maybeOf(context)?.projectData.projectId;
 } catch (e) {
 return null;
 }
 }

 @override
 void initState() {
 super.initState();
 _loadData();
 }

 @override
 void didChangeDependencies() {
 super.didChangeDependencies();
 _loadData();
 }

 Future<void> _loadData() async {
 final projectId = _projectId;
 if (projectId == null) return;

 setState(() => _isLoading = true);

 try {
 final documents = await DocumentReviewService.instance
 .loadDocumentReviewMatrix(projectId);
 final stats =
 await DocumentReviewService.instance.getStatistics(projectId);

 if (mounted) {
 setState(() {
 _allDocuments = documents;
 _filteredDocuments = documents;
 _statistics = stats;
 _isLoading = false;
 });
 }
 } catch (e) {
 debugPrint('Error loading document review matrix: $e');
 if (mounted) setState(() => _isLoading = false);
 }
 }

 void _applyFilters() {
 setState(() {
 _filteredDocuments = _allDocuments.where((doc) {
 if (_selectedCategory != 'All' &&
 doc.category.name != _selectedCategory.toLowerCase()) {
 return false;
 }
 if (_selectedPhase != 'All' &&
 doc.phase.name != _selectedPhase.toLowerCase()) {
 return false;
 }
 if (_selectedStatus != 'All' &&
 doc.status.name != _selectedStatus.toLowerCase()) {
 return false;
 }
 if (_searchQuery.isNotEmpty &&
 !doc.documentName.toLowerCase().contains(_searchQuery.toLowerCase())) {
 return false;
 }
 return true;
 }).toList();
 });
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: _kBackground,
 body: Stack(
 children: [
 SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Document Review Matrix'),
 ),
 Expanded(
 child: _isLoading
 ? const Center(child: CircularProgressIndicator())
 : _buildContent()),
 ],
 ),
 ),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Document Review Matrix',
 ),
 ),
 const KazAiChatBubble(),
 ],
 ),
 );
 }

 Widget _buildContent() {
 return Column(
 children: [
 PlanningPhaseHeader(
 title: 'Document Review Matrix',
onBack: () => PlanningPhaseNavigation.goToPrevious(
 context,
 'document_review_matrix',
 ),
 onForward: () => PlanningPhaseNavigation.goToNext(
 context,
 'document_review_matrix',
 ), onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 _buildHeader(),
 if (_statistics != null) _buildStatisticsBar(),
 Expanded(
 child: SingleChildScrollView(
 padding: const EdgeInsets.all(24),
 child: _buildDocumentsTable(),
 ),
 ),
 ],
 );
 }

 Widget _buildHeader() {
 return Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 border: Border(bottom: BorderSide(color: _kCardBorder)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 _NavCircleBtn(
 icon: Icons.arrow_back_ios_new_rounded,
 onTap: () => PlanningPhaseNavigation.goToPrevious(
 context,
 'document_review_matrix',
 ),
 ),
 const SizedBox(width: 10),
 _NavCircleBtn(
 icon: Icons.arrow_forward_ios_rounded,
 onTap: () => PlanningPhaseNavigation.goToNext(
 context,
 'document_review_matrix',
 ),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Document Review Matrix',
 style: TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.bold,
 color: _kHeadline,
 ),
 ),
 const SizedBox(height: 4),
 Text(
 'Track and approve all project documents',
 style: TextStyle(
 fontSize: 14,
 color: _kMuted,
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 _buildFilterBar(),
 ],
 ),
 );
 }

 Widget _buildStatisticsBar() {
 final stats = _statistics!;
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
 decoration: BoxDecoration(
 color: Colors.white,
 border: Border(bottom: BorderSide(color: _kCardBorder)),
 ),
 child: Row(
 children: [
 _buildStatChip('Total', stats.total.toString(), Colors.blue),
 const SizedBox(width: 12),
 _buildStatChip('Pending', stats.pending.toString(), Colors.orange),
 const SizedBox(width: 12),
 _buildStatChip('Approved', stats.completed.toString(), Colors.green),
 const SizedBox(width: 12),
 _buildStatChip('Overdue', stats.overdue.toString(), Colors.red),
 const SizedBox(width: 12),
 _buildStatChip('Needs Re-review', stats.needsRereview.toString(), Colors.purple),
 const Spacer(),
 Text(
 '${stats.completionPercent.toStringAsFixed(0)}% Complete',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Colors.green,
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildStatChip(String label, String value, Color color) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: color.withOpacity(0.1),
 borderRadius: BorderRadius.circular(16),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 '$label: ',
 style: TextStyle(
 fontSize: 12,
 color: color,
 ),
 ),
 Text(
 value,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.bold,
 color: color,
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildFilterBar() {
 return Row(
 children: [
 Expanded(
 child: VoiceTextField(
 decoration: InputDecoration(
 hintText: 'Search documents...',
 prefixIcon: const Icon(Icons.search),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(8),
 borderSide: BorderSide(color: _kCardBorder),
 ),
 contentPadding: const EdgeInsets.symmetric(
 horizontal: 16,
 vertical: 12,
 ),
 ),
 onChanged: (value) {
 _searchQuery = value;
 _applyFilters();
 },
 ),
 ),
 const SizedBox(width: 16),
 _buildDropdown('Category', _selectedCategory, [
 'All',
 'Governance',
 'Requirements',
 'Risk & Compliance',
 'Execution',
 'Technical',
 'Quality',
 'Contracts & Procurement',
 'Schedule & Cost',
 'Team & Stakeholders',
 ], (value) {
 setState(() {
 _selectedCategory = value;
 _applyFilters();
 });
 }),
 const SizedBox(width: 12),
 _buildDropdown('Phase', _selectedPhase, [
 'All',
 'Initiation',
 'Front-End Planning',
 'Planning',
 'Design',
 'Execution',
 'Launch',
 ], (value) {
 setState(() {
 _selectedPhase = value;
 _applyFilters();
 });
 }),
 const SizedBox(width: 12),
 _buildDropdown('Status', _selectedStatus, [
 'All',
 'Not Started',
 'Pending Review',
 'Under Review',
 'Changes Requested',
 'Approved',
 'Rejected',
 ], (value) {
 setState(() {
 _selectedStatus = value;
 _applyFilters();
 });
 }),
 ],
 );
 }

 Widget _buildDropdown(
 String label,
 String value,
 List<String> items,
 Function(String) onChanged,
 ) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: _kMuted,
 ),
 ),
 const SizedBox(height: 4),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12),
 decoration: BoxDecoration(
 border: Border.all(color: _kCardBorder),
 borderRadius: BorderRadius.circular(8),
 ),
 child: DropdownButtonHideUnderline(
 child: DropdownButton<String>(
 value: value,
 items: items
 .map((item) => DropdownMenuItem(
 value: item,
 child: Text(item, style: const TextStyle(fontSize: 14)),
 ))
 .toList(),
 onChanged: (v) => onChanged(v!),
 icon: const Icon(Icons.expand_more, size: 20),
 isDense: true,
 ),
 ),
 ),
 ],
 );
 }

 Widget _buildDocumentsTable() {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 children: [
 _buildTableHeader(),
 if (_filteredDocuments.isEmpty)
 _buildEmptyState()
 else
 _buildTableRows(),
 ],
 ),
 );
 }

 Widget _buildTableHeader() {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: const BorderRadius.only(
 topLeft: Radius.circular(18),
 topRight: Radius.circular(18),
 ),
 ),
 child: const Row(
 children: [
 SizedBox(width: 50, child: Center(child: Text('#', style: _headerStyle))),
 Expanded(flex: 2, child: Center(child: Text('DOCUMENT', style: _headerStyle))),
 Expanded(child: Center(child: Text('PHASE', style: _headerStyle))),
 Expanded(child: Center(child: Text('CATEGORY', style: _headerStyle))),
 Expanded(child: Center(child: Text('STATUS', style: _headerStyle))),
 Expanded(child: Center(child: Text('REVIEWER', style: _headerStyle))),
 Expanded(child: Center(child: Text('APPROVER', style: _headerStyle))),
 Expanded(child: Center(child: Text('DUE DATE', style: _headerStyle))),
 Expanded(child: Center(child: Text('VERSION', style: _headerStyle))),
 SizedBox(width: 60, child: Center(child: Text('ACTIONS', style: _headerStyle))),
 ],
 ),
 );
 }

 Widget _buildEmptyState() {
 return Padding(
 padding: const EdgeInsets.all(48),
 child: Column(
 children: [
 Icon(Icons.description_outlined,
 size: 64, color: _kMuted.withOpacity(0.5)),
 const SizedBox(height: 16),
 Text(
 'No documents found',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w500,
 color: _kMuted,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 'Try adjusting your filters or search terms',
 style: TextStyle(
 fontSize: 14,
 color: _kMuted,
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildTableRows() {
 return Column(
 children: [
 for (var i = 0; i < _filteredDocuments.length; i++)
 _buildTableRow(_filteredDocuments[i], i),
 ],
 );
 }

 Widget _buildTableRow(DocumentReviewItem doc, int index) {
 final isEven = index.isEven;
 return InkWell(
 onTap: () => _showDocumentPreview(doc),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 decoration: BoxDecoration(
 color: doc.isOverdue
 ? Colors.red.withOpacity(0.05)
 : (isEven ? Colors.white : const Color(0xFFF9FAFB)),
 border: Border(
 top: BorderSide(
 color: const Color(0xFFE5E7EB),
 width: index == 0 ? 1 : 0.5,
 ),
 ),
 ),
 child: Row(
 children: [
 SizedBox(
 width: 50,
 child: Center(
 child: Text(
 '${index + 1}',
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF9CA3AF),
 ),
 ),
 ),
 ),
 Expanded(
 flex: 2,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 doc.documentName,
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w500,
 color: _kHeadline,
 ),
 ),
 if (doc.description.isNotEmpty)
 Text(
 doc.description,
 style: TextStyle(
 fontSize: 12,
 color: _kMuted,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ],
 ),
 ),
 Expanded(child: Text(doc.phaseLabel, style: _cellStyle)),
 Expanded(child: Text(doc.categoryLabel, style: _cellStyle)),
 Expanded(child: _buildStatusChip(doc.status)),
 Expanded(
 child: Text(
 doc.primaryReviewerName ?? 'Unassigned',
 style: _cellStyle,
 ),
 ),
 Expanded(
 child: Text(
 doc.finalApproverName ?? 'Unassigned',
 style: _cellStyle,
 ),
 ),
 Expanded(
 child: Text(
 doc.reviewDueDate != null
 ? '${doc.reviewDueDate!.month}/${doc.reviewDueDate!.day}'
 : '-',
 style: _cellStyle.copyWith(
 color: doc.isOverdue ? Colors.red : null,
 ),
 ),
 ),
 Expanded(
 child: Center(
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: Colors.grey.withOpacity(0.1),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Text('v${doc.version}'),
 ),
 ),
 ),
 SizedBox(
 width: 60,
 child: Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 IconButton(
 icon: const Icon(Icons.visibility_outlined, size: 18),
 onPressed: () => _showDocumentPreview(doc),
 tooltip: 'Preview',
 ),
 PopupMenuButton<String>(
 icon: const Icon(Icons.more_vert, size: 18),
 onSelected: (action) => _handleMenuAction(action, doc),
 itemBuilder: (context) => [
 const PopupMenuItem(
 value: 'assign',
 child: Row(
 children: [
 Icon(Icons.person_add_outlined, size: 18),
 SizedBox(width: 12),
 Text('Assign Reviewer'),
 ],
 ),
 ),
 const PopupMenuItem(
 value: 'approve',
 child: Row(
 children: [
 Icon(Icons.check_circle_outline, size: 18),
 SizedBox(width: 12),
 Text('Approve'),
 ],
 ),
 ),
 const PopupMenuItem(
 value: 'reject',
 child: Row(
 children: [
 Icon(Icons.cancel_outlined, size: 18),
 SizedBox(width: 12),
 Text('Reject'),
 ],
 ),
 ),
 const PopupMenuItem(
 value: 'request_changes',
 child: Row(
 children: [
 Icon(Icons.edit_outlined, size: 18),
 SizedBox(width: 12),
 Text('Request Changes'),
 ],
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildStatusIcon(ReviewStatus status) {
 IconData icon;
 Color color;

 switch (status) {
 case ReviewStatus.approved:
 icon = Icons.check_circle;
 color = Colors.green;
 break;
 case ReviewStatus.underReview:
 icon = Icons.rate_review;
 color = Colors.blue;
 break;
 case ReviewStatus.pendingReview:
 icon = Icons.pending;
 color = Colors.orange;
 break;
 case ReviewStatus.changesRequested:
 icon = Icons.edit_note;
 color = Colors.orange;
 break;
 case ReviewStatus.rejected:
 icon = Icons.cancel;
 color = Colors.red;
 break;
 case ReviewStatus.notStarted:
 icon = Icons.circle_outlined;
 color = Colors.grey;
 break;
 }

 return Icon(icon, color: color, size: 18);
 }

 Widget _buildStatusChip(ReviewStatus status) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: _getStatusColor(status).withOpacity(0.1),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Text(
 _getStatusLabel(status),
 style: TextStyle(
 fontSize: 12,
 color: _getStatusColor(status),
 fontWeight: FontWeight.w500,
 ),
 ),
 );
 }

 Color _getStatusColor(ReviewStatus status) {
 switch (status) {
 case ReviewStatus.approved:
 return Colors.green;
 case ReviewStatus.underReview:
 return Colors.blue;
 case ReviewStatus.pendingReview:
 return Colors.orange;
 case ReviewStatus.changesRequested:
 return Colors.orange;
 case ReviewStatus.rejected:
 return Colors.red;
 case ReviewStatus.notStarted:
 return Colors.grey;
 }
 }

 String _getStatusLabel(ReviewStatus status) {
 switch (status) {
 case ReviewStatus.notStarted:
 return 'Not Started';
 case ReviewStatus.pendingReview:
 return 'Pending Review';
 case ReviewStatus.underReview:
 return 'Under Review';
 case ReviewStatus.changesRequested:
 return 'Changes Requested';
 case ReviewStatus.approved:
 return 'Approved';
 case ReviewStatus.rejected:
 return 'Rejected';
 }
 }

 void _showDocumentPreview(DocumentReviewItem doc) {
 showDialog(
 context: context,
 builder: (context) => _DocumentPreviewDialog(
 document: doc,
 onAssignReviewer: () => _assignReviewer(doc),
 onApprove: () => _approveDocument(doc),
 onReject: () => _rejectDocument(doc),
 onRequestChanges: () => _requestChanges(doc),
 onRefresh: () {
 _loadData();
 Navigator.of(context).pop();
 },
 ),
 );
 }

 void _handleMenuAction(String action, DocumentReviewItem doc) {
 switch (action) {
 case 'assign':
 _assignReviewer(doc);
 break;
 case 'approve':
 _approveDocument(doc);
 break;
 case 'reject':
 _rejectDocument(doc);
 break;
 case 'request_changes':
 _requestChanges(doc);
 break;
 }
 }

 void _assignReviewer(DocumentReviewItem doc) {
 showDialog(
 context: context,
 builder: (context) => _AssignReviewerDialog(
 document: doc,
 onAssign: (reviewerId, reviewerName, role) async {
 final projectId = _projectId;
 if (projectId == null) return;

 final success = await DocumentReviewService.instance.assignReviewer(
 projectId: projectId,
 reviewItemId: doc.id,
 reviewerId: reviewerId,
 reviewerName: reviewerName,
 role: role,
 );

 if (success) {
 _loadData();
 if (mounted) Navigator.of(context).pop();
 }
 },
 ),
 );
 }

 void _approveDocument(DocumentReviewItem doc) {
 _showReviewDialog(
 doc,
 'Approve Document',
 'approve',
 Icons.check_circle,
 Colors.green,
 (comments) async {
 final projectId = _projectId;
 if (projectId == null) return false;

 return await DocumentReviewService.instance.approveDocument(
 projectId: projectId,
 reviewItemId: doc.id,
 reviewerId: 'current_user_id', // TODO: Get actual user
 reviewerName: 'Current User',
 reviewerRole: 'Project Manager',
 comments: comments,
 );
 },
 );
 }

 void _rejectDocument(DocumentReviewItem doc) {
 _showReviewDialog(
 doc,
 'Reject Document',
 'reject',
 Icons.cancel,
 Colors.red,
 (reason) async {
 final projectId = _projectId;
 if (projectId == null) return false;

 return await DocumentReviewService.instance.rejectDocument(
 projectId: projectId,
 reviewItemId: doc.id,
 reviewerId: 'current_user_id', // TODO: Get actual user
 reviewerName: 'Current User',
 reviewerRole: 'Project Manager',
 reason: reason ?? '',
 );
 },
 );
 }

 void _requestChanges(DocumentReviewItem doc) {
 _showReviewDialog(
 doc,
 'Request Changes',
 'request changes',
 Icons.edit_note,
 Colors.orange,
 (changes) async {
 final projectId = _projectId;
 if (projectId == null) return false;

 return await DocumentReviewService.instance.requestChanges(
 projectId: projectId,
 reviewItemId: doc.id,
 reviewerId: 'current_user_id', // TODO: Get actual user
 reviewerName: 'Current User',
 reviewerRole: 'Project Manager',
 requestedChanges: changes ?? '',
 );
 },
 );
 }

 void _showReviewDialog(
 DocumentReviewItem doc,
 String title,
 String actionLabel,
 IconData icon,
 Color color,
 Future<bool> Function(String?) onSubmit,
 ) {
 final controller = TextEditingController();

 showDialog(
 context: context,
 builder: (context) => AlertDialog(
 title: Row(
 children: [
 Icon(icon, color: color),
 const SizedBox(width: 12),
 Text(title),
 ],
 ),
 content: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Document: ${doc.documentName}'),
 const SizedBox(height: 16),
 VoiceTextField(
 controller: controller,
 maxLines: 4,
 decoration: InputDecoration(
 hintText: 'Enter comments (optional)...',
 border: const OutlineInputBorder(),
 ),
 ),
 ],
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () async {
 final success = await onSubmit(controller.text.isEmpty ? null : controller.text);
 if (success && mounted) {
 _loadData();
 Navigator.of(context).pop();
 }
 },
 style: ElevatedButton.styleFrom(backgroundColor: color),
 child: Text(actionLabel.toUpperCase()),
 ),
 ],
 ),
 );
 }

 static const TextStyle _headerStyle = TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 letterSpacing: 0.8,
 color: Color(0xFF6B7280),
 );

 static const TextStyle _cellStyle = TextStyle(
 fontSize: 14,
 color: Color(0xFF374151),
 );

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Document Review Matrix',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_document_review_matrix_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

class _DocumentPreviewDialog extends StatelessWidget {
 final DocumentReviewItem document;
 final VoidCallback onAssignReviewer;
 final VoidCallback onApprove;
 final VoidCallback onReject;
 final VoidCallback onRequestChanges;
 final VoidCallback onRefresh;

 const _DocumentPreviewDialog({
 required this.document,
 required this.onAssignReviewer,
 required this.onApprove,
 required this.onReject,
 required this.onRequestChanges,
 required this.onRefresh,
 });

 @override
 Widget build(BuildContext context) {
 return Dialog(
 child: Container(
 width: 600,
 constraints: const BoxConstraints(maxHeight: 700),
 child: Column(
 children: [
 _buildHeader(context),
 Expanded(
 child: SingleChildScrollView(
 padding: const EdgeInsets.all(24),
 child: _buildContent(context),
 ),
 ),
 _buildActions(context),
 ],
 ),
 ),
 );
 }

 Widget _buildHeader(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.grey.withOpacity(0.05),
 border: Border(bottom: BorderSide(color: _kCardBorder)),
 ),
 child: Row(
 children: [
 Icon(
 Icons.description,
 color: _getStatusColor(document.status),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 document.documentName,
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.bold,
 ),
 ),
 Text(
 'Version ${document.version} • ${document.phaseLabel}',
 style: TextStyle(
 fontSize: 12,
 color: _kMuted,
 ),
 ),
 ],
 ),
 ),
 IconButton(
 icon: const Icon(Icons.close),
 onPressed: () => Navigator.of(context).pop(),
 ),
 ],
 ),
 );
 }

 Widget _buildContent(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (document.description.isNotEmpty) ...[
 _buildSection('Description', document.description),
 const SizedBox(height: 16),
 ],
 _buildInfoRow('Category', document.categoryLabel),
 _buildInfoRow('Status', document.statusLabel),
 _buildInfoRow('Due Date',
 document.reviewDueDate != null ? document.reviewDueDate!.toLocal().toString().split(' ')[0] : 'Not set'),
 _buildInfoRow('Primary Reviewer', document.primaryReviewerName ?? 'Not assigned'),
 _buildInfoRow('Final Approver', document.finalApproverName ?? 'Not assigned'),
 if (document.reviewComments != null && document.reviewComments!.isNotEmpty) ...[
 const SizedBox(height: 16),
 _buildSection('Review Comments', document.reviewComments!),
 ],
 if (document.reviewHistory.isNotEmpty) ...[
 const SizedBox(height: 16),
 _buildSection('Review History', ''),
 ...document.reviewHistory.map((entry) => _buildHistoryEntry(entry)),
 ],
 ],
 );
 }

 Widget _buildSection(String title, String content) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.bold,
 color: _kHeadline,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 content,
 style: TextStyle(
 fontSize: 14,
 color: _kMuted,
 ),
 ),
 ],
 );
 }

 Widget _buildInfoRow(String label, String value) {
 return Padding(
 padding: const EdgeInsets.symmetric(vertical: 4),
 child: Row(
 children: [
 SizedBox(
 width: 120,
 child: Text(
 '$label:',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w500,
 color: _kMuted,
 ),
 ),
 ),
 Expanded(
 child: Text(
 value,
 style: const TextStyle(
 fontSize: 14,
 color: _kHeadline,
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildHistoryEntry(ReviewHistoryEntry entry) {
 return Container(
 margin: const EdgeInsets.only(bottom: 8),
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: Colors.grey.withOpacity(0.05),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Text(
 entry.reviewerName,
 style: const TextStyle(
 fontWeight: FontWeight.w500,
 ),
 ),
 const SizedBox(width: 8),
 Text(
 entry.reviewerRole,
 style: TextStyle(
 fontSize: 12,
 color: _kMuted,
 ),
 ),
 const Spacer(),
 Text(
 '${entry.timestamp.month}/${entry.timestamp.day}/${entry.timestamp.year}',
 style: TextStyle(
 fontSize: 12,
 color: _kMuted,
 ),
 ),
 ],
 ),
 if (entry.comments != null && entry.comments!.isNotEmpty) ...[
 const SizedBox(height: 4),
 Text(
 entry.comments!,
 style: TextStyle(
 fontSize: 13,
 color: _kMuted,
 ),
 ),
 ],
 ],
 ),
 );
 }

 Widget _buildActions(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.grey.withOpacity(0.05),
 border: Border(top: BorderSide(color: _kCardBorder)),
 ),
 child: Row(
 children: [
 OutlinedButton.icon(
 onPressed: onAssignReviewer,
 icon: const Icon(Icons.person_add_outlined, size: 18),
 label: const Text('Assign'),
 ),
 const SizedBox(width: 12),
 OutlinedButton.icon(
 onPressed: onReject,
 icon: const Icon(Icons.cancel_outlined, size: 18),
 label: const Text('Reject'),
 style: OutlinedButton.styleFrom(
 foregroundColor: Colors.red,
 ),
 ),
 const Spacer(),
 OutlinedButton.icon(
 onPressed: onRequestChanges,
 icon: const Icon(Icons.edit_outlined, size: 18),
 label: const Text('Request Changes'),
 ),
 const SizedBox(width: 12),
 ElevatedButton.icon(
 onPressed: onApprove,
 icon: const Icon(Icons.check_circle, size: 18),
 label: const Text('Approve'),
 style: ElevatedButton.styleFrom(
 backgroundColor: Colors.green,
 foregroundColor: Colors.white,
 ),
 ),
 ],
 ),
 );
 }

 Color _getStatusColor(ReviewStatus status) {
 switch (status) {
 case ReviewStatus.approved:
 return Colors.green;
 case ReviewStatus.underReview:
 return Colors.blue;
 case ReviewStatus.pendingReview:
 return Colors.orange;
 case ReviewStatus.changesRequested:
 return Colors.orange;
 case ReviewStatus.rejected:
 return Colors.red;
 case ReviewStatus.notStarted:
 return Colors.grey;
 }
 }
}

class _AssignReviewerDialog extends StatefulWidget {
 final DocumentReviewItem document;
 final Function(String reviewerId, String reviewerName, ReviewerRole role) onAssign;

 const _AssignReviewerDialog({
 required this.document,
 required this.onAssign,
 });

 @override
 State<_AssignReviewerDialog> createState() => _AssignReviewerDialogState();
}

class _AssignReviewerDialogState extends State<_AssignReviewerDialog> {
 ReviewerRole _selectedRole = ReviewerRole.primary;
 String _selectedUserId = '';
 String _selectedUserName = '';

 // TODO: Load actual team members
 final List<Map<String, String>> _teamMembers = [
 {'id': '1', 'name': 'John Smith'},
 {'id': '2', 'name': 'Jane Doe'},
 {'id': '3', 'name': 'Bob Johnson'},
 ];

 @override
 Widget build(BuildContext context) {
 return AlertDialog(
 title: const Text('Assign Reviewer'),
 content: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 DropdownButtonFormField<ReviewerRole>(
 value: _selectedRole,
 decoration: const InputDecoration(
 labelText: 'Role',
 border: OutlineInputBorder(),
 ),
 items: ReviewerRole.values
 .map((r) => DropdownMenuItem(
 value: r,
 child: Text(r.name.toUpperCase()),
 ))
 .toList(),
 onChanged: (v) => setState(() => _selectedRole = v!),
 ),
 const SizedBox(height: 16),
 DropdownButtonFormField<String>(
 value: _selectedUserId.isEmpty ? null : _selectedUserId,
 decoration: const InputDecoration(
 labelText: 'Team Member',
 border: OutlineInputBorder(),
 ),
 items: _teamMembers
 .map((m) => DropdownMenuItem(
 value: m['id'],
 child: Text(m['name']!),
 ))
 .toList(),
 onChanged: (v) {
 setState(() {
 _selectedUserId = v!;
 _selectedUserName = _teamMembers.firstWhere((m) => m['id'] == v)['name']!;
 });
 },
 ),
 ],
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: _selectedUserId.isEmpty
 ? null
 : () {
 widget.onAssign(_selectedUserId, _selectedUserName, _selectedRole);
 },
 child: const Text('Assign'),
 ),
 ],
 );
 }
}

class _NavCircleBtn extends StatelessWidget {
 const _NavCircleBtn({required this.icon, this.onTap});

 final IconData icon;
 final VoidCallback? onTap;

 @override
 Widget build(BuildContext context) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(18),
 child: Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: Colors.white,
 shape: BoxShape.circle,
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Icon(icon, size: 16, color: const Color(0xFF6B7280)),
 ),
 );
 }
}
