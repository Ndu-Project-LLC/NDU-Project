import 'package:ndu_project/widgets/expanding_text_field.dart';
import 'package:flutter/material.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/models/staffing_row.dart';

class SsherItemInput {
  final String department;
  final String teamMember;
  final String concern;
  final String riskLevel; // 'Low' | 'Medium' | 'High'
  final String mitigation;
  final String estimatedCost;
  final String costCurrency;
  final String costFrequency;
  final String costUnit;
  final List<String> linkedRiskIds;
  final List<String> linkedStaffingRoleIds;
  final List<String> linkedRequirementIds;
  final String notes;

  SsherItemInput({
    required this.department,
    required this.teamMember,
    required this.concern,
    required this.riskLevel,
    required this.mitigation,
    this.estimatedCost = '',
    this.costCurrency = 'USD',
    this.costFrequency = 'One-time',
    this.costUnit = 'lump sum',
    List<String>? linkedRiskIds,
    List<String>? linkedStaffingRoleIds,
    List<String>? linkedRequirementIds,
    this.notes = '',
  })  : linkedRiskIds = linkedRiskIds ?? [],
        linkedStaffingRoleIds = linkedStaffingRoleIds ?? [],
        linkedRequirementIds = linkedRequirementIds ?? [];
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
  final SsherItemInput? initialData;

  // Integration sources (for multi-select chips)
  final List<RiskRegisterItem> riskRegisterItems;
  final List<StaffingRow> staffingRows;
  final List<RequirementItem> requirementItems;

  const AddSsherItemDialog({
    super.key,
    required this.accentColor,
    required this.icon,
    required this.heading,
    required this.blurb,
    required this.concernLabel,
    this.mitigationLabel = 'Mitigation Strategy',
    this.departmentLabel = 'Department',
    this.teamMemberLabel = 'Team Member / Owner',
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
      'Health & Safety',
      'Environmental',
      'Regulatory Affairs',
      'Security',
    ],
    this.initialData,
    this.riskRegisterItems = const [],
    this.staffingRows = const [],
    this.requirementItems = const [],
  });

  @override
  State<AddSsherItemDialog> createState() => _AddSsherItemDialogState();
}

