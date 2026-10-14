import 'package:ndu_project/widgets/expanding_text_field.dart';
import 'package:flutter/material.dart';

import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/spell_check/spell_checking_text_controller.dart';
class SsherItemInput {
 final String department;
 final String teamMember;
 final String concern;
 final String riskLevel; // 'Low' | 'Medium' | 'High'
 final String mitigation;

 /// Whether meeting this item means buying something for the project. Only
 /// these become cost lines (Lusaka 25 (copy): "if it says PPE required, just
 /// have a question on the cost for that … if it's something that needs to be
 /// bought for the project").
 final bool requiresPurchase;

 /// The assessor's rough amount for that purchase. Blank when unknown.
 final String estimatedCost;

 SsherItemInput({
 required this.department,
 required this.teamMember,
 required this.concern,
 required this.riskLevel,
 required this.mitigation,
 this.requiresPurchase = false,
 this.estimatedCost = '',
 });
}

class AddSsherItemDialog extends StatefulWidget {
 final Color accentColor;
 final IconData icon;
 final String heading;
 final String blurb;
 final String concernLabel;
 final String mitigationLabel;
 final String departmentLabel;
 final String teamMemberLabel;
 final String riskLevelLabel;
 final String saveButtonLabel;
 final List<String> departmentOptions;

 /// Options for the Team Member dropdown. When null the dialog builds them
 /// from the project's own team (team members, staffing plan, project roles).
 final List<String>? teamMemberOptions;

 final SsherItemInput? initialData;

 const AddSsherItemDialog({
 super.key,
 required this.accentColor,
 required this.icon,
 required this.heading,
 required this.blurb,
 required this.concernLabel,
 this.mitigationLabel = 'Mitigation Strategy',
 this.departmentLabel = 'Department',
 this.teamMemberLabel = 'Team Member',
 this.riskLevelLabel = 'Risk Level',
 this.saveButtonLabel = 'Save Item',
 this.departmentOptions = const [
 'Operations',
 'Manufacturing',
 'Logistics',
 'HR',
 'Maintenance',
 'IT Security',
 'Compliance',
 'Facilities',
 'Sustainability',
 'Energy',
 'Data Governance',
 ],
 this.teamMemberOptions,
 this.initialData,
 });

 @override
 State<AddSsherItemDialog> createState() => _AddSsherItemDialogState();
}

class _AddSsherItemDialogState extends State<AddSsherItemDialog> {
 final _formKey = GlobalKey<FormState>();
 late TextEditingController _concernCtrl;
 late TextEditingController _mitigationCtrl;
 late TextEditingController _costCtrl;
 late String _department;
 late String _riskLevel;
 late String _teamMember;
 late bool _requiresPurchase;
 List<String> _teamMemberOptions = const [];
 bool _teamMemberOptionsResolved = false;

 @override
 void initState() {
 super.initState();
 _teamMember = widget.initialData?.teamMember.trim() ?? '';
 _concernCtrl = SpellCheckTextEditingController(text: widget.initialData?.concern ?? '');
 _mitigationCtrl = SpellCheckTextEditingController(text: widget.initialData?.mitigation ?? '');
 _department = widget.initialData?.department ?? 'Operations';
 _riskLevel = widget.initialData?.riskLevel ?? 'High';
 _requiresPurchase = widget.initialData?.requiresPurchase ?? false;
 _costCtrl =
 SpellCheckTextEditingController(text: widget.initialData?.estimatedCost ?? '');

 if (!widget.departmentOptions.contains(_department)) {
 _department = widget.departmentOptions.first;
 }
 }

 @override
 void didChangeDependencies() {
 super.didChangeDependencies();
 if (_teamMemberOptionsResolved) return;
 _teamMemberOptionsResolved = true;
 _teamMemberOptions = _resolveTeamMemberOptions();
 }

