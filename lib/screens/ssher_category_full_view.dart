import 'package:flutter/material.dart';
import 'package:ndu_project/screens/ssher_components.dart';
import 'package:ndu_project/screens/ssher_add_safety_item_dialog.dart';
import 'package:ndu_project/models/project_data_model.dart';

class SsherCategoryFullView extends StatefulWidget {
 final String title;
 final String subtitle;
 final IconData icon;
 final Color accentColor;
 final String detailsText;
 final List<String> columns;
 final List<SsherEntry> entries;
 final Function(SsherItemInput) onAddItem;
 final Function(SsherEntry) onEditItem;
 final Function(SsherEntry) onDeleteItem;
 final VoidCallback onDownload;
 final String addButtonLabel;
 final String concernLabel; // For the dialog
 final bool allowCsv;

 const SsherCategoryFullView({
 super.key,
 required this.title,
 required this.subtitle,
 required this.icon,
 required this.accentColor,
 required this.detailsText,
 required this.columns,
 required this.entries,
 required this.onAddItem,
 required this.onEditItem,
 required this.onDeleteItem,
 required this.onDownload,
 required this.addButtonLabel,
 required this.concernLabel,
 required this.allowCsv,
 });

 @override
 State<SsherCategoryFullView> createState() => _SsherCategoryFullViewState();
}

class _SsherCategoryFullViewState extends State<SsherCategoryFullView> {

 List<Widget> _buildRowForEntry(int index, SsherEntry entry) {
 Widget risk;
 switch (entry.riskLevel) {
 case 'Low':
 risk = const RiskBadge.low();
 break;
 case 'Medium':
 risk = const RiskBadge.medium();
 break;
 default:
 risk = const RiskBadge.high();
 }

 // Assumes standard columns for now: #, Department, Team Member, Concern, Risk, Mitigation, Actions
 // If columns vary significantly per section, we might need a more dynamic row builder or just standardized columns.
 return [
 Text('$index', style: const TextStyle(fontSize: 12)),
 Text(entry.department, style: const TextStyle(fontSize: 13)),
 Text(entry.teamMember, style: const TextStyle(fontSize: 13)),
 Text(entry.concern, style: const TextStyle(fontSize: 13, color: Colors.black87), overflow: TextOverflow.ellipsis),
 risk,
 Text(entry.mitigation, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
 ActionButtons(
 onEdit: () => widget.onEditItem(entry),
 onDelete: () => widget.onDeleteItem(entry),
 ),
 ];
 }


 Future<void> _handleAddItem() async {
 final result = await showDialog<SsherItemInput>(
 context: context,
 builder: (ctx) => AddSsherItemDialog(
 accentColor: widget.accentColor,
 icon: widget.icon,
 heading: widget.addButtonLabel,
 blurb: 'Provide details for the new record.',
 concernLabel: widget.concernLabel,
 ),
 );
 if (result == null) return;
 widget.onAddItem(result);
 }

 @override
 Widget build(BuildContext context) {
 final countText = '${widget.entries.length} items';
 
 // Convert entries to rows of widgets
 final rows = widget.entries.asMap().entries.map((e) {
 return _buildRowForEntry(e.key + 1, e.value);
 }).toList();

 return LayoutBuilder(builder: (context, constraints) {
 return SingleChildScrollView(
 padding: const EdgeInsets.all(20),
 child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: Colors.grey.withOpacity(0.2)),
 ),
 child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(color: widget.accentColor.withOpacity(0.15), shape: BoxShape.circle),
 child: Icon(widget.icon, color: widget.accentColor, size: 20),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
 const SizedBox(height: 4),
 Text(widget.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
 ]),
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(color: widget.accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
 child: Text(countText, style: TextStyle(fontSize: 12, color: widget.accentColor, fontWeight: FontWeight.w600)),
 ),
 const SizedBox(width: 10),
 ElevatedButton.icon(
 onPressed: widget.onDownload,
 icon: Icon(widget.allowCsv ? Icons.download : Icons.picture_as_pdf, size: 16),
 label: Text(widget.allowCsv ? 'Download CSV' : 'Download PDF'),
 style: ElevatedButton.styleFrom(
 backgroundColor: widget.accentColor,
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
 elevation: 0,
 ),
 ),
 ]),
 ),
 const SizedBox(height: 16),
 if (widget.detailsText.isNotEmpty) ...[
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: Colors.grey.withOpacity(0.25)),
 ),
 child: Text(widget.detailsText, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
 ),
 const SizedBox(height: 16),
 ],
 // Table
 Container(
 decoration: BoxDecoration(
 color: Colors.white,
 border: Border.all(color: Colors.grey.withOpacity(0.25)),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Column(children: [
 Container(
 decoration: BoxDecoration(color: widget.accentColor.withOpacity(0.08), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 child: Row(children: [
 for (var i = 0; i < widget.columns.length; i++)
 Expanded(
 child: Align(
 alignment: i == 0
 ? Alignment.center
 : (i == widget.columns.length - 1 ? Alignment.center : Alignment.centerLeft),
 child: Text(
 widget.columns[i],
 style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
 textAlign: i == 0
 ? TextAlign.center
 : (i == widget.columns.length - 1 ? TextAlign.center : TextAlign.left),
 ),
 ),
 ),
 ]),
 ),
 for (int idx = 0; idx < rows.length; idx++)
 Container(
 decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2)))),
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
 child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
 for (var i = 0; i < rows[idx].length; i++)
 Expanded(
 child: Align(
 alignment: i == 0
 ? Alignment.center
 : (i == rows[idx].length - 1 ? Alignment.center : Alignment.centerLeft),
 child: rows[idx][i],
 ),
 ),
 ]),
 ),
 Container(
 padding: const EdgeInsets.all(14),
 decoration: const BoxDecoration(borderRadius: BorderRadius.vertical(bottom: Radius.circular(10))),
 alignment: Alignment.centerLeft,
 child: OutlinedButton.icon(
 onPressed: _handleAddItem,
 icon: const Icon(Icons.add, size: 16),
 label: Text(widget.addButtonLabel),
 style: OutlinedButton.styleFrom(
 foregroundColor: widget.accentColor,
 side: BorderSide(color: widget.accentColor.withOpacity(0.5)),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
 ),
 ),
 ),
 ]),
 ),
 ]),
 );
 });
 }
}
