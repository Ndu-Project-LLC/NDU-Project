import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/responsive.dart';

class SsherSectionCard extends StatelessWidget {
 final IconData leadingIcon;
 final Color accentColor;
 final String title;
 final String subtitle;
 final String detailsPlaceholder;
 final String itemsLabel;
 final String addButtonLabel;
 final List<String> columns;
 final List<List<Widget>> rows; // each inner list is a row of widgets, length must equal columns length
 final VoidCallback? onFullView;
 final VoidCallback? onDownload;
 final VoidCallback? onAdd;

 const SsherSectionCard({
 super.key,
 required this.leadingIcon,
 required this.accentColor,
 required this.title,
 required this.subtitle,
 required this.detailsPlaceholder,
 required this.itemsLabel,
 required this.addButtonLabel,
 required this.columns,
 required this.rows,
 this.onFullView,
 this.onDownload,
 this.onAdd,
 });

 @override
 Widget build(BuildContext context) {
 final headerTint = accentColor.withOpacity(0.08);
 final headerBorder = accentColor.withOpacity(0.12);
 final headerBg = Colors.white;
 final isMobile = AppBreakpoints.isMobile(context);

 return Container(
 margin: const EdgeInsets.only(bottom: 20),
 decoration: BoxDecoration(
 color: headerBg,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: Colors.grey.withOpacity(0.2)),
 boxShadow: [
 BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
 ],
 ),
 child: Column(
 children: [
 // Header
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: BoxDecoration(
 color: headerTint,
 borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
 border: Border(bottom: BorderSide(color: headerBorder)),
 ),
 child: LayoutBuilder(builder: (context, constraints) {
 final isCompact = constraints.maxWidth < 720;

 Widget buildMeta() {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 Container(
 width: 30,
 height: 30,
 decoration: BoxDecoration(color: accentColor.withOpacity(0.15), shape: BoxShape.circle),
 child: Icon(leadingIcon, size: 18, color: accentColor),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey[900])),
 const SizedBox(height: 2),
 Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
 ]),
 ),
 ],
 );
 }

 List<Widget> actionButtons() {
 return [
 _ItemsChip(text: itemsLabel, color: accentColor),
 if (onFullView != null)
 OutlinedButton.icon(
 onPressed: onFullView,
 icon: const Icon(Icons.open_in_new, size: 16),
 label: const Text('Full View'),
 style: OutlinedButton.styleFrom(
 foregroundColor: Colors.blue[700],
 side: BorderSide(color: Colors.blue[300]!),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
 ),
 ),
 if (onDownload != null)
 ElevatedButton.icon(
 onPressed: onDownload,
 icon: const Icon(Icons.download, size: 16),
 label: const Text('Download'),
 style: ElevatedButton.styleFrom(
 backgroundColor: accentColor,
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
 elevation: 0,
 ),
 ),
 ];
 }

 if (isCompact) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 buildMeta(),
 const SizedBox(height: 12),
 Wrap(
 spacing: 12,
 runSpacing: 12,
 crossAxisAlignment: WrapCrossAlignment.center,
 children: actionButtons(),
 ),
 ],
 );
 }

 return Row(
 children: [
 Expanded(child: buildMeta()),
 const SizedBox(width: 12),
 ...actionButtons().expand((widget) => [widget, const SizedBox(width: 10)]).toList()
 ..removeLast(),
 ],
 );
 }),
 ),

 // Details text box
 Container(
 padding: const EdgeInsets.all(16),
 margin: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: Colors.grey.withOpacity(0.25)),
 ),
 child: Text(
 detailsPlaceholder,
 style: TextStyle(fontSize: 13, color: Colors.grey[700]),
 ),
 ),

 // Table
 isMobile
 ? _MobileTable(
 accentColor: accentColor,
 columns: columns,
 rows: rows,
 addButtonLabel: addButtonLabel,
 onAdd: onAdd,
 )
 : Container(
 margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
 decoration: BoxDecoration(
 color: Colors.white,
 border: Border.all(color: Colors.grey.withOpacity(0.25)),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Column(
 children: [
 // header row
 Container(
 decoration: BoxDecoration(
 color: accentColor.withOpacity(0.08),
 borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
 ),
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 child: Row(
 children: [
 for (var i = 0; i < columns.length; i++)
 Expanded(
 child: Align(
 alignment: i == 0
 ? Alignment.center
 : (i == columns.length - 1 ? Alignment.center : Alignment.centerLeft),
 child: Text(
 columns[i],
 style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
 textAlign: i == 0
 ? TextAlign.center
 : (i == columns.length - 1 ? TextAlign.center : TextAlign.left),
 ),
 ),
 ),
 ],
 ),
 ),
 // rows
 for (final r in rows)
 Container(
 decoration: BoxDecoration(
 border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
 ),
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 for (var i = 0; i < r.length; i++)
 Expanded(
 child: Align(
 alignment: i == 0
 ? Alignment.center
 : (i == r.length - 1 ? Alignment.center : Alignment.centerLeft),
 child: r[i],
 ),
 ),
 ],
 ),
 ),
 // add item
 Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
 ),
 child: Align(
 alignment: Alignment.centerLeft,
 child: OutlinedButton.icon(
 onPressed: onAdd,
 icon: const Icon(Icons.add, size: 16),
 label: Text(addButtonLabel),
 style: OutlinedButton.styleFrom(
 foregroundColor: accentColor,
 side: BorderSide(color: accentColor.withOpacity(0.5)),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
 ),
 ),
 ),
 ),
 ],
 ),
 ),

 const SizedBox(height: 16),
 ],
 ),
 );
 }
}

