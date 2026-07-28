import 'package:flutter/material.dart';
import 'package:ndu_project/models/staffing_row.dart';
import 'package:ndu_project/wbs/screens/wbs_module_screen.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/content_text.dart';
import 'package:ndu_project/widgets/front_end_planning_header.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/program_workspace_scaffold.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/widgets/csv_import_dialog.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/widgets/rate_card_management_dialog.dart';
import 'package:ndu_project/models/rate_card.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';
class FrontEndPlanningPersonnelScreen extends StatefulWidget {
 const FrontEndPlanningPersonnelScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const FrontEndPlanningPersonnelScreen(),
 ),
 );
 }

 @override
 State<FrontEndPlanningPersonnelScreen> createState() =>
 _FrontEndPlanningPersonnelScreenState();
}

class _FrontEndPlanningPersonnelScreenState
 extends State<FrontEndPlanningPersonnelScreen> {
 final TextEditingController _notes = TextEditingController();
 List<StaffingRow> _rows = [];
 bool _isSyncReady = false;

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) {
 final data = ProjectDataHelper.getData(context);
 setState(() {
 _notes.text = data.frontEndPlanning.personnel;
 _rows = List<StaffingRow>.from(data.frontEndPlanning.staffingRows);
 _isSyncReady = true;
 });
 _notes.addListener(_syncNotesToProvider);
 });
 }

 
 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 final fep = projectData.frontEndPlanning;
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Personnel',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', fep.requirementsNotes ?? 'No data recorded.'),
 ],
 );
 }
  /// Open the Rate Card management dialog
  Future<void> _openRateCardManager() async {
    final data = ProjectDataHelper.getData(context);
    final existingCards = List<RateCard>.from(data.rateCards);
    
    final result = await RateCardManagementDialog.show(
      context,
      existingCards: existingCards,
    );
    
    if (result != null && mounted) {
      // Save updated rate cards
      final provider = ProjectDataHelper.getProvider(context);
      provider.updateField((projectData) => projectData.copyWith(rateCards: result));
      await provider.saveToFirebase(checkpoint: 'rate_cards');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.length.toString() + ' rate card(s) saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Import staffing roles from CSV file
  Future<void> _importFromCsv() async {
    final rows = await showCsvImportDialog(
      context,
      tableTitle: 'Staffing Plan',
      columns: [
        CsvColumnSpec(key: 'role', label: 'Role Title', sampleValue: 'Project Manager'),
        CsvColumnSpec(key: 'quantity', label: 'Quantity', sampleValue: '1'),
        CsvColumnSpec(key: 'type', label: 'Type (Internal/External)', sampleValue: 'Internal'),
        CsvColumnSpec(key: 'startDate', label: 'Start Date', sampleValue: '2024-01-15'),
        CsvColumnSpec(key: 'durationMonths', label: 'Duration (months)', sampleValue: '12'),
        CsvColumnSpec(key: 'monthlyCost', label: 'Monthly Cost (\$', sampleValue: '15000'),
        CsvColumnSpec(key: 'description', label: 'Role Description', sampleValue: 'Responsible for overall project delivery...'),
        CsvColumnSpec(key: 'skills', label: 'Skill Requirements', sampleValue: 'PMP certification, 10+ years experience'),
        CsvColumnSpec(key: 'notes', label: 'Notes', sampleValue: 'Critical hire - must be filled before kickoff'),
      ],
    );

    if (rows == null || !mounted) return;

    final newRows = <StaffingRow>[];
    for (final csvRow in rows) {
      final row = StaffingRow(
        role: (csvRow['role'] ?? '').toString().trim(),
        quantity: int.tryParse((csvRow['quantity'] ?? '1').toString().trim()) ?? 1,
        isInternal: (csvRow['type'] ?? 'Internal').toString().trim().toLowerCase() != 'external',
        startDate: (csvRow['startDate'] ?? '').toString().trim(),
        durationMonths: (csvRow['durationMonths'] ?? '12').toString().trim(),
        monthlyCost: (csvRow['monthlyCost'] ?? '0').toString().trim(),
        roleDescription: (csvRow['description'] ?? '').toString().trim(),
        skillRequirements: (csvRow['skills'] ?? '').toString().trim(),
        notes: (csvRow['notes'] ?? '').toString().trim(),
        status: 'Planned',
      );
      if (row.role.isNotEmpty) {
        newRows.add(row);
      }
    }

    if (newRows.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid rows found in CSV'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _rows.addAll(newRows);
    });
    _syncRowsToProvider();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newRows.length.toString() + ' staffing role(s) imported successfully'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              _rows.removeRange(_rows.length - newRows.length, _rows.length);
            });
            _syncRowsToProvider();
          },
        ),
      ),
    );
  }

