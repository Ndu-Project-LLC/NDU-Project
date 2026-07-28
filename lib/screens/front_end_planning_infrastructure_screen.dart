import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/screens/front_end_planning_technology_personnel_screen.dart';
import 'package:ndu_project/screens/planning_technology_screen.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/content_text.dart';
import 'package:ndu_project/widgets/front_end_planning_header.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';
class FrontEndPlanningInfrastructureScreen extends StatefulWidget {
 const FrontEndPlanningInfrastructureScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const FrontEndPlanningInfrastructureScreen(),
 ),
 );
 }

 @override
 State<FrontEndPlanningInfrastructureScreen> createState() =>
 _FrontEndPlanningInfrastructureScreenState();
}

class _FrontEndPlanningInfrastructureScreenState
 extends State<FrontEndPlanningInfrastructureScreen> {
 final TextEditingController _notes = TextEditingController();
 List<InfrastructurePlanningItem> _items = [];
 Timer? _infrastructurePromptTimer;
 bool _hasShownPrompt = false;
 bool _isSyncReady = false;

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) {
 final data = ProjectDataHelper.getData(context);
 setState(() {
 _notes.text = data.frontEndPlanning.infrastructure;
 _items = List<InfrastructurePlanningItem>.from(
 data.frontEndPlanning.infrastructureItems);
 _isSyncReady = true;
 });
 _notes.addListener(_onTextChanged);
 _startInactivityTimer();
 });
 }

 
 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 final fep = projectData.frontEndPlanning;
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Infrastructure',
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
 _infrastructurePromptTimer?.cancel();
 _notes.removeListener(_onTextChanged);
 _notes.dispose();
 super.dispose();
 }

 void _onTextChanged() {
 _syncNotesToProvider();
 _infrastructurePromptTimer?.cancel();
 _startInactivityTimer();
 }

 void _syncNotesToProvider() {
 if (!mounted || !_isSyncReady) return;
 final provider = ProjectDataHelper.getProvider(context);
 provider.updateField(
 (data) => data.copyWith(
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 infrastructure: _notes.text,
 ),
 ),
 );
 provider.saveToFirebase(checkpoint: 'fep_infrastructure');
 }

 void _syncItemsToProvider() {
 if (!mounted || !_isSyncReady) return;
 final provider = ProjectDataHelper.getProvider(context);
 provider.updateField(
 (data) => data.copyWith(
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 infrastructureItems: _items,
 ),
 ),
 );
 provider.saveToFirebase(checkpoint: 'fep_infrastructure');
 }

 void _startInactivityTimer() {
 _infrastructurePromptTimer = Timer(const Duration(seconds: 60), () {
 if (!mounted || _hasShownPrompt) return;
 if (_notes.text.trim().isEmpty && _items.isEmpty) {
 _hasShownPrompt = true;
 _showInfrastructureDialog().then((_) {
 if (!mounted) return;
 _hasShownPrompt = false;
 _startInactivityTimer();
 });
 }
 });
 }

 Future<void> _showInfrastructureDialog({
 InfrastructurePlanningItem? existing,
 }) async {
 final nameController =
 TextEditingController(text: existing?.name.trim() ?? '');
 final summaryController =
 TextEditingController(text: existing?.summary.trim() ?? '');
 final detailsController =
 TextEditingController(text: existing?.details.trim() ?? '');
 final costController = TextEditingController(
 text: existing != null && existing.potentialCost > 0
 ? existing.potentialCost.toStringAsFixed(0)
 : '',
 );
 final ownerController =
 TextEditingController(text: existing?.owner.trim() ?? '');
 var status = existing?.status.trim().isNotEmpty == true
 ? existing!.status.trim()
 : 'Planned';

 try {
 final result = await showDialog<InfrastructurePlanningItem>(
 context: context,
 barrierDismissible: false,
 builder: (dialogContext) {
 return StatefulBuilder(
 builder: (context, setDialogState) {
 return Dialog(
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12),
 ),
 child: Container(
 constraints: const BoxConstraints(maxWidth: 640),
 padding: const EdgeInsets.all(24),
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 existing == null
 ? 'Add Infrastructure Item'
 : 'Edit Infrastructure Item',
 style: const TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w600,
 color: Colors.black,
 ),
 ),
 const SizedBox(height: 16),
 VoiceTextField(
 controller: nameController,
 decoration: const InputDecoration(
 labelText: 'Infrastructure',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: summaryController,
 decoration: const InputDecoration(
 labelText: 'Summary',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: detailsController,
 minLines: 3,
 maxLines: 5,
 decoration: const InputDecoration(
 labelText: 'Detailed Description',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: costController,
 keyboardType:
 const TextInputType.numberWithOptions(
 decimal: true,
 ),
 decoration: const InputDecoration(
 labelText: 'Potential Cost',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextField(
 controller: ownerController,
 decoration: const InputDecoration(
 labelText: 'Owner',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: status,
 decoration: const InputDecoration(
 labelText: 'Status',
 border: OutlineInputBorder(),
 ),
 items: const [
 DropdownMenuItem(
 value: 'Planned', child: Text('Planned')),
 DropdownMenuItem(
 value: 'In Review', child: Text('In Review')),
 DropdownMenuItem(
 value: 'Approved', child: Text('Approved')),
 DropdownMenuItem(
 value: 'Deferred', child: Text('Deferred')),
 ],
 onChanged: (value) {
 setDialogState(() {
 status = value ?? 'Planned';
 });
 },
 ),
 const SizedBox(height: 24),
 Align(
 alignment: Alignment.centerRight,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 TextButton(
 onPressed: () =>
 Navigator.of(dialogContext).pop(),
 child: const Text('Cancel'),
 ),
 const SizedBox(width: 8),
 ElevatedButton(
 onPressed: () {
 final name = nameController.text.trim();
 if (name.isEmpty) return;
 final potentialCost = double.tryParse(
 costController.text
 .trim()
 .replaceAll(',', ''),
 ) ??
 0;
 final item =
 (existing ?? InfrastructurePlanningItem())
 .copyWith(
 number:
 existing?.number ?? (_items.length + 1),
 name: name,
 summary: summaryController.text.trim(),
 details: detailsController.text.trim(),
 potentialCost: potentialCost,
 owner: ownerController.text.trim(),
 status: status,
 );
 Navigator.of(dialogContext).pop(item);
 },
 child: Text(existing == null ? 'Add' : 'Save'),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 ),
 );
 },
 );
 },
 );

 if (!mounted || result == null) return;
 setState(() {
 final index = _items.indexWhere((item) => item.id == result.id);
 if (index >= 0) {
 _items[index] = result.copyWith(number: index + 1);
 } else {
 _items.add(result.copyWith(number: _items.length + 1));
 }
 });
 _syncItemsToProvider();
 } finally {
 nameController.dispose();
 summaryController.dispose();
 detailsController.dispose();
 costController.dispose();
 ownerController.dispose();
 }
 }

  Future<void> _deleteInfrastructureItem(
    InfrastructurePlanningItem item,
  ) async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Delete Infrastructure Item',
      itemLabel: item.name.trim(),
    );
    if (!confirmed) return;

 setState(() {
 _items.removeWhere((entry) => entry.id == item.id);
 _items = _items.asMap().entries.map((entry) {
 return entry.value.copyWith(number: entry.key + 1);
 }).toList();
 });
 _syncItemsToProvider();
 }

 double get _infrastructureTotal => _items.fold<double>(
 0,
 (total, item) => total + item.potentialCost,
 );

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const InitiationLikeSidebar(
 activeItemLabel: 'Initiation: Front End Planning',
 ),
 Expanded(
 child: Stack(
 children: [
 const AdminEditToggle(),
 Column(
 children: [
 FrontEndPlanningHeader(onExportPdf: _exportPdf),
 Expanded(
 child: SingleChildScrollView(
 padding: const EdgeInsets.symmetric(
 horizontal: 32,
 vertical: 24,
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _roundedField(
 controller: _notes,
 hint: 'Input your notes here...',
 minLines: 3,
 ),
 const SizedBox(height: 22),
 Row(
 crossAxisAlignment: CrossAxisAlignment.end,
 children: [
 Expanded(
 child: RichText(
 text: const TextSpan(
 children: [
 TextSpan(
 text: 'Project Infrastructure ',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 TextSpan(
 text:
 '(Early planning for required project infrastructure.)',
 style: TextStyle(
 fontSize: 14,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 ),
 ),
 const SizedBox(width: 12),
 _yellowPillButton(
 label: 'Go to Detailed View',
 onTap: () =>
 PlanningTechnologyScreen.open(context),
 ),
 ],
 ),
 const SizedBox(height: 14),
 _InfrastructureSummary(
 itemCount: _items.length,
 total: _infrastructureTotal,
 ),
 const SizedBox(height: 14),
 _InfrastructureTable(
 items: _items,
 onEdit: (item) =>
 _showInfrastructureDialog(existing: item),
 onDelete: _deleteInfrastructureItem,
 ),
 const SizedBox(height: 140),
 ],
 ),
 ),
 ),
 ],
 ),
 _BottomOverlays(
 nextLabel: 'Next',
 onAddItems: () => _showInfrastructureDialog(),
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
}

class _InfrastructureSummary extends StatelessWidget {
 const _InfrastructureSummary({required this.itemCount, required this.total});

 final int itemCount;
 final double total;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 children: [
 _metric('Structured Items', '$itemCount'),
 const SizedBox(width: 24),
 _metric('Potential Cost', _formatCurrency(total)),
 ],
 ),
 );
 }

 Widget _metric(String label, String value) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF6B7280),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 value,
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ],
 );
 }
}

class _InfrastructureTable extends StatelessWidget {
 const _InfrastructureTable({
 required this.items,
 required this.onEdit,
 required this.onDelete,
 });

 final List<InfrastructurePlanningItem> items;
 final ValueChanged<InfrastructurePlanningItem> onEdit;
 final ValueChanged<InfrastructurePlanningItem> onDelete;

 @override
 Widget build(BuildContext context) {
 final border = const BorderSide(color: Color(0xFFE5E7EB));
 final headerStyle = const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF4B5563),
 );
 final cellStyle = const TextStyle(fontSize: 14, color: Color(0xFF111827));

 Widget td(Widget child) => Padding(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 child: child,
 );

 final rows = <TableRow>[
 TableRow(
 decoration: const BoxDecoration(color: Color(0xFFF9FAFB)),
 children: [
 _th('No', headerStyle),
 _th('Infrastructure', headerStyle),
 _th('Summary', headerStyle),
 _th('Detailed Description', headerStyle),
 _th('Potential cost', headerStyle),
 _th('Owner', headerStyle),
 _th('Status', headerStyle),
 _th('Actions', headerStyle),
 ],
 ),
 ];

 if (items.isEmpty) {
 rows.add(
 TableRow(
 children: [
 td(const SizedBox.shrink()),
 td(
 const Text(
 'No structured infrastructure items added yet.',
 style: TextStyle(
 fontSize: 14,
 color: Color(0xFF6B7280),
 ),
 ),
 ),
 td(const SizedBox.shrink()),
 td(const SizedBox.shrink()),
 td(const SizedBox.shrink()),
 td(const SizedBox.shrink()),
 td(const SizedBox.shrink()),
 td(const SizedBox.shrink()),
 ],
 ),
 );
 } else {
 for (var index = 0; index < items.length; index++) {
 final item = items[index];
 rows.add(
 TableRow(
 children: [
 td(Text('${index + 1}', style: cellStyle)),
 td(Text(item.name.trim(), style: cellStyle)),
 td(Text(
 item.summary.trim().isEmpty ? '-' : item.summary.trim(),
 style: cellStyle,
 )),
 td(Text(
 item.details.trim().isEmpty ? '-' : item.details.trim(),
 style: cellStyle,
 )),
 td(Text(_formatCurrency(item.potentialCost), style: cellStyle)),
 td(Text(item.owner.trim().isEmpty ? '-' : item.owner.trim(),
 style: cellStyle)),
 td(Text(item.status.trim(), style: cellStyle)),
 td(
 Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 onPressed: () => onEdit(item),
 icon: const Icon(Icons.edit_outlined, size: 18),
 ),
 IconButton(
 onPressed: () => onDelete(item),
 icon: const Icon(Icons.delete_outline, size: 18),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }
 }

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: LayoutBuilder(
 builder: (context, constraints) {
 final minTableWidth =
 constraints.maxWidth > 1440 ? constraints.maxWidth : 1440.0;
 return Scrollbar(
 thumbVisibility: true,
 child: SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: ConstrainedBox(
 constraints: BoxConstraints(minWidth: minTableWidth),
 child: Table(
 columnWidths: const {
 0: FixedColumnWidth(52),
 1: FlexColumnWidth(1.6),
 2: FlexColumnWidth(1.4),
 3: FlexColumnWidth(2.2),
 4: FixedColumnWidth(130),
 5: FixedColumnWidth(140),
 6: FixedColumnWidth(110),
 7: FixedColumnWidth(110),
 },
 border: TableBorder(
 horizontalInside: border,
 verticalInside: border,
 top: border,
 bottom: border,
 left: border,
 right: border,
 ),
 defaultVerticalAlignment: TableCellVerticalAlignment.middle,
 children: rows,
 ),
 ),
 ),
 );
 },
 ),
 );
 }

 Widget _th(String text, TextStyle style) {
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
 child: Center(
 child: EditableContentText(
 contentKey:
 'fep_infra_header_${text.toLowerCase().replaceAll(' ', '_')}',
 fallback: text,
 category: 'front_end_planning',
 style: style,
 textAlign: TextAlign.center,
 ),
 ),
 );
 }
}

class _BottomOverlays extends StatelessWidget {
 const _BottomOverlays({required this.nextLabel, required this.onAddItems});

 final String nextLabel;
 final VoidCallback onAddItems;

 @override
 Widget build(BuildContext context) {
 return Positioned.fill(
 child: IgnorePointer(
 ignoring: false,
 child: Stack(
 children: [
 Positioned(
 left: 24,
 bottom: 24,
 child: Row(
 children: [
 Container(
 width: 48,
 height: 48,
 decoration: const BoxDecoration(
 color: Color(0xFFB3D9FF),
 shape: BoxShape.circle,
 ),
 child: const Icon(Icons.info_outline, color: Colors.white),
 ),
 const SizedBox(width: 12),
 ElevatedButton(
 onPressed: onAddItems,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: Colors.black,
 padding: const EdgeInsets.symmetric(
 horizontal: 20,
 vertical: 14,
 ),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(10),
 ),
 elevation: 0,
 ),
 child: const Text(
 'Add Items',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 ),
 ),
 ),
 ],
 ),
 ),
 Positioned(
 right: 24,
 bottom: 24,
 child: Row(
 children: [
 _aiHint(),
 const SizedBox(width: 16),
 ElevatedButton(
 onPressed: () =>
 FrontEndPlanningTechnologyPersonnelScreen.open(context),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: Colors.black,
 padding: const EdgeInsets.symmetric(
 horizontal: 28,
 vertical: 14,
 ),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(22),
 ),
 elevation: 0,
 ),
 child: Text(
 nextLabel,
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w600,
 ),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _aiHint() {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 decoration: BoxDecoration(
 color: const Color(0xFFE6F1FF),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFD7E5FF)),
 ),
 child: Row(
 children: const [
 Icon(Icons.auto_awesome, color: Color(0xFFD97706)),
 SizedBox(width: 8),
 Text(
 'AI',
 style: TextStyle(
 fontWeight: FontWeight.w800,
 color: Color(0xFFD97706),
 ),
 ),
 SizedBox(width: 10),
 Text(
 'Capture infrastructure requirements and potential cost exposure.',
 style: TextStyle(color: Color(0xFF1F2937)),
 ),
 ],
 ),
 );
 }
}

Widget _roundedField({
 required TextEditingController controller,
 required String hint,
 int minLines = 1,
}) {
 return Container(
 width: double.infinity,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE4E7EC)),
 ),
 padding: const EdgeInsets.all(14),
 child: VoiceTextField(
 controller: controller,
 minLines: minLines,
 maxLines: null,
 decoration: InputDecoration(
 isDense: true,
 border: InputBorder.none,
 hintText: hint,
 hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
 ),
 style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
 ),
 );
}

Widget _yellowPillButton({
 required String label,
 required VoidCallback onTap,
}) {
 return ElevatedButton(
 onPressed: onTap,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: Colors.black,
 padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 elevation: 0,
 ),
 child: Text(
 label,
 style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
 ),
 );
}

String _formatCurrency(double value) {
 final sign = value < 0 ? '-' : '';
 final absolute = value.abs();
 final whole = absolute.toStringAsFixed(0);
 final chars = whole.split('').reversed.toList();
 final parts = <String>[];
 for (var i = 0; i < chars.length; i++) {
 if (i > 0 && i % 3 == 0) {
 parts.add(',');
 }
 parts.add(chars[i]);
 }
 return '$sign\$${parts.reversed.join()}';
}