class _ItemsChip extends StatelessWidget {
 final String text;
 final Color color;
 const _ItemsChip({required this.text, required this.color});
 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: color.withOpacity(0.12),
 borderRadius: BorderRadius.circular(16),
 ),
 child: Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
 );
 }
}

class RiskBadge extends StatelessWidget {
 final String level;
 final Color color;
 const RiskBadge.high({super.key})
 : level = 'High',
 color = const Color(0xFFF28B82);
 const RiskBadge.medium({super.key})
 : level = 'Medium',
 color = const Color(0xFFFFC107);
 const RiskBadge.low({super.key})
 : level = 'Low',
 color = const Color(0xFF66BB6A);

 @override
 Widget build(BuildContext context) {
 return Container(
 height: 28,
 alignment: Alignment.center,
 margin: const EdgeInsets.only(right: 8),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: color.withOpacity(0.25),
 borderRadius: BorderRadius.circular(16),
 ),
 child: Text(level, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
 );
 }
}

class ActionButtons extends StatelessWidget {
 final VoidCallback? onEdit;
 final VoidCallback? onDelete;
 
 const ActionButtons({super.key, this.onEdit, this.onDelete});
 
 @override
 Widget build(BuildContext context) {
 return Row(
 children: [
 InkWell(
 onTap: onEdit,
 child: const Padding(
 padding: EdgeInsets.all(4.0),
 child: Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
 ),
 ),
 const SizedBox(width: 6),
 InkWell(
 onTap: onDelete,
 child: const Padding(
 padding: EdgeInsets.all(4.0),
 child: Icon(Icons.delete_outline, color: Colors.red, size: 20),
 ),
 ),
 ],
 );
 }
}

class _MobileTable extends StatelessWidget {
 final Color accentColor;
 final List<String> columns;
 final List<List<Widget>> rows;
 final String addButtonLabel;
 final VoidCallback? onAdd;
 const _MobileTable({
 required this.accentColor,
 required this.columns,
 required this.rows,
 required this.addButtonLabel,
 this.onAdd,
 });

 @override
 Widget build(BuildContext context) {
 return Container(
 margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
 decoration: BoxDecoration(
 color: Colors.white,
 border: Border.all(color: Colors.grey.withOpacity(0.25)),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Column(
 children: [
 for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
 Column(
 children: [
 if (rowIndex != 0)
 Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 for (var i = 0; i < columns.length; i++)
 Padding(
 padding: EdgeInsets.only(bottom: i == columns.length - 1 ? 0 : 12),
 child: _MobileCell(label: columns[i], child: rows[rowIndex][i]),
 ),
 ],
 ),
 ),
 ],
 ),
 Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
 Container(
 padding: const EdgeInsets.all(14),
 decoration: const BoxDecoration(
 borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
 ),
 child: Align(
 alignment: Alignment.centerLeft,
 child: OutlinedButton.icon(
 onPressed: onAdd,
 icon: const Icon(Icons.add, size: 16),
 label: Text(addButtonLabel),
 style: OutlinedButton.styleFrom(
 foregroundColor: accentColor,
 side: BorderSide(color: accentColor.withOpacity(0.5)),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
 ),
 ),
 ),
 ),
 ],
 ),
 );
 }
}

class _MobileCell extends StatelessWidget {
 final String label;
 final Widget child;
 const _MobileCell({required this.label, required this.child});

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
 const SizedBox(height: 4),
 DefaultTextStyle.merge(
 style: const TextStyle(fontSize: 13),
 child: child,
 ),
 ],
 );
 }
}
