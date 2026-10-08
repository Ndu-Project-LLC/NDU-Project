import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

/// Shared WBS mapping pickers for requirement tables.
///
/// [WbsGoalDropdown] chooses the Level-1 goal (or ALL) a requirement maps to;
/// [WbsElementMultiSelect] chooses the Level-2 elements under that goal.
/// Used by the Planning and Front End Planning requirements tables.

/// WBS Goal (Level 1) dropdown for the requirements table — Lusaka 28.
///
/// Options come from the live WBS tree (top-level codes G1, G2, …), plus an
/// explicit "ALL — Entire project" choice for requirements that span every
/// goal. Selecting a goal scopes the Level-2 element picker beside it.
class WbsGoalDropdown extends StatefulWidget {  const WbsGoalDropdown({
    super.key,

 this.value,
 required this.onChanged,
 this.enabled = true,
 });

 final String? value;
 final ValueChanged<String?> onChanged;
 final bool enabled;

 @override
 State<WbsGoalDropdown> createState() => WbsGoalDropdownState();
}

class WbsGoalDropdownState extends State<WbsGoalDropdown> {
 @override
 Widget build(BuildContext context) {
 final wbs = context.watch<WBSProvider>().wbs;
 final goalOptions = <String>[];
 if (wbs != null) {
 for (final child in wbs.level0.children) {
 final code = child.code.trim();
 if (code.isNotEmpty && !goalOptions.contains(code)) {
 goalOptions.add(code);
 }
 }
 }

 String? coerced = widget.value;
 if (coerced != null &&
     coerced != 'ALL' &&
     !goalOptions.contains(coerced)) {
 coerced = null;
 }

 return Container(
 height: 40,
 padding: const EdgeInsets.symmetric(horizontal: 12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: DropdownButtonHideUnderline(
 child: DropdownButton<String>(
 value: coerced,
 hint: const Text(
 'Select goal…',
 style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
 ),
 icon: const Icon(
 Icons.keyboard_arrow_down_rounded,
 color: Color(0xFF6B7280),
 size: 20,
 ),
 isExpanded: true,
 onChanged: widget.enabled ? (value) => widget.onChanged(value) : null,
 items: [
 const DropdownMenuItem<String>(
 value: 'ALL',
 child: Text(
 'ALL — Entire project',
 style: TextStyle(fontSize: 13),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 for (final goal in goalOptions)
 DropdownMenuItem<String>(
 value: goal,
 child: _goalLabel(context, goal),
 ),
 ],
 ),
 ),
 );
 }

 Widget _goalLabel(BuildContext context, String goal) {
 final wbs = context.watch<WBSProvider>().wbs;
 String name = '';
 if (wbs != null) {
 for (final child in wbs.level0.children) {
 if (child.code.trim() == goal) {
 name = child.name.trim();
 break;
 }
 }
 }
 return Text(
 name.isEmpty ? goal : '$goal — $name',
 style: const TextStyle(fontSize: 13),
 overflow: TextOverflow.ellipsis,
 );
 }
}

/// WBS Elements (Level 2) multi-select for the requirements table — Lusaka 28.
///
/// Shows the Level-2 children of the selected goal (G2.1, G2.4, …). Supports
/// multi-select because a requirement can impact several elements; saving the
/// goal alone with no elements is also valid.
class WbsElementMultiSelect extends StatefulWidget {  const WbsElementMultiSelect({
    super.key,

 required this.goalId,
 required this.selectedIds,
 required this.onChanged,
 this.enabled = true,
 });

 final String? goalId;
 final List<String> selectedIds;
 final ValueChanged<List<String>> onChanged;
 final bool enabled;

 @override
 State<WbsElementMultiSelect> createState() =>
     WbsElementMultiSelectState();
}

class WbsElementMultiSelectState extends State<WbsElementMultiSelect> {
 Future<void> _openPicker() async {
 final wbs = context.read<WBSProvider>().wbs;
 final options = <(String, String)>[]; // (code, name)
 if (wbs != null && (widget.goalId ?? '').isNotEmpty) {
 for (final goal in wbs.level0.children) {
 if (goal.code.trim() != widget.goalId) continue;
 for (final element in goal.children) {
 options.add((element.code.trim(), element.name.trim()));
 }
 break;
 }
 }
 if (!mounted) return;
 if (options.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Select a WBS goal first — its Level-2 elements will appear here.'),
 duration: Duration(seconds: 2),
 ),
 );
 return;
 }

 final result = await showDialog<List<String>>(
 context: context,
 builder: (dialogContext) {
 final draft = List<String>.from(widget.selectedIds);
 return StatefulBuilder(
 builder: (context, setDialogState) => AlertDialog(
 title: Text('WBS Elements under ${widget.goalId}'),
 content: SizedBox(
 width: 420,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 CheckboxListTile(
 dense: true,
 controlAffinity: ListTileControlAffinity.leading,
 value: options.isNotEmpty &&
 options.every((o) => draft.contains(o.$1)),
 onChanged: (checked) {
 setDialogState(() {
 if (checked == true) {
 draft
   ..clear()
   ..addAll(options.map((o) => o.$1));
 } else {
 draft.clear();
 }
 });
 },
 title: const Text('Select all',
 style: TextStyle(fontWeight: FontWeight.w600)),
 ),
 ...options.map(
 (o) => CheckboxListTile(
 dense: true,
 controlAffinity: ListTileControlAffinity.leading,
 value: draft.contains(o.$1),
 title: Text(
 o.$2.isEmpty ? o.$1 : '${o.$1} — ${o.$2}',
 style: const TextStyle(fontSize: 13),
 ),
 onChanged: (checked) {
 setDialogState(() {
 if (checked == true) {
 draft.add(o.$1);
 } else {
 draft.remove(o.$1);
 }
 });
 },
 ),
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(dialogContext, null),
 child: const Text('Cancel'),
 ),
 FilledButton(
 onPressed: () => Navigator.pop(dialogContext, draft),
 child: const Text('Done'),
 ),
 ],
 ),
 );
 },
 );

 if (result != null) {
 widget.onChanged(result);
 }
 }

 @override
 Widget build(BuildContext context) {
 final label = widget.selectedIds.isEmpty
 ? 'Select elements…'
 : widget.selectedIds.join(', ');
 final hasSelection = widget.selectedIds.isNotEmpty;

 return InkWell(
 onTap: widget.enabled ? _openPicker : null,
 borderRadius: BorderRadius.circular(10),
 child: Container(
 height: 40,
 padding: const EdgeInsets.symmetric(horizontal: 12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(
 color: hasSelection
 ? const Color(0xFFFCD34D)
 : const Color(0xFFE5E7EB),
 ),
 ),
 child: Row(
 children: [
 Expanded(
 child: Text(
 label,
 style: TextStyle(
 fontSize: 13,
 color: hasSelection
 ? const Color(0xFF111827)
 : const Color(0xFF9CA3AF),
 ),
 overflow: TextOverflow.ellipsis,
 maxLines: 1,
 ),
 ),
 const Icon(
 Icons.keyboard_arrow_down_rounded,
 color: Color(0xFF6B7280),
 size: 20,
 ),
 ],
 ),
 ),
 );
 }
}
