import 'package:flutter/material.dart';
import 'package:ndu_project/screens/ssher_components.dart';
import 'package:ndu_project/screens/ssher_add_safety_item_dialog.dart';

class SafetyFullViewScreen extends StatefulWidget {
 final List<String> columns;
 final List<List<Widget>> initialRows;
 final Color accentColor;
 final String detailsText;
 final void Function(SsherItemInput input)? onAddItem;

 const SafetyFullViewScreen({
 super.key,
 required this.columns,
 required this.initialRows,
 required this.accentColor,
 required this.detailsText,
 this.onAddItem,
 });

 /// Opens the full-view screen with the default safety data used across the SSHER flow.
 static Future<void> openDefault(BuildContext context) {
 const accent = Color(0xFF34A853);
 const columns = ['#', 'Department', 'Team Member', 'Safety Concern', 'Risk Level', 'Mitigation Strategy', 'Actions'];
 // Start with no default rows in full view as well.
 final rows = <List<Widget>>[];

 return Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => SafetyFullViewScreen(
 columns: columns,
 initialRows: rows,
 accentColor: accent,
 detailsText: '',
 ),
 ),
 );
 }

 @override
 State<SafetyFullViewScreen> createState() => _SafetyFullViewScreenState();
}

class _SafetyFullViewScreenState extends State<SafetyFullViewScreen> {
 late List<List<Widget>> _rows;

 @override
 void initState() {
 super.initState();
 _rows = List<List<Widget>>.from(widget.initialRows);
 }

 List<Widget> _rowFromInput({required int index, required SsherItemInput input}) {
 Widget risk;
 switch (input.riskLevel) {
 case 'Low':
 risk = const RiskBadge.low();
 break;
 case 'Medium':
 risk = const RiskBadge.medium();
 break;
 default:
 risk = const RiskBadge.high();
 }

 return [
 Text('$index', style: const TextStyle(fontSize: 12)),
 Text(input.department, style: const TextStyle(fontSize: 13)),
 Text(input.teamMember, style: const TextStyle(fontSize: 13)),
 Text(input.concern, style: const TextStyle(fontSize: 13, color: Colors.black87), overflow: TextOverflow.ellipsis),
 risk,
 Text(input.mitigation, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
 const ActionButtons(),
 ];
 }

 Future<void> _addItem() async {
 final result = await showDialog<SsherItemInput>(
 context: context,
 builder: (ctx) => AddSsherItemDialog(
 accentColor: widget.accentColor,
 icon: Icons.health_and_safety,
 heading: 'Add Safety Item',
 blurb: 'Provide details for the new safety record. Make sure risk level and mitigation strategy are accurate.',
 concernLabel: 'Safety Concern',
 ),
 );
 if (result == null) return;
 final nextIndex = _rows.length + 1;
 setState(() => _rows.add(_rowFromInput(index: nextIndex, input: result)));
 widget.onAddItem?.call(result);
 }

 @override
 Widget build(BuildContext context) {
 final countText = '${_rows.length} items';
 return Scaffold(
 backgroundColor: Colors.grey[50],
 appBar: AppBar(
 elevation: 0,
 backgroundColor: Colors.white,
 leading: IconButton(icon: const Icon(Icons.arrow_back_ios, size: 16), onPressed: () => Navigator.pop(context)),
 title: const Text('Safety - Full View', style: TextStyle(fontWeight: FontWeight.w700)),
 ),
 body: LayoutBuilder(builder: (context, constraints) {
 return SingleChildScrollView(
 padding: const EdgeInsets.all(20),
 child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
 ),
 child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(color: widget.accentColor.withValues(alpha: 0.15), shape: BoxShape.circle),
 child: Icon(Icons.health_and_safety, color: widget.accentColor, size: 20),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 const Text('Safety', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
 const SizedBox(height: 4),
 Text('Workplace safety protocols and risk management', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
 ]),
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(color: widget.accentColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
 child: Text(countText, style: TextStyle(fontSize: 12, color: widget.accentColor, fontWeight: FontWeight.w600)),
 ),
 const SizedBox(width: 10),
 ElevatedButton.icon(
 onPressed: () {},
 icon: const Icon(Icons.download, size: 16),
 label: const Text('Download'),
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
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
 ),
 child: Text(widget.detailsText, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
 ),
 const SizedBox(height: 16),
 // Table with optional horizontal scrolling
 Container(
 decoration: BoxDecoration(
 color: Colors.white,
 border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Column(children: [
 Container(
 decoration: BoxDecoration(color: widget.accentColor.withValues(alpha: 0.08), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
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
 for (int idx = 0; idx < _rows.length; idx++)
 Container(
 decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)))),
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
 child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
 for (var i = 0; i < _rows[idx].length; i++)
 Expanded(
 child: Align(
 alignment: i == 0
 ? Alignment.center
 : (i == _rows[idx].length - 1 ? Alignment.center : Alignment.centerLeft),
 child: _rows[idx][i],
 ),
 ),
 ]),
 ),
 Container(
 padding: const EdgeInsets.all(14),
 decoration: const BoxDecoration(borderRadius: BorderRadius.vertical(bottom: Radius.circular(10))),
 alignment: Alignment.centerLeft,
 child: OutlinedButton.icon(
 onPressed: _addItem,
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add Safety Item'),
 style: OutlinedButton.styleFrom(
 foregroundColor: widget.accentColor,
 side: BorderSide(color: widget.accentColor.withValues(alpha: 0.5)),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
 ),
 ),
 ),
 ]),
 ),
 ]),
 );
 }),
 );
 }
}