class _AddSsherItemDialogState extends State<AddSsherItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  late TextEditingController _memberCtrl;
  late TextEditingController _concernCtrl;
  late TextEditingController _mitigationCtrl;
  late TextEditingController _costCtrl;
  late TextEditingController _notesCtrl;
  late String _department;
  late String _riskLevel;
  late String _costCurrency;
  late String _costFrequency;
  late String _costUnit;
  late List<String> _selectedRiskIds;
  late List<String> _selectedStaffingIds;
  late List<String> _selectedRequirementIds;
  bool _showIntegrations = false;

  late TextEditingController _costUnitCtrl;

  @override
  void initState() {
    super.initState();
    _memberCtrl = TextEditingController(text: widget.initialData?.teamMember ?? '');
    _concernCtrl = TextEditingController(text: widget.initialData?.concern ?? '');
    _mitigationCtrl = TextEditingController(text: widget.initialData?.mitigation ?? '');
    _costCtrl = TextEditingController(text: widget.initialData?.estimatedCost ?? '');
    _notesCtrl = TextEditingController(text: widget.initialData?.notes ?? '');
    _costUnitCtrl = TextEditingController(text: widget.initialData?.costUnit ?? 'lump sum');
    _department = widget.initialData?.department ?? 'Operations';
    _riskLevel = widget.initialData?.riskLevel ?? 'High';
    _costCurrency = widget.initialData?.costCurrency ?? 'USD';
    _costFrequency = widget.initialData?.costFrequency ?? 'One-time';
    _costUnit = widget.initialData?.costUnit ?? 'lump sum';
    _selectedRiskIds = List<String>.from(widget.initialData?.linkedRiskIds ?? []);
    _selectedStaffingIds = List<String>.from(widget.initialData?.linkedStaffingRoleIds ?? []);
    _selectedRequirementIds = List<String>.from(widget.initialData?.linkedRequirementIds ?? []);

    if (!widget.departmentOptions.contains(_department)) {
      _department = widget.departmentOptions.first;
    }
  }

  @override
  void dispose() {
    _memberCtrl.dispose();
    _concernCtrl.dispose();
    _mitigationCtrl.dispose();
    _costCtrl.dispose();
    _notesCtrl.dispose();
    _costUnitCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label, ThemeData theme, ColorScheme colorScheme) {
    final borderRadius = BorderRadius.circular(12);
    final outlineColor = colorScheme.outline.withOpacity(theme.brightness == Brightness.light ? 0.2 : 0.4);
    final labelStyle = theme.textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant);

    return InputDecoration(
      labelText: label,
      labelStyle: labelStyle,
      filled: true,
      fillColor: Color.alphaBlend(colorScheme.primary.withOpacity(0.04), colorScheme.surfaceContainerHighest.withOpacity(theme.brightness == Brightness.light ? 0.65 : 0.35)),
      border: OutlineInputBorder(borderRadius: borderRadius, borderSide: BorderSide(color: outlineColor)),
      enabledBorder: OutlineInputBorder(borderRadius: borderRadius, borderSide: BorderSide(color: outlineColor)),
      focusedBorder: OutlineInputBorder(borderRadius: borderRadius, borderSide: BorderSide(color: widget.accentColor, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _sectionLabel(String text, ColorScheme colorScheme) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.05,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );

  Widget _integrationChip({
    required String label,
    required String subtitle,
    required bool selected,
    required ValueChanged<bool> onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: FilterChip(
        label: Text(
          subtitle.isEmpty ? label : '$label — $subtitle',
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : Colors.grey[800],
          ),
        ),
        selected: selected,
        onSelected: onTap,
        selectedColor: widget.accentColor,
        backgroundColor: Colors.grey[100],
        side: BorderSide(color: Colors.grey[300]!),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
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
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 900),
        child: Padding(
          padding: const EdgeInsets.all(20),
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
                    decoration: BoxDecoration(color: widget.accentColor.withOpacity(0.12), shape: BoxShape.circle),
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

                Flexible(
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: Department, Owner, Risk Level
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
                            ]);
                          }),

                          // Cost section
                          _sectionLabel('Estimated Cost for this SSHER Element', colorScheme),
                          LayoutBuilder(builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 600;
                            final children = _costRow(theme, colorScheme);
                            return isNarrow
                                ? Column(children: children)
                                : Row(children: children);
                          }),

                          // Notes / logs
                          const SizedBox(height: 12),
                          ExpandingTextFormField(
                            controller: _notesCtrl,
                            minLines: 2,
                            decoration: _inputDecoration('Notes / Additional Logs', theme, colorScheme),
                            style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
                          ),

                          // Integrations (collapsible)
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () => setState(() => _showIntegrations = !_showIntegrations),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: widget.accentColor.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: widget.accentColor.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.link, size: 16, color: widget.accentColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Cross-Discipline Integration (${_selectedRiskIds.length + _selectedStaffingIds.length + _selectedRequirementIds.length} linked)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: widget.accentColor,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    _showIntegrations ? Icons.expand_less : Icons.expand_more,
                                    color: widget.accentColor,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_showIntegrations) ...[
                            const SizedBox(height: 12),
                            // Risk Register linkage
                            if (widget.riskRegisterItems.isNotEmpty) ...[
                              _sectionLabel('Linked Risk Register Items', colorScheme),
                              Wrap(
                                children: widget.riskRegisterItems.asMap().entries.map((entry) {
                                  final r = entry.value;
                                  final key = r.riskName.isNotEmpty ? r.riskName : 'Risk ${entry.key + 1}';
                                  final selected = _selectedRiskIds.contains(key);
                                  return _integrationChip(
                                    label: key,
                                    subtitle: r.impactLevel,
                                    selected: selected,
                                    onTap: (v) => setState(() {
                                      if (v) {
                                        _selectedRiskIds.add(key);
                                      } else {
                                        _selectedRiskIds.remove(key);
                                      }
                                    }),
                                  );
                                }).toList(),
                              ),
                            ],
                            // Staffing Plan linkage
                            if (widget.staffingRows.isNotEmpty) ...[
                              _sectionLabel('Linked Staffing Plan Roles', colorScheme),
                              Wrap(
                                children: widget.staffingRows.map((s) {
                                  final selected = _selectedStaffingIds.contains(s.id);
                                  return _integrationChip(
                                    label: s.role.isNotEmpty ? s.role : 'Role ${s.id.substring(0, 4)}',
                                    subtitle: s.personName,
                                    selected: selected,
                                    onTap: (v) => setState(() {
                                      if (v) {
                                        _selectedStaffingIds.add(s.id);
                                      } else {
                                        _selectedStaffingIds.remove(s.id);
                                      }
                                    }),
                                  );
                                }).toList(),
                              ),
                            ],
                            // Requirements linkage
                            if (widget.requirementItems.isNotEmpty) ...[
                              _sectionLabel('Linked Requirements', colorScheme),
                              Wrap(
                                children: widget.requirementItems.map((r) {
                                  final selected = _selectedRequirementIds.contains(r.id);
                                  return _integrationChip(
                                    label: r.description.isNotEmpty
                                        ? (r.description.length > 40
                                            ? '${r.description.substring(0, 40)}...'
                                            : r.description)
                                        : 'Req ${r.id.substring(0, 4)}',
                                    subtitle: r.requirementType,
                                    selected: selected,
                                    onTap: (v) => setState(() {
                                      if (v) {
                                        _selectedRequirementIds.add(r.id);
                                      } else {
                                        _selectedRequirementIds.remove(r.id);
                                      }
                                    }),
                                  );
                                }).toList(),
                              ),
                            ],
                            if (widget.riskRegisterItems.isEmpty &&
                                widget.staffingRows.isEmpty &&
                                widget.requirementItems.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'No risk register, staffing, or requirement items found. Add them in earlier sections to enable linkage.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                                ),
                              ),
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),

                // Footer actions
                Row(children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.onSurfaceVariant,
                      side: BorderSide(color: colorScheme.outline.withOpacity(0.4)),
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
    );

    return dialog;
  }

  List<Widget> _row1(ThemeData theme, ColorScheme colorScheme) {
    return [
      Expanded(
        child: DropdownButtonFormField<String>(
          initialValue: _department,
          items: [
            for (final option in widget.departmentOptions)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: (v) => setState(() => _department = v ?? _department),
          decoration: _inputDecoration(widget.departmentLabel, theme, colorScheme),
          dropdownColor: colorScheme.surface,
          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: VoiceTextFormField(
          controller: _memberCtrl,
          decoration: _inputDecoration(widget.teamMemberLabel, theme, colorScheme),
          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: DropdownButtonFormField<String>(
          initialValue: _riskLevel,
          items: const [
            DropdownMenuItem(value: 'Low', child: Text('Low')),
            DropdownMenuItem(value: 'Medium', child: Text('Medium')),
            DropdownMenuItem(value: 'High', child: Text('High')),
          ],
          onChanged: (v) => setState(() => _riskLevel = v ?? _riskLevel),
          decoration: _inputDecoration(widget.riskLevelLabel, theme, colorScheme),
          dropdownColor: colorScheme.surface,
          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
        ),
      ),
    ];
  }

  List<Widget> _costRow(ThemeData theme, ColorScheme colorScheme) {
    return [
      Expanded(
        flex: 2,
        child: TextFormField(
          controller: _costCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
          decoration: _inputDecoration('Estimated Cost Amount', theme, colorScheme).copyWith(
            prefixText: _costCurrency == 'USD' ? '\$ ' : '$_costCurrency ',
          ),
          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 1,
        child: DropdownButtonFormField<String>(
          initialValue: _costCurrency,
          items: const [
            DropdownMenuItem(value: 'USD', child: Text('USD')),
            DropdownMenuItem(value: 'ZMW', child: Text('ZMW')),
            DropdownMenuItem(value: 'EUR', child: Text('EUR')),
            DropdownMenuItem(value: 'GBP', child: Text('GBP')),
            DropdownMenuItem(value: 'ZAR', child: Text('ZAR')),
          ],
          onChanged: (v) => setState(() => _costCurrency = v ?? _costCurrency),
          decoration: _inputDecoration('Currency', theme, colorScheme),
          dropdownColor: colorScheme.surface,
          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: DropdownButtonFormField<String>(
          initialValue: _costFrequency,
          items: const [
            DropdownMenuItem(value: 'One-time', child: Text('One-time')),
            DropdownMenuItem(value: 'Recurring', child: Text('Recurring')),
            DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
            DropdownMenuItem(value: 'Quarterly', child: Text('Quarterly')),
            DropdownMenuItem(value: 'Annual', child: Text('Annual')),
          ],
          onChanged: (v) => setState(() => _costFrequency = v ?? _costFrequency),
          decoration: _inputDecoration('Frequency', theme, colorScheme),
          dropdownColor: colorScheme.surface,
          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: VoiceTextFormField(
          controller: _costUnitCtrl,
          decoration: _inputDecoration('Cost Unit (e.g. lump sum, per item, per month)', theme, colorScheme),
          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
          onChanged: (v) => _costUnit = v,
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
        teamMember: _memberCtrl.text.trim(),
        concern: _concernCtrl.text.trim(),
        riskLevel: _riskLevel,
        mitigation: _mitigationCtrl.text.trim(),
        estimatedCost: _costCtrl.text.trim(),
        costCurrency: _costCurrency,
        costFrequency: _costFrequency,
        costUnit: _costUnit,
        linkedRiskIds: _selectedRiskIds,
        linkedStaffingRoleIds: _selectedStaffingIds,
        linkedRequirementIds: _selectedRequirementIds,
        notes: _notesCtrl.text.trim(),
      ),
    );
  }
}