@override
 void dispose() {
 _notes.removeListener(_syncNotesToProvider);
 _notes.dispose();
 super.dispose();
 }

 void _syncNotesToProvider() {
 if (!mounted || !_isSyncReady) return;
 final provider = ProjectDataHelper.getProvider(context);
 provider.updateField(
 (data) => data.copyWith(
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 personnel: _notes.text,
 ),
 ),
 );
 provider.saveToFirebase(checkpoint: 'fep_personnel');
 }

 void _syncRowsToProvider() {
 if (!mounted || !_isSyncReady) return;
 final provider = ProjectDataHelper.getProvider(context);
 provider.updateField(
 (data) => data.copyWith(
 frontEndPlanning: ProjectDataHelper.updateFEPField(
 current: data.frontEndPlanning,
 staffingRows: _rows,
 ),
 ),
 );
 provider.saveToFirebase(checkpoint: 'fep_personnel');
 }

 Future<void> _upsertRow({StaffingRow? existing}) async {
 final roleController = TextEditingController(text: existing?.role ?? '');
 final quantityController = TextEditingController(
 text: existing != null ? existing.quantity.toString() : '1');
 final durationController =
 TextEditingController(text: existing?.durationMonths ?? '');
 final monthlyCostController =
 TextEditingController(text: existing?.monthlyCost ?? '');
 final startDateController =
 TextEditingController(text: existing?.startDate ?? '');
 final descriptionController =
 TextEditingController(text: existing?.roleDescription ?? '');
 final skillsController =
 TextEditingController(text: existing?.skillRequirements ?? '');
 final notesController = TextEditingController(text: existing?.notes ?? '');
 var isInternal = existing?.isInternal ?? true;
 var status = existing?.status.trim().isNotEmpty == true
 ? existing!.status.trim()
 : 'Not Started';

 try {
 final result = await showDialog<StaffingRow>(
 context: context,
 builder: (dialogContext) {
 return StatefulBuilder(
 builder: (context, setDialogState) {
 return AlertDialog(
 title:
 Text(existing == null ? 'Add Staffing Role' : 'Edit Role'),
 content: SizedBox(
 width: 640,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: roleController,
 decoration: const InputDecoration(
 labelText: 'Role',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: quantityController,
 keyboardType: TextInputType.number,
 decoration: const InputDecoration(
 labelText: 'Quantity',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextField(
 controller: durationController,
 keyboardType:
 const TextInputType.numberWithOptions(
 decimal: true,
 ),
 decoration: const InputDecoration(
 labelText: 'Duration (months)',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: monthlyCostController,
 keyboardType:
 const TextInputType.numberWithOptions(
 decimal: true,
 ),
 decoration: const InputDecoration(  labelText: 'Monthly Rate',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextField(
 controller: startDateController,
 decoration: const InputDecoration(
 labelText: 'Start Date',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: DropdownButtonFormField<String>(
 value: status,
 decoration: const InputDecoration(
 labelText: 'Status',
 border: OutlineInputBorder(),
 ),
 items: const [
 DropdownMenuItem(
 value: 'Not Started',
 child: Text('Not Started')),
 DropdownMenuItem(
 value: 'Planned', child: Text('Planned')),
 DropdownMenuItem(
 value: 'In Progress',
 child: Text('In Progress')),
 DropdownMenuItem(
 value: 'Confirmed',
 child: Text('Confirmed')),
 ],
 onChanged: (value) {
 setDialogState(() {
 status = value ?? 'Not Started';
 });
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: SwitchListTile(
 value: isInternal,
 onChanged: (value) {
 setDialogState(() {
 isInternal = value;
 });
 },
 title: Text(
 isInternal ? 'Internal' : 'External',
 style: const TextStyle(fontSize: 14),
 ),
 contentPadding: const EdgeInsets.symmetric(
 horizontal: 12,
 ),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8),
 side: const BorderSide(
 color: Color(0xFFD1D5DB),
 ),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: descriptionController,
 minLines: 3,
 maxLines: 5,
 decoration: const InputDecoration(
 labelText: 'Role Definition',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: skillsController,
 minLines: 2,
 maxLines: 4,
 decoration: const InputDecoration(
 labelText: 'Skill Requirements',
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
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () {
 final role = roleController.text.trim();
 final quantity =
 int.tryParse(quantityController.text.trim()) ?? 0;
 if (role.isEmpty || quantity <= 0) {
 return;
 }
 Navigator.of(dialogContext).pop(
 (existing ?? StaffingRow()).copyWith(
 role: role,
 quantity: quantity,
 durationMonths: durationController.text.trim(),
 monthlyCost: monthlyCostController.text.trim(),
 startDate: startDateController.text.trim(),
 roleDescription: descriptionController.text.trim(),
 skillRequirements: skillsController.text.trim(),
 notes: notesController.text.trim(),
 status: status,
 isInternal: isInternal,
 ),
 );
 },
 child: Text(existing == null ? 'Add' : 'Save'),
 ),
 ],
 );
 },
 );
 },
 );

 if (!mounted || result == null) return;
 setState(() {
 final index = _rows.indexWhere((row) => row.id == result.id);
 if (index >= 0) {
 _rows[index] = result;
 } else {
 _rows.add(result);
 }
 });
 _syncRowsToProvider();
 } finally {
 roleController.dispose();
 quantityController.dispose();
 durationController.dispose();
 monthlyCostController.dispose();
 startDateController.dispose();
 descriptionController.dispose();
 skillsController.dispose();
 notesController.dispose();
 }
 }

  Future<void> _deleteRow(StaffingRow row) async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Delete Role',
      itemLabel: row.role.trim(),
    );
    if (!confirmed) return;

 setState(() {
 _rows.removeWhere((item) => item.id == row.id);
 });
 _syncRowsToProvider();
 }

 double get _staffingTotal =>
 _rows.fold<double>(0, (total, row) => total + row.subtotal);

 @override
 Widget build(BuildContext context) {
 return ProgramWorkspaceScaffold(
 body: Stack(
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
 hint: 'Input your notes here…',
 minLines: 3,
 ),
 const SizedBox(height: 22),
 Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 const Expanded(child: _SectionTitle()),
 const SizedBox(width: 12),
 _AddRoleButton(
 onPressed: () => _upsertRow(),
 ),
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: _importFromCsv,
 icon: const Icon(Icons.upload_file_outlined, size: 18),
 label: const Text('Import CSV'),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFFD97706),
 side: const BorderSide(color: const Color(0xFFD97706)),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 ),
 ),
 const SizedBox(width: 8),
 OutlinedButton.icon(
 onPressed: _openRateCardManager,
 icon: const Icon(Icons.attach_money, size: 18),
 label: const Text('Rates'),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF059669),
 side: const BorderSide(color: const Color(0xFF059669)),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 ),
 ),
 ],
 ),
 const SizedBox(height: 14),
 _PersonnelSummary(
 rowCount: _rows.length,
 total: _staffingTotal,
 ),
 const SizedBox(height: 14),
 _PersonnelTable(
 rows: _rows,
 onEdit: (row) => _upsertRow(existing: row),
 onDelete: _deleteRow,
 ),
 const SizedBox(height: 140),
 ],
 ),
 ),
 ),
 ],
 ),
 _BottomOverlays(
 onSubmit: () => WBSModuleScreen.open(context),
 ),
 const KazAiChatBubble(),
 ],
 ),
 );
 }
}