 /// Options shown in the Team Member dropdown.
 ///
 /// Team members come first, then people named on the staffing plan, then
 /// project role titles — so the picker reflects who is actually on the
 /// project. A value already saved on the row is always kept selectable, and
 /// the list is never empty.
 List<String> _resolveTeamMemberOptions() {
 final provided = widget.teamMemberOptions;
 final options = <String>{};

 if (provided != null) {
 options.addAll(provided.map((o) => o.trim()).where((o) => o.isNotEmpty));
 } else {
 final data = ProjectDataHelper.getData(context);
 for (final member in data.teamMembers) {
 final name = member.name.trim().isNotEmpty
 ? member.name.trim()
 : member.email.trim();
 if (name.isNotEmpty) options.add(name);
 }
 for (final row in data.staffingRequirements) {
 final name = row.personName.trim();
 if (name.isNotEmpty) options.add(name);
 final title = row.title.trim();
 if (title.isNotEmpty) options.add(title);
 }
 for (final role in data.projectRoles) {
 final title = role.title.trim();
 if (title.isNotEmpty) options.add(title);
 }
 }

 final current = _teamMember.trim();
 if (current.isNotEmpty) options.add(current);
 if (options.isEmpty) options.add('Unassigned');

 return options.toList(growable: false);
 }

 @override
 void dispose() {
 _concernCtrl.dispose();
 _mitigationCtrl.dispose();
 _costCtrl.dispose();
 super.dispose();
 }

 InputDecoration _inputDecoration(String label, ThemeData theme, ColorScheme colorScheme) {
 final borderRadius = BorderRadius.circular(12);
 final outlineColor = colorScheme.outline.withValues(alpha: theme.brightness == Brightness.light ? 0.2 : 0.4);
 final labelStyle = theme.textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant);

