import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/screens/specialized_design_screen.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/launch_data_table.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
class LongLeadEquipmentOrderingScreen extends StatefulWidget {
 const LongLeadEquipmentOrderingScreen({super.key});

 @override
 State<LongLeadEquipmentOrderingScreen> createState() =>
 _LongLeadEquipmentOrderingScreenState();
}

class _LongLeadEquipmentOrderingScreenState
 extends State<LongLeadEquipmentOrderingScreen> {
 final TextEditingController _notesController = TextEditingController();
 final _Debouncer _saveDebounce = _Debouncer();
 bool _isLoading = false;
 bool _suspendNotesSave = false;

 final List<_EquipmentCategory> _categories = [];
 final List<_EquipmentItem> _equipmentItems = [];
 final List<_ProcurementAction> _actions = [];

 final List<String> _criticalityOptions = const ['High', 'Medium', 'Low'];
 final List<String> _equipmentStatusOptions = const [
 'Planned',
 'Ordered',
 'In production',
 'In transit',
 'Delivered',
 'On hold'
 ];
 final List<String> _actionStatusOptions = const [
 'Planned',
 'Active',
 'Blocked',
 'Completed'
 ];

 void _showExportFeedback() {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Equipment schedule export will use the latest saved register data.',
 ),
 ),
 );
 }

 @override
 void initState() {
 super.initState();
 _notesController.addListener(() {
 if (_suspendNotesSave) return;
 _scheduleSave();
 });
 WidgetsBinding.instance.addPostFrameCallback((_) => _loadFromFirestore());
 }

 @override
 void dispose() {
 _notesController.dispose();
 _saveDebounce.dispose();
 super.dispose();
 }

 String? _projectId() => ProjectDataHelper.getData(context).projectId;

 Future<void> _loadFromFirestore() async {
 final projectId = _projectId();
 if (projectId == null || projectId.isEmpty) return;
 setState(() => _isLoading = true);
 try {
 final doc = await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('design_phase_sections')
 .doc('long_lead_equipment_ordering')
 .get();
 final data = doc.data() ?? {};
 _suspendNotesSave = true;
 _notesController.text = data['notes']?.toString() ?? '';
 _suspendNotesSave = false;
 final categories = _EquipmentCategory.fromList(data['categories']);
 final equipmentItems = _EquipmentItem.fromList(data['equipmentItems']);
 final actions = _ProcurementAction.fromList(data['actions']);
 if (!mounted) return;
 setState(() {
 _categories
 ..clear()
 ..addAll(categories);
 _equipmentItems
 ..clear()
 ..addAll(equipmentItems);
 _actions
 ..clear()
 ..addAll(actions);
 });
 } catch (error) {
 debugPrint('Failed to load long lead equipment ordering data: $error');
 } finally {
 if (mounted) setState(() => _isLoading = false);
 }
 }

 void _scheduleSave() {
 _saveDebounce.run(_saveToFirestore);
 }

 Future<void> _saveToFirestore() async {
 final projectId = _projectId();
 if (projectId == null || projectId.isEmpty) return;
 final payload = {
 'notes': _notesController.text.trim(),
 'categories': _categories.map((entry) => entry.toJson()).toList(),
 'equipmentItems': _equipmentItems.map((entry) => entry.toJson()).toList(),
 'actions': _actions.map((entry) => entry.toJson()).toList(),
 'updatedAt': FieldValue.serverTimestamp(),
 };
 await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('design_phase_sections')
 .doc('long_lead_equipment_ordering')
 .set(payload, SetOptions(merge: true));
 }

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 final padding = AppBreakpoints.pagePadding(context);

 return ResponsiveScaffold(
 activeItemLabel: 'Long Lead Equipment Ordering',
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: Column(
 children: [
 PlanningPhaseHeader(
 title: 'Long Lead Equipment Ordering', onExportPdf: _exportPdf),
 Expanded(
 child: SingleChildScrollView(
 padding: EdgeInsets.all(padding),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (_isLoading) const LinearProgressIndicator(minHeight: 2),
 if (_isLoading) const SizedBox(height: 16),
 // Page Title
 Text(
 'Long Lead Equipment Ordering',
 style: TextStyle(
 fontSize: isMobile ? 20 : 24,
 fontWeight: FontWeight.bold,
 color: LightModeColors.accent,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 'Plan and track equipment with extended procurement timelines',
 style: TextStyle(
 fontSize: isMobile ? 16 : 18,
 fontWeight: FontWeight.w600,
 color: Colors.black87,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 'Identify and manage equipment that requires early ordering to avoid schedule delays and ensure timely project delivery.',
 style: TextStyle(fontSize: 14, color: Colors.grey[700]),
 ),
 const SizedBox(height: 24),

 _buildNotesCard(),
 const SizedBox(height: 16),

 // Helper Text
 Text(
 'Focus on items where procurement timing directly impacts project milestones or critical path activities.',
 style: TextStyle(fontSize: 13, color: Colors.grey[600]),
 ),
 const SizedBox(height: 24),

 // Three Cards - stacked layout
 Column(
 children: [
 _buildCategoriesCard(),
 const SizedBox(height: 16),
 _buildEquipmentTrackingCard(),
 const SizedBox(height: 16),
 _buildProcurementActionsCard(),
 ],
 ),
 const SizedBox(height: 32),

 // Bottom Navigation
 _buildBottomNavigation(isMobile),
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildCategoriesCard() {
 return _SectionCard(
 title: 'Equipment categories',
 subtitle: 'Types of items requiring early procurement.',
 actionLabel: 'Create item',
 onAction: _addCategory,
 child: _buildCategoriesTable(),
 );
 }

 Widget _buildEquipmentTrackingCard() {
 return _SectionCard(
 title: 'Equipment tracking',
 subtitle: 'Current status of long-lead items.',
 actionLabel: 'Create item',
 onAction: _addEquipmentItem,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildEquipmentTable(),
 const SizedBox(height: 12),
 Text(
 'Track all equipment with lead times exceeding 4 weeks to ensure timely delivery.',
 style: TextStyle(fontSize: 12, color: Colors.grey[600]),
 ),
 ],
 ),
 );
 }

 Widget _buildProcurementActionsCard() {
 return _SectionCard(
 title: 'Procurement actions',
 subtitle: 'Steps to manage long-lead procurement.',
 actionLabel: 'Create item',
 onAction: _addAction,
 child: Column(
 children: [
 _buildActionsTable(),
 const SizedBox(height: 16),
 SizedBox(
 width: double.infinity,
 child: ElevatedButton.icon(
 onPressed: _showExportFeedback,
 icon: const Icon(Icons.download, size: 18),
 label: const Text('Export equipment schedule'),
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

 Widget _buildBottomNavigation(bool isMobile) {
 return Column(
 children: [
 const Divider(),
 const SizedBox(height: 16),
 if (isMobile)
 Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 Text('Design phase • Long lead equipment ordering',
 style: TextStyle(fontSize: 13, color: Colors.grey[500]),
 textAlign: TextAlign.center),
 const SizedBox(height: 12),
 OutlinedButton.icon(
 onPressed: () => Navigator.pop(context),
 icon: const Icon(Icons.arrow_back, size: 18),
 label: const Text('Back: Tools integration'),
 style: OutlinedButton.styleFrom(
 padding:
 const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 side: BorderSide(color: Colors.grey[300]!),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8)),
 foregroundColor: Colors.black87,
 ),
 ),
 const SizedBox(height: 12),
 ElevatedButton.icon(
 onPressed: () => Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const SpecializedDesignScreen(),
 ),
 ),
 icon: const Icon(Icons.arrow_forward, size: 18),
 label: const Text('Next: Specialized design'),
 style: ElevatedButton.styleFrom(
 backgroundColor: Colors.black87,
 foregroundColor: Colors.white,
 padding:
 const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(20)),
 ),
 ),
 ],
 )
 else
 Row(
 children: [
 OutlinedButton.icon(
 onPressed: () => Navigator.pop(context),
 icon: const Icon(Icons.arrow_back, size: 18),
 label: const Text('Back: Tools integration'),
 style: OutlinedButton.styleFrom(
 padding:
 const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 side: BorderSide(color: Colors.grey[300]!),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8)),
 foregroundColor: Colors.black87,
 ),
 ),
 const SizedBox(width: 16),
 Text('Design phase • Long lead equipment ordering',
 style: TextStyle(fontSize: 13, color: Colors.grey[500])),
 const Spacer(),
 ElevatedButton.icon(
 onPressed: () => Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const SpecializedDesignScreen(),
 ),
 ),
 icon: const Icon(Icons.arrow_forward, size: 18),
 label: const Text('Next: Specialized design'),
 style: ElevatedButton.styleFrom(
 backgroundColor: Colors.black87,
 foregroundColor: Colors.white,
 padding:
 const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(20)),
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 // Footer hint
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Icon(Icons.lightbulb_outline,
 size: 18, color: LightModeColors.accent),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 'Start procurement activities for long-lead items as early as possible to maintain schedule flexibility and reduce project risk.',
 style: TextStyle(fontSize: 12, color: Colors.grey[600]),
 ),
 ),
 ],
 ),
 ],
 );
 }

 Widget _buildNotesCard() {
 return _SectionCard(
 title: 'Notes',
 subtitle: 'Capture lead times, vendor constraints, and critical dates.',
 child: VoiceTextField(
 controller: _notesController,
 maxLines: 3,
 decoration: InputDecoration(
 hintText:
 'Document key ordering considerations, vendor contacts, and escalation triggers.',
 hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
 filled: true,
 fillColor: Colors.white,
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: BorderSide.none),
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
 ),
 ),
 );
 }

 void _addCategory() {
 _openCategoryDialog();
 }

 void _updateCategory(_EquipmentCategory updated) {
 final index = _categories.indexWhere((entry) => entry.id == updated.id);
 if (index == -1) return;
 setState(() => _categories[index] = updated);
 _scheduleSave();
 }

  void _deleteCategory(String id) async {
  final ok = await launchConfirmDelete(context, itemName: 'equipment category');
  if (!ok) return;
  setState(() => _categories.removeWhere((entry) => entry.id == id));
  _scheduleSave();
  }

 void _addEquipmentItem() {
 _openEquipmentDialog();
 }

 void _updateEquipmentItem(_EquipmentItem updated) {
 final index = _equipmentItems.indexWhere((entry) => entry.id == updated.id);
 if (index == -1) return;
 setState(() => _equipmentItems[index] = updated);
 _scheduleSave();
 }

  void _deleteEquipmentItem(String id) async {
  final ok = await launchConfirmDelete(context, itemName: 'equipment item');
  if (!ok) return;
  setState(() => _equipmentItems.removeWhere((entry) => entry.id == id));
  _scheduleSave();
  }

 void _addAction() {
 _openActionDialog();
 }

 void _updateAction(_ProcurementAction updated) {
 final index = _actions.indexWhere((entry) => entry.id == updated.id);
 if (index == -1) return;
 setState(() => _actions[index] = updated);
 _scheduleSave();
 }

  void _deleteAction(String id) async {
  final ok = await launchConfirmDelete(context, itemName: 'action');
  if (!ok) return;
  setState(() => _actions.removeWhere((entry) => entry.id == id));
  _scheduleSave();
  }

 Future<void> _openCategoryDialog() async {
 final draft = _EquipmentCategory.empty();
 final titleController = TextEditingController();
 final descriptionController = TextEditingController();
 final thresholdController = TextEditingController();
 final ownerController = TextEditingController();
 String criticality = _criticalityOptions[1];

 final saved = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (context, setModalState) => AlertDialog(
 title: const Text('Add equipment category'),
 content: SizedBox(
 width: 520,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: titleController,
 decoration: const InputDecoration(
 labelText: 'Category',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: descriptionController,
 minLines: 2,
 maxLines: 4,
 decoration: const InputDecoration(
 labelText: 'Description',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: criticality,
 items: _criticalityOptions
 .map((option) => DropdownMenuItem(
 value: option,
 child: Text(option),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setModalState(() => criticality = value);
 },
 decoration: const InputDecoration(
 labelText: 'Criticality',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: thresholdController,
 decoration: const InputDecoration(
 labelText: 'Lead time threshold',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: ownerController,
 decoration: const InputDecoration(
 labelText: 'Owner',
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
 child: const Text('Add category'),
 ),
 ],
 ),
 ),
 );
 if (saved != true) return;
 setState(() {
 _categories.add(
 draft.copyWith(
 title: titleController.text.trim(),
 description: descriptionController.text.trim(),
 criticality: criticality,
 leadTimeThreshold: thresholdController.text.trim(),
 owner: ownerController.text.trim(),
 ),
 );
 });
 _scheduleSave();
 }

 Future<void> _openEquipmentDialog() async {
 final draft = _EquipmentItem.empty();
 final nameController = TextEditingController();
 final categoryController = TextEditingController();
 final vendorController = TextEditingController();
 final leadTimeController = TextEditingController();
 final deliveryController = TextEditingController();
 final ownerController = TextEditingController();
 String status = _equipmentStatusOptions.first;

 final saved = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (context, setModalState) => AlertDialog(
 title: const Text('Add equipment item'),
 content: SizedBox(
 width: 560,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: nameController,
 decoration: const InputDecoration(
 labelText: 'Item',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: categoryController,
 decoration: const InputDecoration(
 labelText: 'Category',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: vendorController,
 decoration: const InputDecoration(
 labelText: 'Vendor',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: leadTimeController,
 decoration: const InputDecoration(
 labelText: 'Lead time',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: deliveryController,
 decoration: const InputDecoration(
 labelText: 'Expected delivery',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: status,
 items: _equipmentStatusOptions
 .map((option) => DropdownMenuItem(
 value: option,
 child: Text(option),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setModalState(() => status = value);
 },
 decoration: const InputDecoration(
 labelText: 'Status',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: ownerController,
 decoration: const InputDecoration(
 labelText: 'Owner',
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
 child: const Text('Add item'),
 ),
 ],
 ),
 ),
 );
 if (saved != true) return;
 setState(() {
 _equipmentItems.add(
 draft.copyWith(
 name: nameController.text.trim(),
 category: categoryController.text.trim(),
 vendor: vendorController.text.trim(),
 leadTime: leadTimeController.text.trim(),
 expectedDelivery: deliveryController.text.trim(),
 status: status,
 owner: ownerController.text.trim(),
 ),
 );
 });
 _scheduleSave();
 }

 Future<void> _openActionDialog() async {
 final draft = _ProcurementAction.empty();
 final titleController = TextEditingController();
 final ownerController = TextEditingController();
 final dueDateController = TextEditingController();
 final notesController = TextEditingController();
 String status = _actionStatusOptions.first;

 final saved = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (context, setModalState) => AlertDialog(
 title: const Text('Add procurement action'),
 content: SizedBox(
 width: 540,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: titleController,
 decoration: const InputDecoration(
 labelText: 'Action',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: ownerController,
 decoration: const InputDecoration(
 labelText: 'Owner',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: dueDateController,
 decoration: const InputDecoration(
 labelText: 'Due date',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: status,
 items: _actionStatusOptions
 .map((option) => DropdownMenuItem(
 value: option,
 child: Text(option),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setModalState(() => status = value);
 },
 decoration: const InputDecoration(
 labelText: 'Status',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: notesController,
 minLines: 2,
 maxLines: 4,
 decoration: const InputDecoration(
 labelText: 'Notes',
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
 child: const Text('Add action'),
 ),
 ],
 ),
 ),
 );
 if (saved != true) return;
 setState(() {
 _actions.add(
 draft.copyWith(
 title: titleController.text.trim(),
 owner: ownerController.text.trim(),
 dueDate: dueDateController.text.trim(),
 status: status,
 notes: notesController.text.trim(),
 ),
 );
 });
 _scheduleSave();
 }

 Widget _buildCategoriesTable() {
 final columns = [
 const _TableColumnDef('Category', 200),
 const _TableColumnDef('Description', 260),
 const _TableColumnDef('Criticality', 140),
 const _TableColumnDef('Lead time threshold', 180),
 const _TableColumnDef('Owner', 160),
 const _TableColumnDef('', 60),
 ];

 if (_categories.isEmpty) {
 return const _InlineEmptyState(
 title: 'No categories yet',
 message: 'Add categories to classify long-lead items.',
 );
 }

 return _EditableTable(
 columns: columns,
 rows: [
 for (final entry in _categories)
 _EditableRow(
 key: ValueKey(entry.id),
 columns: columns,
 cells: [
 _TextCell(
 value: entry.title,
 fieldKey: '${entry.id}_title',
 hintText: 'Category',
 onChanged: (value) =>
 _updateCategory(entry.copyWith(title: value)),
 ),
 _TextCell(
 value: entry.description,
 fieldKey: '${entry.id}_desc',
 hintText: 'Description',
 maxLines: 2,
 onChanged: (value) =>
 _updateCategory(entry.copyWith(description: value)),
 ),
 _DropdownCell(
 value: entry.criticality,
 fieldKey: '${entry.id}_criticality',
 options: _criticalityOptions,
 onChanged: (value) =>
 _updateCategory(entry.copyWith(criticality: value)),
 ),
 _TextCell(
 value: entry.leadTimeThreshold,
 fieldKey: '${entry.id}_threshold',
 hintText: 'e.g., 6 weeks',
 onChanged: (value) =>
 _updateCategory(entry.copyWith(leadTimeThreshold: value)),
 ),
 _TextCell(
 value: entry.owner,
 fieldKey: '${entry.id}_owner',
 hintText: 'Owner',
 onChanged: (value) =>
 _updateCategory(entry.copyWith(owner: value)),
 ),
 _DeleteCell(onPressed: () => _deleteCategory(entry.id)),
 ],
 ),
 ],
 );
 }

 Widget _buildEquipmentTable() {
 final columns = [
 const _TableColumnDef('Item', 220),
 const _TableColumnDef('Category', 180),
 const _TableColumnDef('Vendor', 180),
 const _TableColumnDef('Lead time', 140),
 const _TableColumnDef('Expected delivery', 160),
 const _TableColumnDef('Status', 160),
 const _TableColumnDef('Owner', 160),
 const _TableColumnDef('', 60),
 ];

 if (_equipmentItems.isEmpty) {
 return const _InlineEmptyState(
 title: 'No equipment items yet',
 message: 'Add equipment to track procurement status.',
 );
 }

 return _EditableTable(
 columns: columns,
 rows: [
 for (final entry in _equipmentItems)
 _EditableRow(
 key: ValueKey(entry.id),
 columns: columns,
 cells: [
 _TextCell(
 value: entry.name,
 fieldKey: '${entry.id}_name',
 hintText: 'Item',
 onChanged: (value) =>
 _updateEquipmentItem(entry.copyWith(name: value)),
 ),
 _TextCell(
 value: entry.category,
 fieldKey: '${entry.id}_category',
 hintText: 'Category',
 onChanged: (value) =>
 _updateEquipmentItem(entry.copyWith(category: value)),
 ),
 _TextCell(
 value: entry.vendor,
 fieldKey: '${entry.id}_vendor',
 hintText: 'Vendor',
 onChanged: (value) =>
 _updateEquipmentItem(entry.copyWith(vendor: value)),
 ),
 _TextCell(
 value: entry.leadTime,
 fieldKey: '${entry.id}_lead',
 hintText: 'e.g., 12 weeks',
 onChanged: (value) =>
 _updateEquipmentItem(entry.copyWith(leadTime: value)),
 ),
 _TextCell(
 value: entry.expectedDelivery,
 fieldKey: '${entry.id}_delivery',
 hintText: 'YYYY-MM-DD',
 onChanged: (value) => _updateEquipmentItem(
 entry.copyWith(expectedDelivery: value)),
 ),
 _DropdownCell(
 value: entry.status,
 fieldKey: '${entry.id}_status',
 options: _equipmentStatusOptions,
 onChanged: (value) =>
 _updateEquipmentItem(entry.copyWith(status: value)),
 ),
 _TextCell(
 value: entry.owner,
 fieldKey: '${entry.id}_owner',
 hintText: 'Owner',
 onChanged: (value) =>
 _updateEquipmentItem(entry.copyWith(owner: value)),
 ),
 _DeleteCell(onPressed: () => _deleteEquipmentItem(entry.id)),
 ],
 ),
 ],
 );
 }

 Widget _buildActionsTable() {
 final columns = [
 const _TableColumnDef('Action', 240),
 const _TableColumnDef('Owner', 180),
 const _TableColumnDef('Due date', 140),
 const _TableColumnDef('Status', 160),
 const _TableColumnDef('Notes', 240),
 const _TableColumnDef('', 60),
 ];

 if (_actions.isEmpty) {
 return const _InlineEmptyState(
 title: 'No actions yet',
 message: 'Add procurement actions and owners.',
 );
 }

 return _EditableTable(
 columns: columns,
 rows: [
 for (final entry in _actions)
 _EditableRow(
 key: ValueKey(entry.id),
 columns: columns,
 cells: [
 _TextCell(
 value: entry.title,
 fieldKey: '${entry.id}_title',
 hintText: 'Action',
 onChanged: (value) =>
 _updateAction(entry.copyWith(title: value)),
 ),
 _TextCell(
 value: entry.owner,
 fieldKey: '${entry.id}_owner',
 hintText: 'Owner',
 onChanged: (value) =>
 _updateAction(entry.copyWith(owner: value)),
 ),
 _TextCell(
 value: entry.dueDate,
 fieldKey: '${entry.id}_due',
 hintText: 'YYYY-MM-DD',
 onChanged: (value) =>
 _updateAction(entry.copyWith(dueDate: value)),
 ),
 _DropdownCell(
 value: entry.status,
 fieldKey: '${entry.id}_status',
 options: _actionStatusOptions,
 onChanged: (value) =>
 _updateAction(entry.copyWith(status: value)),
 ),
 _TextCell(
 value: entry.notes,
 fieldKey: '${entry.id}_notes',
 hintText: 'Notes',
 maxLines: 2,
 onChanged: (value) =>
 _updateAction(entry.copyWith(notes: value)),
 ),
 _DeleteCell(onPressed: () => _deleteAction(entry.id)),
 ],
 ),
 ],
 );
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Long Lead Equipment Ordering',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_long_lead_equipment_ordering_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

class _SectionCard extends StatelessWidget {
 const _SectionCard({
 required this.title,
 required this.subtitle,
 required this.child,
 this.actionLabel,
 this.onAction,
 });

 final String title;
 final String subtitle;
 final Widget child;
 final String? actionLabel;
 final VoidCallback? onAction;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: AppSemanticColors.border),
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
 fontSize: 16, fontWeight: FontWeight.w600)),
 const SizedBox(height: 4),
 Text(subtitle,
 style:
 TextStyle(fontSize: 12, color: Colors.grey[600])),
 ],
 ),
 ),
 if (actionLabel != null && onAction != null)
 TextButton.icon(
 onPressed: onAction,
 icon: const Icon(Icons.add, size: 16),
 label: Text(actionLabel!),
 style: TextButton.styleFrom(
 foregroundColor: LightModeColors.accent,
 padding: EdgeInsets.zero,
 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
 minimumSize: const Size(0, 32),
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
 final resolvedValue = options.contains(value) ? value : options.first;
 return DropdownButtonFormField<String>(
 key: ValueKey(fieldKey),
 value: resolvedValue,
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

class _DeleteCell extends StatelessWidget {
 const _DeleteCell({required this.onPressed});

 final VoidCallback onPressed;

 @override
 Widget build(BuildContext context) {
 return IconButton(
 onPressed: onPressed,
 icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
 tooltip: 'Delete',
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

class _EquipmentCategory {
 const _EquipmentCategory({
 required this.id,
 required this.title,
 required this.description,
 required this.criticality,
 required this.leadTimeThreshold,
 required this.owner,
 });

 final String id;
 final String title;
 final String description;
 final String criticality;
 final String leadTimeThreshold;
 final String owner;

 factory _EquipmentCategory.empty() {
 return _EquipmentCategory(
 id: DateTime.now().microsecondsSinceEpoch.toString(),
 title: '',
 description: '',
 criticality: 'Medium',
 leadTimeThreshold: '',
 owner: '',
 );
 }

 _EquipmentCategory copyWith({
 String? title,
 String? description,
 String? criticality,
 String? leadTimeThreshold,
 String? owner,
 }) {
 return _EquipmentCategory(
 id: id,
 title: title ?? this.title,
 description: description ?? this.description,
 criticality: criticality ?? this.criticality,
 leadTimeThreshold: leadTimeThreshold ?? this.leadTimeThreshold,
 owner: owner ?? this.owner,
 );
 }

 Map<String, dynamic> toJson() {
 return {
 'id': id,
 'title': title,
 'description': description,
 'criticality': criticality,
 'leadTimeThreshold': leadTimeThreshold,
 'owner': owner,
 };
 }

 static List<_EquipmentCategory> fromList(dynamic raw) {
 if (raw is! List) return [];
 return raw.whereType<Map>().map((item) {
 final data = Map<String, dynamic>.from(item);
 return _EquipmentCategory(
 id: data['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 title: data['title']?.toString() ?? '',
 description: data['description']?.toString() ?? '',
 criticality: data['criticality']?.toString() ?? 'Medium',
 leadTimeThreshold: data['leadTimeThreshold']?.toString() ?? '',
 owner: data['owner']?.toString() ?? '',
 );
 }).toList();
 }
}

class _EquipmentItem {
 const _EquipmentItem({
 required this.id,
 required this.name,
 required this.category,
 required this.vendor,
 required this.leadTime,
 required this.expectedDelivery,
 required this.status,
 required this.owner,
 });

 final String id;
 final String name;
 final String category;
 final String vendor;
 final String leadTime;
 final String expectedDelivery;
 final String status;
 final String owner;

 factory _EquipmentItem.empty() {
 return _EquipmentItem(
 id: DateTime.now().microsecondsSinceEpoch.toString(),
 name: '',
 category: '',
 vendor: '',
 leadTime: '',
 expectedDelivery: '',
 status: 'Planned',
 owner: '',
 );
 }

 _EquipmentItem copyWith({
 String? name,
 String? category,
 String? vendor,
 String? leadTime,
 String? expectedDelivery,
 String? status,
 String? owner,
 }) {
 return _EquipmentItem(
 id: id,
 name: name ?? this.name,
 category: category ?? this.category,
 vendor: vendor ?? this.vendor,
 leadTime: leadTime ?? this.leadTime,
 expectedDelivery: expectedDelivery ?? this.expectedDelivery,
 status: status ?? this.status,
 owner: owner ?? this.owner,
 );
 }

 Map<String, dynamic> toJson() {
 return {
 'id': id,
 'name': name,
 'category': category,
 'vendor': vendor,
 'leadTime': leadTime,
 'expectedDelivery': expectedDelivery,
 'status': status,
 'owner': owner,
 };
 }

 static List<_EquipmentItem> fromList(dynamic raw) {
 if (raw is! List) return [];
 return raw.whereType<Map>().map((item) {
 final data = Map<String, dynamic>.from(item);
 return _EquipmentItem(
 id: data['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 name: data['name']?.toString() ?? '',
 category: data['category']?.toString() ?? '',
 vendor: data['vendor']?.toString() ?? '',
 leadTime: data['leadTime']?.toString() ?? '',
 expectedDelivery: data['expectedDelivery']?.toString() ?? '',
 status: data['status']?.toString() ?? 'Planned',
 owner: data['owner']?.toString() ?? '',
 );
 }).toList();
 }
}

class _ProcurementAction {
 const _ProcurementAction({
 required this.id,
 required this.title,
 required this.owner,
 required this.dueDate,
 required this.status,
 required this.notes,
 });

 final String id;
 final String title;
 final String owner;
 final String dueDate;
 final String status;
 final String notes;

 factory _ProcurementAction.empty() {
 return _ProcurementAction(
 id: DateTime.now().microsecondsSinceEpoch.toString(),
 title: '',
 owner: '',
 dueDate: '',
 status: 'Planned',
 notes: '',
 );
 }

 _ProcurementAction copyWith({
 String? title,
 String? owner,
 String? dueDate,
 String? status,
 String? notes,
 }) {
 return _ProcurementAction(
 id: id,
 title: title ?? this.title,
 owner: owner ?? this.owner,
 dueDate: dueDate ?? this.dueDate,
 status: status ?? this.status,
 notes: notes ?? this.notes,
 );
 }

 Map<String, dynamic> toJson() {
 return {
 'id': id,
 'title': title,
 'owner': owner,
 'dueDate': dueDate,
 'status': status,
 'notes': notes,
 };
 }

 static List<_ProcurementAction> fromList(dynamic raw) {
 if (raw is! List) return [];
 return raw.whereType<Map>().map((item) {
 final data = Map<String, dynamic>.from(item);
 return _ProcurementAction(
 id: data['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 title: data['title']?.toString() ?? '',
 owner: data['owner']?.toString() ?? '',
 dueDate: data['dueDate']?.toString() ?? '',
 status: data['status']?.toString() ?? 'Planned',
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