class _SectionTitle extends StatelessWidget {
 const _SectionTitle();

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: const [
 EditableContentText(
 contentKey: 'fep_personnel_title',
 fallback: 'Project Personnel',
 category: 'front_end_planning',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 EditableContentText(
 contentKey: 'fep_personnel_subtitle',
 fallback:
 '(Early identification of core project roles and people ( if known))',
 category: 'front_end_planning',
 style: TextStyle(
 fontSize: 14,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 );
 }
}

class _PersonnelSummary extends StatelessWidget {
 const _PersonnelSummary({required this.rowCount, required this.total});

 final int rowCount;
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
 _summaryMetric('Structured Roles', '$rowCount'),
 const SizedBox(width: 24),
 _summaryMetric('Projected Staffing Cost', _formatCurrency(total)),
 ],
 ),
 );
 }

 Widget _summaryMetric(String label, String value) {
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

class _AddRoleButton extends StatelessWidget {
 const _AddRoleButton({required this.onPressed});

 final VoidCallback onPressed;

 @override
 Widget build(BuildContext context) {
 return SizedBox(
 height: 44,
 child: OutlinedButton(
 onPressed: onPressed,
 style: OutlinedButton.styleFrom(
 backgroundColor: const Color(0xFFF2F4F7),
 foregroundColor: const Color(0xFF111827),
 side: const BorderSide(color: Color(0xFFE5E7EB)),
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
 textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
 ),
 child: const Text('Add a role and description'),
 ),
 );
 }
}

class _PersonnelTable extends StatelessWidget {
 const _PersonnelTable({
 required this.rows,
 required this.onEdit,
 required this.onDelete,
 });

 final List<StaffingRow> rows;
 final ValueChanged<StaffingRow> onEdit;
 final ValueChanged<StaffingRow> onDelete;

 @override
 Widget build(BuildContext context) {
 final border = const BorderSide(color: Color(0xFFE5E7EB));
 final headerStyle = const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF4B5563),
 );
 final cellStyle = const TextStyle(fontSize: 14, color: Color(0xFF111827));

 Widget th(String text) => Padding(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
 child: Center(
 child: Text(
 text,
 style: headerStyle,
 textAlign: TextAlign.center,
 ),
 ),
 );

 Widget td(Widget child) => Padding(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 child: child,
 );

 final tableRows = <TableRow>[
 TableRow(
 decoration: const BoxDecoration(color: Color(0xFFF9FAFB)),
 children: [
 th('No'),
 th('Project Roles'),
 th('Definition'),
 th('Qty'),
 th('Duration'),  th('Monthly Rate'),
 th('Subtotal'),
 th('Type'),
 th('Status'),
 th('Actions'),
 ],
 ),
 ];

 if (rows.isEmpty) {
 tableRows.add(
 TableRow(
 children: [
 td(const SizedBox.shrink()),
 td(
 const Text(
 'No structured personnel roles added yet.',
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
 td(const SizedBox.shrink()),
 td(const SizedBox.shrink()),
 ],
 ),
 );
 } else {
 for (var index = 0; index < rows.length; index++) {
 final row = rows[index];
 tableRows.add(
 TableRow(
 children: [
 td(Text('${index + 1}', style: cellStyle)),
 td(Text(row.role.trim(), style: cellStyle)),
 td(
 Text(
 row.roleDescription.trim().isEmpty
 ? 'No definition provided'
 : row.roleDescription.trim(),
 style: cellStyle,
 ),
 ),
 td(Text('${row.quantity}', style: cellStyle)),
 td(Text(
 row.durationMonths.trim().isEmpty
 ? '-'
 : '${row.durationMonths.trim()} mo',
 style: cellStyle,
 )),
 td(Text(
 row.monthlyCost.trim().isEmpty ? '-' : row.monthlyCost.trim(),
 style: cellStyle,
 )),
 td(Text(_formatCurrency(row.subtotal), style: cellStyle)),
 td(Text(row.isInternal ? 'Internal' : 'External',
 style: cellStyle)),
 td(Text(row.status.trim(), style: cellStyle)),
 td(
 Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 onPressed: () => onEdit(row),
 icon: const Icon(Icons.edit_outlined, size: 18),
 ),
 IconButton(
 onPressed: () => onDelete(row),
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
 constraints.maxWidth > 1400 ? constraints.maxWidth : 1400.0;
 return Scrollbar(
 thumbVisibility: true,
 child: SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: ConstrainedBox(
 constraints: BoxConstraints(minWidth: minTableWidth),
 child: Table(
 columnWidths: const {
 0: FixedColumnWidth(60),
 1: FlexColumnWidth(1.6),
 2: FlexColumnWidth(2.4),
 3: FixedColumnWidth(70),
 4: FixedColumnWidth(90),
 5: FixedColumnWidth(130),
 6: FixedColumnWidth(130),
 7: FixedColumnWidth(90),
 8: FixedColumnWidth(110),
 9: FixedColumnWidth(110),
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
 children: tableRows,
 ),
 ),
 ),
 );
 },
 ),
 );
 }
}

class _BottomOverlays extends StatelessWidget {
 const _BottomOverlays({required this.onSubmit});

 final VoidCallback onSubmit;

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
 child: Container(
 width: 48,
 height: 48,
 decoration: const BoxDecoration(
 color: Color(0xFFB3D9FF),
 shape: BoxShape.circle,
 ),
 child: const Icon(Icons.info_outline, color: Colors.white),
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
 onPressed: onSubmit,
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
 child: const Text(
 'Submit',
 style: TextStyle(
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
 'Capture team shape, sourcing type, and staffing cost assumptions.',
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