 return InputDecoration(
 labelText: label,
 labelStyle: labelStyle,
 filled: true,
 fillColor: Color.alphaBlend(colorScheme.primary.withValues(alpha: 0.04), colorScheme.surfaceContainerHighest.withValues(alpha: theme.brightness == Brightness.light ? 0.65 : 0.35)),
 border: OutlineInputBorder(borderRadius: borderRadius, borderSide: BorderSide(color: outlineColor)),
 enabledBorder: OutlineInputBorder(borderRadius: borderRadius, borderSide: BorderSide(color: outlineColor)),
 focusedBorder: OutlineInputBorder(borderRadius: borderRadius, borderSide: BorderSide(color: widget.accentColor, width: 1.5)),
 contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
 );
 }

 @override
 Widget build(BuildContext context) {
 final theme = Theme.of(context);
 final colorScheme = theme.colorScheme;

 final dialog = Dialog(
 insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
 backgroundColor: colorScheme.surface,
 surfaceTintColor: colorScheme.surfaceTint,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 720),
 child: Padding(
 padding: const EdgeInsets.all(20),
 // The dialog gained the purchase/cost question, so on a short viewport it
 // has to scroll rather than overflow.
 child: SingleChildScrollView(
 child: Form(
 key: _formKey,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(children: [
 Container(
 width: 40,
 height: 40,
 decoration: BoxDecoration(color: widget.accentColor.withValues(alpha: 0.12), shape: BoxShape.circle),
 child: Icon(widget.icon, color: widget.accentColor, size: 22),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Text(
 widget.heading,
 style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: colorScheme.onSurface),
 ),
 ),
 IconButton(
 icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
 tooltip: 'Close',
 onPressed: () => Navigator.pop(context),
 ),
 ]),
 const SizedBox(height: 16),
 Text(
 widget.blurb,
 style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
 ),
 const SizedBox(height: 16),

 // Grid-like form
 LayoutBuilder(builder: (context, constraints) {
 final isNarrow = constraints.maxWidth < 600;
 return Column(children: [
 isNarrow
 ? Column(children: _row1(theme, colorScheme))
 : Row(children: _row1(theme, colorScheme)),
 const SizedBox(height: 12),
 ExpandingTextFormField(
 controller: _concernCtrl,
 minLines: 3,
 decoration: _inputDecoration(widget.concernLabel, theme, colorScheme),
 style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
 validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
 ),
 const SizedBox(height: 12),
 ExpandingTextFormField(
 controller: _mitigationCtrl,
 minLines: 3,
 decoration: _inputDecoration(widget.mitigationLabel, theme, colorScheme),
 style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
 validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
 ),
 const SizedBox(height: 12),
 // Every SSHER item must state whether it costs money, so the cost can be
 // carried into the Cost Estimate instead of being guessed at later.
 Row(
 children: [
 Checkbox(
 value: _requiresPurchase,
 visualDensity: VisualDensity.compact,
 onChanged: (v) =>
 setState(() => _requiresPurchase = v == true),
 ),
 Expanded(
 child: Tooltip(
 message: 'Tick this if meeting the item means buying something — then '
 'give an estimated cost so it reaches the Cost Estimate.',
 child: Text(
 'Requires a purchase (adds a cost to the estimate)',
 style: theme.textTheme.bodyMedium
 ?.copyWith(color: colorScheme.onSurface),
 ),
 ),
 ),
 const SizedBox(width: 12),
 SizedBox(
 width: 190,
 child: TextFormField(
 controller: _costCtrl,
 enabled: _requiresPurchase,
 keyboardType: const TextInputType.numberWithOptions(decimal: true),
 decoration:
 _inputDecoration('Estimated cost', theme, colorScheme),
 style: theme.textTheme.bodyMedium
 ?.copyWith(color: colorScheme.onSurface),
 validator: (v) {
 if (!_requiresPurchase) return null;
 final cleaned =
 (v ?? '').replaceAll(RegExp(r'[^0-9.]'), '');
 if (cleaned.isEmpty || (double.tryParse(cleaned) ?? 0) <= 0) {
 return 'Enter an amount';
 }
 return null;
 },
 ),
 ),
 ],
 ),
 ]);
 }),

 const SizedBox(height: 20),
 Row(children: [
 OutlinedButton(
 onPressed: () => Navigator.pop(context),
 style: OutlinedButton.styleFrom(
 foregroundColor: colorScheme.onSurfaceVariant,
 side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.4)),
 padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 child: const Text('Cancel'),
 ),
 const SizedBox(width: 12),
 ElevatedButton.icon(
 onPressed: _save,
 icon: const Icon(Icons.check, size: 18),
 label: Text(widget.saveButtonLabel),
 style: ElevatedButton.styleFrom(
 backgroundColor: widget.accentColor,
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 elevation: 1,
 ),
 ),
 ]),
 ],
 ),
 ),
 ),
 ),
 ),
 );

 return dialog;
 }

 List<Widget> _row1(ThemeData theme, ColorScheme colorScheme) {
 return [
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue: _department,
 isExpanded: true,
 items: [
 for (final option in widget.departmentOptions)
 DropdownMenuItem(value: option, child: Text(option, overflow: TextOverflow.ellipsis)),
 ],
 onChanged: (v) => setState(() => _department = v ?? _department),
 decoration: _inputDecoration(widget.departmentLabel, theme, colorScheme),
 dropdownColor: colorScheme.surface,
 style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue: _teamMember.isEmpty ? null : _teamMember,
 isExpanded: true,
 items: [
 for (final option in _teamMemberOptions)
 DropdownMenuItem(value: option, child: Text(option, overflow: TextOverflow.ellipsis)),
 ],
 onChanged: (v) => setState(() => _teamMember = v ?? _teamMember),
 decoration: _inputDecoration(widget.teamMemberLabel, theme, colorScheme),
 dropdownColor: colorScheme.surface,
 style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
 validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue: _riskLevel,
 isExpanded: true,
 items: const [
 DropdownMenuItem(value: 'Low', child: Text('Low', overflow: TextOverflow.ellipsis)),
 DropdownMenuItem(value: 'Medium', child: Text('Medium', overflow: TextOverflow.ellipsis)),
 DropdownMenuItem(value: 'High', child: Text('High', overflow: TextOverflow.ellipsis)),
 ],
 onChanged: (v) => setState(() => _riskLevel = v ?? _riskLevel),
 decoration: _inputDecoration(widget.riskLevelLabel, theme, colorScheme),
 dropdownColor: colorScheme.surface,
 style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
 ),
 ),
 ];
 }

 void _save() {
 if (!_formKey.currentState!.validate()) return;
 Navigator.pop(
 context,
 SsherItemInput(
 department: _department,
 teamMember: _teamMember.trim(),
 concern: _concernCtrl.text.trim(),
 riskLevel: _riskLevel,
 mitigation: _mitigationCtrl.text.trim(),
 requiresPurchase: _requiresPurchase,
 estimatedCost: _requiresPurchase ? _costCtrl.text.trim() : '',
 ),
 );
 }
}
