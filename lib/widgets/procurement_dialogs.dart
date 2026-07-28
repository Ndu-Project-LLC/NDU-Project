import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/procurement/procurement_models.dart';
import 'package:ndu_project/models/procurement/procurement_ui_extensions.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/services/vendor_service.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
class ProcurementAssignableMemberOption {
  const ProcurementAssignableMemberOption({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.source,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String source;

  String get displayLabel {
    if (name.trim().isNotEmpty) return name.trim();
    if (email.trim().isNotEmpty) return email.trim();
    return 'Unnamed Member';
  }

  String get subtitle {
    final parts = <String>[];
    if (email.trim().isNotEmpty) parts.add(email.trim());
    if (role.trim().isNotEmpty) parts.add(role.trim());
    parts.add(source.trim().isEmpty ? 'Members' : source.trim());
    return parts.join(' - ');
  }
}

class ProcurementDialogShell extends StatelessWidget {
  const ProcurementDialogShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.contextChips,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> contextChips;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: 720, maxHeight: media.size.height * 0.88),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
                color: Color(0x1F0F172A),
                blurRadius: 30,
                offset: Offset(0, 18)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF8FAFF), Color(0xFFEFF6FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    top: -30,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE).withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x140F172A),
                                blurRadius: 10,
                                offset: Offset(0, 6)),
                          ],
                        ),
                        child: Icon(icon, color: const Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF475569)),
                            ),
                            if (contextChips.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: contextChips,
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: onSecondary,
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: child,
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Row(
                children: [
                  const Text(
                    'Saved to this workspace only.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: onPrimary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(primaryLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DialogSectionTitle extends StatelessWidget {
  const DialogSectionTitle(
      {super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}

class ContextChip extends StatelessWidget {
  const ContextChip({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(width: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}

class AddItemDialog extends StatefulWidget {
  const AddItemDialog({
    super.key,
    required this.contextChips,
    required this.categoryOptions,
    this.responsibleOptions = const <ProcurementAssignableMemberOption>[],
    this.initialItem,
    this.showAiGenerateButton = false,
    this.itemDomainLabel = 'Procurement',
  });

  final List<Widget> contextChips;
  final List<String> categoryOptions;
  final List<ProcurementAssignableMemberOption> responsibleOptions;
  final ProcurementItemModel? initialItem;
  final bool showAiGenerateButton;
  final String itemDomainLabel;

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _budgetCtrl;

  late String _category;
  ProcurementItemStatus _status = ProcurementItemStatus.planning;
  ProcurementPriority _priority = ProcurementPriority.medium;
  DateTime? _deliveryDate;
  String _responsibleMember = '';
  bool _showDateError = false;
  bool _isGenerating = false;

  final FocusNode _nameFocus = FocusNode();
  late final OpenAiServiceSecure _openAi;
  bool get _isEditing => widget.initialItem != null;

  List<String> get _categoryOptionsWithOther {
    final normalized = <String>[];
    var hasOther = false;
    for (final rawOption in widget.categoryOptions) {
      final option = rawOption.trim();
      if (option.isEmpty) continue;
      if (!normalized.contains(option)) {
        normalized.add(option);
      }
      if (option.toLowerCase() == 'other') {
        hasOther = true;
      }
    }
    if (!hasOther) {
      normalized.add('Other');
    }
    if (normalized.isEmpty) {
      normalized.add('Other');
    }
    return normalized;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.initialItem;
    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _descCtrl = TextEditingController(text: existing?.description ?? '');
    _budgetCtrl = TextEditingController(
      text: existing != null ? existing.budget.toStringAsFixed(0) : '',
    );
    final categoryOptions = _categoryOptionsWithOther;
    _category = existing?.category ??
        (categoryOptions.isNotEmpty ? categoryOptions.first : 'Other');
    _status = existing?.status ?? ProcurementItemStatus.planning;
    _priority = existing?.priority ?? ProcurementPriority.medium;
    _deliveryDate = existing?.estimatedDelivery;
    _responsibleMember =
        _resolveResponsibleSelection(existing?.responsibleMember ?? '');
    _openAi = OpenAiServiceSecure();
    ApiKeyManager.initializeApiKey();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _budgetCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  int _parseCurrency(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  double _textSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final tokensA = a
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toSet();
    final tokensB = b
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toSet();
    if (tokensA.isEmpty || tokensB.isEmpty) return 0;
    final union = tokensA.union(tokensB).length.toDouble();
    if (union == 0) return 0;
    final overlap = tokensA.intersection(tokensB).length.toDouble();
    return overlap / union;
  }

  ProcurementAssignableMemberOption? _matchResponsibleByRole(String roleHint) {
    final role = roleHint.trim().toLowerCase();
    if (role.isEmpty) return null;
    for (final option in widget.responsibleOptions) {
      final memberRole = option.role.trim().toLowerCase();
      if (memberRole.isEmpty) continue;
      if (memberRole == role ||
          memberRole.contains(role) ||
          role.contains(memberRole)) {
        return option;
      }
    }
    return null;
  }

  String _resolveResponsibleSelection(String rawValue, {String roleHint = ''}) {
    final value = rawValue.trim();
    if (value.isEmpty) {
      return _matchResponsibleByRole(roleHint)?.displayLabel ?? '';
    }

    final normalized = value.toLowerCase();
    ProcurementAssignableMemberOption? exactMatch;
    ProcurementAssignableMemberOption? fuzzyMatch;
    var bestScore = 0.0;

    for (final option in widget.responsibleOptions) {
      final label = option.displayLabel.toLowerCase();
      final email = option.email.toLowerCase();
      if (label == normalized || email == normalized) {
        exactMatch = option;
        break;
      }

      if (label.contains(normalized) ||
          normalized.contains(label) ||
          (email.isNotEmpty &&
              (email.contains(normalized) || normalized.contains(email)))) {
        fuzzyMatch = option;
        bestScore = 1.0;
        continue;
      }

      final score = _textSimilarity(normalized, label);
      if (score > bestScore) {
        bestScore = score;
        fuzzyMatch = option;
      }
    }

    if (exactMatch != null) return exactMatch.displayLabel;
    if (fuzzyMatch != null && bestScore >= 0.5) return fuzzyMatch.displayLabel;
    final roleMatch = _matchResponsibleByRole(roleHint);
    if (roleMatch != null) return roleMatch.displayLabel;
    return value;
  }

  String _formatDisplayDate(DateTime date) =>
      DateFormat('MMM d, yyyy').format(date);

  Future<void> _generateWithAI() async {
    if (!widget.showAiGenerateButton) return;
    if (_isGenerating) return;

    setState(() => _isGenerating = true);

    try {
      final projectData = ProjectDataHelper.getData(context);
      final projectName = projectData.projectName.trim().isEmpty
          ? 'Project'
          : projectData.projectName.trim();
      final solutionTitle = projectData.solutionTitle.trim().isEmpty
          ? 'Solution'
          : projectData.solutionTitle.trim();
      final notes = projectData.frontEndPlanning.procurement.trim();

      final result = await _openAi.generateProcurementItemSuggestion(
        projectName: projectName,
        solutionTitle: solutionTitle,
        category: _category,
        contextNotes: notes,
      );

      if (mounted) {
        final deliveryDays = result['estimatedDeliveryDays'] as int? ?? 90;
        final deliveryDate = DateTime.now().add(Duration(days: deliveryDays));
        final aiResponsible = (result['responsible'] ??
                result['responsibleMember'] ??
                result['owner'] ??
                result['person'] ??
                '')
            .toString()
            .trim();
        final aiRole = (result['role'] ??
                result['ownerRole'] ??
                result['responsibleRole'] ??
                '')
            .toString()
            .trim();

        ProcurementPriority priority;
        final priorityStr = result['priority'] as String? ?? 'medium';
        switch (priorityStr.toLowerCase()) {
          case 'critical':
            priority = ProcurementPriority.critical;
            break;
          case 'high':
            priority = ProcurementPriority.high;
            break;
          case 'low':
            priority = ProcurementPriority.low;
            break;
          default:
            priority = ProcurementPriority.medium;
        }

        setState(() {
          _nameCtrl.text = result['name'] ?? '';
          _descCtrl.text = result['description'] ?? '';
          _category = result['category'] ?? _category;
          _budgetCtrl.text = (result['budget'] as int? ?? 50000).toString();
          _priority = priority;
          _deliveryDate = deliveryDate;
          _responsibleMember =
              _resolveResponsibleSelection(aiResponsible, roleHint: aiRole);
          _showDateError = false;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate item: ${e.toString()}')),
        );
      }
    }
  }

  InputDecoration _dialogDecoration(
      {required String label,
      String? hint,
      Widget? prefixIcon,
      String? helperText,
      String? errorText}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      errorText: errorText,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      labelStyle: const TextStyle(
          fontWeight: FontWeight.w600, color: Color(0xFF475569)),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryOptions = _categoryOptionsWithOther.contains(_category)
        ? _categoryOptionsWithOther
        : [_category, ..._categoryOptionsWithOther];

    return ProcurementDialogShell(
      title: _isEditing
          ? 'Edit ${widget.itemDomainLabel} Item'
          : 'Add ${widget.itemDomainLabel} Item',
      subtitle: _isEditing
          ? 'Update scope, budget, and delivery timing.'
          : 'Capture scope, budget, and delivery timing.',
      icon: Icons.inventory_2_outlined,
      contextChips: widget.contextChips,
      primaryLabel: _isEditing ? 'Save Changes' : 'Add Item',
      secondaryLabel: 'Cancel',
      onSecondary: () => Navigator.of(context).pop(),
      onPrimary: () {
        final valid = _formKey.currentState?.validate() ?? false;
        if (!valid) return;
        if (_deliveryDate == null) {
          setState(() => _showDateError = true);
          return;
        }
        final projectId = widget.initialItem?.projectId ??
            ProjectDataHelper.getData(context).projectId ??
            'project-1';
        final budget = _parseCurrency(_budgetCtrl.text);
        final existing = widget.initialItem;
        final item = ProcurementItemModel(
          id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          projectId: projectId,
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          category: _category,
          status: _status,
          priority: _priority,
          budget: budget.toDouble(),
          spent: existing?.spent ?? 0.0,
          estimatedDelivery: _deliveryDate,
          actualDelivery: existing?.actualDelivery,
          progress: existing?.progress ?? 0,
          vendorId: existing?.vendorId,
          contractId: existing?.contractId,
          events: existing?.events ?? [],
          notes: existing?.notes ?? '',
          projectPhase: existing?.projectPhase ?? 'Planning',
          responsibleMember: _responsibleMember.trim(),
          comments: existing?.comments ?? '',
          createdAt: existing?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );
        Navigator.of(context).pop(item);
      },
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: DialogSectionTitle(
                    title: 'Item details',
                    subtitle: 'What are you sourcing for this project?',
                  ),
                ),
                if (widget.showAiGenerateButton) ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _isGenerating ? null : _generateWithAI,
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Generate with AI'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ],
            ),
            if (!widget.showAiGenerateButton) ...[
              const SizedBox(height: 8),
              const Text(
                'Manual entry mode. No AI auto-generation or auto-complete is used when adding a new item.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
            const SizedBox(height: 12),
            VoiceTextFormField(
              controller: _nameCtrl,
              focusNode: _nameFocus,
              decoration: _dialogDecoration(
                  label: 'Item name', hint: 'e.g. Network core switches'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Item name is required.'
                  : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            VoiceTextFormField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: _dialogDecoration(
                  label: 'Description', hint: 'Short scope description'),
            ),
            const SizedBox(height: 18),
            const DialogSectionTitle(
              title: 'Classification',
              subtitle: 'Align the item with sourcing workflow.',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    decoration: _dialogDecoration(label: 'Category'),
                    items: categoryOptions
                        .map((option) => DropdownMenuItem(
                            value: option, child: Text(option)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _category = value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<ProcurementItemStatus>(
                    value: _status,
                    decoration: _dialogDecoration(label: 'Status'),
                    items: ProcurementItemStatus.values
                        .map((option) => DropdownMenuItem(
                            value: option, child: Text(option.label)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _status = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ProcurementPriority>(
              value: _priority,
              decoration: _dialogDecoration(label: 'Priority'),
              items: ProcurementPriority.values
                  .map((option) => DropdownMenuItem(
                      value: option, child: Text(option.label)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _priority = value);
              },
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: widget.responsibleOptions.isEmpty
                  ? null
                  : () async {
                      final selected =
                          await showDialog<ProcurementAssignableMemberOption>(
                        context: context,
                        builder: (dialogContext) =>
                            _ResponsibleMemberPickerDialog(
                          options: widget.responsibleOptions,
                          initialQuery: _responsibleMember,
                        ),
                      );
                      if (selected == null) return;
                      setState(() {
                        _responsibleMember = selected.displayLabel;
                      });
                    },
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: _dialogDecoration(
                  label: 'Responsible',
                  hint: widget.responsibleOptions.isEmpty
                      ? 'No members available'
                      : 'Select project or company member',
                  prefixIcon: const Icon(Icons.person_search_outlined),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _responsibleMember.trim().isEmpty
                            ? (widget.responsibleOptions.isEmpty
                                ? 'No members available'
                                : 'Choose member')
                            : _responsibleMember.trim(),
                        style: TextStyle(
                          color: _responsibleMember.trim().isEmpty
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_responsibleMember.trim().isNotEmpty &&
                        widget.responsibleOptions.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear responsible',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          setState(() => _responsibleMember = '');
                        },
                        icon: const Icon(Icons.close_rounded, size: 16),
                      ),
                    const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const DialogSectionTitle(
              title: 'Budget and timing',
              subtitle: 'Estimate cost and delivery window.',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: VoiceTextFormField(
                    controller: _budgetCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _dialogDecoration(
                        label: 'Budget',
                        hint: 'e.g. 85000',
                        prefixIcon: const Icon(Icons.attach_money)),
                    validator: (value) {
                      final amount = _parseCurrency(value ?? '');
                      return amount <= 0 ? 'Enter a budget amount.' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _deliveryDate ??
                            DateTime.now().add(const Duration(days: 14)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(DateTime.now().year + 5),
                      );
                      if (picked == null) return;
                      setState(() {
                        _deliveryDate = picked;
                        _showDateError = false;
                      });
                    },
                    child: InputDecorator(
                      decoration: _dialogDecoration(
                        label: 'Est. delivery',
                        hint: 'Select date',
                        prefixIcon: const Icon(Icons.event),
                        errorText: _showDateError ? 'Select a date.' : null,
                      ),
                      child: Text(
                        _deliveryDate == null
                            ? 'Select date'
                            : _formatDisplayDate(_deliveryDate!),
                        style: TextStyle(
                          color: _deliveryDate == null
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsibleMemberPickerDialog extends StatefulWidget {
  const _ResponsibleMemberPickerDialog({
    required this.options,
    required this.initialQuery,
  });

  final List<ProcurementAssignableMemberOption> options;
  final String initialQuery;

  @override
  State<_ResponsibleMemberPickerDialog> createState() =>
      _ResponsibleMemberPickerDialogState();
}

class _ResponsibleMemberPickerDialogState
    extends State<_ResponsibleMemberPickerDialog> {
  late final TextEditingController _searchController =
      TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ProcurementAssignableMemberOption> _filteredOptions() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.options;
    return widget.options.where((option) {
      final name = option.name.toLowerCase();
      final email = option.email.toLowerCase();
      final role = option.role.toLowerCase();
      final source = option.source.toLowerCase();
      return name.contains(query) ||
          email.contains(query) ||
          role.contains(query) ||
          source.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOptions();
    final grouped = <String, List<ProcurementAssignableMemberOption>>{};
    for (final option in filtered) {
      grouped
          .putIfAbsent(
              option.source, () => <ProcurementAssignableMemberOption>[])
          .add(option);
    }

    final dialogWidth = MediaQuery.sizeOf(context).width > 620
        ? 520.0
        : MediaQuery.sizeOf(context).width * 0.86;

    return AlertDialog(
      title: const Text('Select Responsible Member'),
      content: SizedBox(
        width: dialogWidth,
        height: 420,
        child: Column(
          children: [
            VoiceTextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search project team or company members...',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No members available',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    )
                  : ListView(
                      children: grouped.entries.map((entry) {
                        final source = entry.key;
                        final members = entry.value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                              child: Text(
                                source,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            ...members.map(
                              (member) => ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFFDBEAFE),
                                  child: Text(
                                    member.displayLabel[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  member.displayLabel,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                subtitle: Text(
                                  member.subtitle,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onTap: () => Navigator.pop(context, member),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class AddVendorDialog extends StatefulWidget {
  const AddVendorDialog({
    super.key,
    required this.contextChips,
    required this.categoryOptions,
    this.initialVendor,
    this.showAiGenerateButton = false,
    this.partnerLabel = 'Vendor',
    this.partnerPluralLabel = 'Vendors',
    this.existingPartners = const <VendorModel>[],
    this.allowExistingAutofill = true,
  });

  final List<Widget> contextChips;
  final List<String> categoryOptions;
  final VendorModel? initialVendor;
  final bool showAiGenerateButton;
  final String partnerLabel;
  final String partnerPluralLabel;
  final List<VendorModel> existingPartners;
  final bool allowExistingAutofill;

  @override
  State<AddVendorDialog> createState() => _AddVendorDialogState();
}

class _AddVendorDialogState extends State<AddVendorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _otherCategoryCtrl;
  late String _category;
  double _rating = 4;
  bool _approved = true;
  bool _preferred = false;
  bool _isGenerating = false;
  bool _usingOtherCategory = false;
  bool _showOtherCategoryError = false;
  VendorModel? _matchedExistingPartner;
  List<VendorModel> _matchingPartners = const <VendorModel>[];

  final FocusNode _nameFocus = FocusNode();
  late final OpenAiServiceSecure _openAi;
  bool get _isEditing => widget.initialVendor != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialVendor?.name ?? '');
    final normalizedCategoryOptions = _categoryOptionsWithOther;
    final initialCategory = (widget.initialVendor?.category ?? '').trim();
    if (initialCategory.isNotEmpty &&
        !normalizedCategoryOptions.contains(initialCategory)) {
      _usingOtherCategory = true;
      _category = 'Other';
      _otherCategoryCtrl = TextEditingController(text: initialCategory);
    } else {
      _category = initialCategory.isNotEmpty
          ? initialCategory
          : normalizedCategoryOptions.first;
      _otherCategoryCtrl = TextEditingController();
    }
    _rating = _ratingFromLetter(widget.initialVendor?.rating ?? 'B');
    final status = widget.initialVendor?.status.toLowerCase() ?? 'active';
    _approved = status == 'active' || status == 'approved';
    final criticality =
        widget.initialVendor?.criticality.toLowerCase() ?? 'medium';
    _preferred = criticality == 'high';
    _openAi = OpenAiServiceSecure();
    ApiKeyManager.initializeApiKey();
    _nameCtrl.addListener(_onNameChanged);
    if (!_isEditing && widget.allowExistingAutofill) {
      _onNameChanged();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _nameFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    _otherCategoryCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  // ignore: unused_element
  String _deriveInitials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'NA';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  double _ratingFromLetter(String rating) {
    final raw = rating.trim().toUpperCase();
    final parsed = int.tryParse(raw);
    if (parsed != null) return parsed.toDouble().clamp(1, 5);
    switch (raw) {
      case 'A':
        return 5;
      case 'B':
        return 4;
      case 'C':
        return 3;
      case 'D':
        return 2;
      case 'E':
        return 1;
      default:
        return 4;
    }
  }

  String _ratingToLetter(double value) {
    final score = value.round().clamp(1, 5);
    switch (score) {
      case 5:
        return 'A';
      case 4:
        return 'B';
      case 3:
        return 'C';
      case 2:
        return 'D';
      default:
        return 'E';
    }
  }

  List<String> get _categoryOptionsWithOther {
    final options = <String>[];
    var hasOther = false;
    for (final rawOption in widget.categoryOptions) {
      final option = rawOption.trim();
      if (option.isEmpty) continue;
      if (!options.contains(option)) {
        options.add(option);
      }
      if (option.toLowerCase() == 'other') {
        hasOther = true;
      }
    }
    if (!hasOther) {
      options.add('Other');
    }
    if (options.isEmpty) {
      options.add('Other');
    }
    return options;
  }

  String _effectiveCategory() {
    if (_usingOtherCategory || _category == 'Other') {
      return _otherCategoryCtrl.text.trim();
    }
    return _category.trim();
  }

  void _applyExistingPartner(VendorModel partner, {bool updateName = false}) {
    if (!mounted) return;
    setState(() {
      if (updateName) {
        _nameCtrl.text = partner.name.trim();
        _nameCtrl.selection = TextSelection.collapsed(
          offset: _nameCtrl.text.length,
        );
      }
      final nextCategory = partner.category.trim();
      if (nextCategory.isNotEmpty &&
          !_categoryOptionsWithOther.contains(nextCategory)) {
        _category = 'Other';
        _usingOtherCategory = true;
        _otherCategoryCtrl.text = nextCategory;
      } else {
        _category = nextCategory.isEmpty ? _category : nextCategory;
        _usingOtherCategory = _category == 'Other';
        if (!_usingOtherCategory) {
          _otherCategoryCtrl.clear();
        }
      }
      _rating = _ratingFromLetter(partner.rating);
      final status = partner.status.trim().toLowerCase();
      _approved = status == 'active' || status == 'approved';
      _preferred = partner.criticality.trim().toLowerCase() == 'high';
      _matchedExistingPartner = partner;
      _showOtherCategoryError = false;
    });
  }

  void _onNameChanged() {
    if (!widget.allowExistingAutofill) return;
    if (_isEditing) return;
    final query = _nameCtrl.text.trim().toLowerCase();
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _matchingPartners = const <VendorModel>[];
        _matchedExistingPartner = null;
      });
      return;
    }

    final exact = widget.existingPartners.where((partner) {
      return partner.name.trim().toLowerCase() == query;
    }).toList();
    if (exact.isNotEmpty) {
      _applyExistingPartner(exact.first);
      setState(() => _matchingPartners = exact.take(1).toList());
      return;
    }

    final matching = widget.existingPartners.where((partner) {
      final name = partner.name.trim().toLowerCase();
      return name.contains(query);
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (!mounted) return;
    setState(() {
      _matchingPartners = matching.take(5).toList();
      _matchedExistingPartner = null;
    });
  }

  Future<void> _generateWithAI() async {
    if (!widget.showAiGenerateButton) return;
    if (_isGenerating) return;

    setState(() => _isGenerating = true);

    try {
      final projectData = ProjectDataHelper.getData(context);
      final projectName = projectData.projectName.trim().isEmpty
          ? 'Project'
          : projectData.projectName.trim();
      final solutionTitle = projectData.solutionTitle.trim().isEmpty
          ? 'Solution'
          : projectData.solutionTitle.trim();
      final notes = projectData.frontEndPlanning.procurement.trim();

      final result = await _openAi.generateVendorSuggestion(
        projectName: projectName,
        solutionTitle: solutionTitle,
        category:
            _effectiveCategory().isEmpty ? _category : _effectiveCategory(),
        contextNotes: notes,
      );

      if (mounted) {
        setState(() {
          _nameCtrl.text = result['name'] ?? '';
          final aiCategory = (result['category'] ?? '').toString().trim();
          if (aiCategory.isNotEmpty &&
              !_categoryOptionsWithOther.contains(aiCategory)) {
            _category = 'Other';
            _usingOtherCategory = true;
            _otherCategoryCtrl.text = aiCategory;
          } else if (aiCategory.isNotEmpty) {
            _category = aiCategory;
            _usingOtherCategory = _category == 'Other';
            if (!_usingOtherCategory) {
              _otherCategoryCtrl.clear();
            }
          }
          _rating = (result['rating'] as int? ?? 4).toDouble();
          _approved = result['approved'] as bool? ?? true;
          _preferred = result['preferred'] as bool? ?? false;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to generate ${widget.partnerLabel.toLowerCase()}: ${e.toString()}',
            ),
          ),
        );
      }
    }
  }

  InputDecoration _dialogDecoration(
      {required String label,
      String? hint,
      Widget? prefixIcon,
      String? helperText,
      String? errorText}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      errorText: errorText,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      labelStyle: const TextStyle(
          fontWeight: FontWeight.w600, color: Color(0xFF475569)),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryOptions = _categoryOptionsWithOther.contains(_category)
        ? _categoryOptionsWithOther
        : [_category, ..._categoryOptionsWithOther];
    return ProcurementDialogShell(
      title: _isEditing
          ? 'Edit ${widget.partnerLabel}'
          : 'Add ${widget.partnerLabel}',
      subtitle: _isEditing
          ? 'Update ${widget.partnerLabel.toLowerCase()} details and qualification.'
          : 'Build your trusted ${widget.partnerPluralLabel.toLowerCase()} network.',
      icon: Icons.storefront_outlined,
      contextChips: widget.contextChips,
      primaryLabel: _isEditing ? 'Save Changes' : 'Add ${widget.partnerLabel}',
      secondaryLabel: 'Cancel',
      onSecondary: () => Navigator.of(context).pop(),
      onPrimary: () {
        final valid = _formKey.currentState?.validate() ?? false;
        if (!valid) return;
        final effectiveCategory = _effectiveCategory();
        if (effectiveCategory.isEmpty) {
          setState(() => _showOtherCategoryError = true);
          return;
        }
        final name = _nameCtrl.text.trim();
        final projectId =
            ProjectDataHelper.getData(context).projectId ?? 'project-1';
        final vendorId = widget.initialVendor?.id ??
            'vendor_${DateTime.now().microsecondsSinceEpoch}';
        final status = _approved ? 'Active' : 'Watch';
        final criticality = _preferred ? 'High' : 'Medium';
        final nextReview = widget.initialVendor?.nextReview ??
            DateFormat('MMM d, yyyy')
                .format(DateTime.now().add(const Duration(days: 180)));
        final vendor = VendorModel(
          id: vendorId,
          projectId: projectId,
          name: name,
          category: effectiveCategory,
          criticality: criticality,
          sla: widget.initialVendor?.sla ?? '98%',
          slaPerformance: widget.initialVendor?.slaPerformance ??
              (_rating / 5).clamp(0.0, 1.0),
          leadTime: widget.initialVendor?.leadTime ?? '14 Days',
          requiredDeliverables: widget.initialVendor?.requiredDeliverables ??
              '• Quarterly review\n• SLA adherence',
          rating: _ratingToLetter(_rating),
          status: status,
          nextReview: nextReview,
          contractId: widget.initialVendor?.contractId,
          onTimeDelivery: widget.initialVendor?.onTimeDelivery ?? 0.95,
          incidentResponse: widget.initialVendor?.incidentResponse ?? 0.95,
          qualityScore: widget.initialVendor?.qualityScore ?? 0.95,
          costAdherence: widget.initialVendor?.costAdherence ?? 0.95,
          notes: widget.initialVendor?.notes,
          createdById: 'user',
          createdByEmail: 'user@email',
          createdByName: 'User',
          createdAt: widget.initialVendor?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );
        Navigator.of(context).pop(vendor);
      },
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: DialogSectionTitle(
                    title: '${widget.partnerLabel} identity',
                    subtitle: 'Capture the partner name and sourcing category.',
                  ),
                ),
                if (widget.showAiGenerateButton) ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _isGenerating ? null : _generateWithAI,
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Generate with AI'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ],
            ),
            if (!widget.showAiGenerateButton) ...[
              const SizedBox(height: 8),
              Text(
                'Manual entry enabled. Saved or approved ${widget.partnerPluralLabel.toLowerCase()} auto-fill when the name matches.',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
            const SizedBox(height: 12),
            VoiceTextFormField(
              controller: _nameCtrl,
              focusNode: _nameFocus,
              decoration: _dialogDecoration(
                label: '${widget.partnerLabel} name',
                hint: 'e.g. Atlas Tech Supply',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? '${widget.partnerLabel} name is required.'
                  : null,
            ),
            if (_matchingPartners.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _matchingPartners
                    .map(
                      (partner) => ActionChip(
                        label: Text(
                          partner.name.trim(),
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        avatar: const Icon(
                          Icons.person_outline_rounded,
                          size: 14,
                        ),
                        onPressed: () => _applyExistingPartner(
                          partner,
                          updateName: true,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (_matchedExistingPartner != null) ...[
              const SizedBox(height: 8),
              Text(
                'Matched existing ${widget.partnerLabel.toLowerCase()}. Details auto-filled.',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: _dialogDecoration(label: 'Category'),
              items: categoryOptions
                  .map((option) =>
                      DropdownMenuItem(value: option, child: Text(option)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _category = value;
                  _usingOtherCategory = value == 'Other';
                  if (!_usingOtherCategory) {
                    _otherCategoryCtrl.clear();
                    _showOtherCategoryError = false;
                  }
                });
              },
            ),
            if (_usingOtherCategory || _category == 'Other') ...[
              const SizedBox(height: 12),
              VoiceTextFormField(
                controller: _otherCategoryCtrl,
                decoration: _dialogDecoration(
                  label: 'Other Category',
                  hint: 'Enter custom category',
                  errorText: _showOtherCategoryError
                      ? 'Category is required when "Other" is selected.'
                      : null,
                ),
                onChanged: (_) {
                  if (_showOtherCategoryError) {
                    setState(() => _showOtherCategoryError = false);
                  }
                },
              ),
            ],
            const SizedBox(height: 18),
            const DialogSectionTitle(
              title: 'Qualification',
              subtitle: 'Define rating and approval status.',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Rating',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569))),
                      Slider(
                        value: _rating,
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: _rating.round().toString(),
                        activeColor: const Color(0xFF2563EB),
                        onChanged: (value) => setState(() => _rating = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    Row(
                      children: [
                        Switch(
                          value: _approved,
                          thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? const Color(0xFF2563EB) : null),
                          onChanged: (value) =>
                              setState(() => _approved = value),
                        ),
                        const Text('Approved'),
                      ],
                    ),
                    Row(
                      children: [
                        Switch(
                          value: _preferred,
                          thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? const Color(0xFF2563EB) : null),
                          onChanged: (value) =>
                              setState(() => _preferred = value),
                        ),
                        const Text('Preferred'),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CreateRfqDialog extends StatefulWidget {
  const CreateRfqDialog({
    super.key,
    required this.contextChips,
    required this.categoryOptions,
    this.initialRfq,
  });

  final List<Widget> contextChips;
  final List<String> categoryOptions;
  final RfqModel? initialRfq;

  @override
  State<CreateRfqDialog> createState() => _CreateRfqDialogState();
}

class _CreateRfqDialogState extends State<CreateRfqDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _ownerCtrl;
  late TextEditingController _budgetCtrl;
  late TextEditingController _invitedCtrl;
  late TextEditingController _responsesCtrl;

  late String _category;
  RfqStatus _status = RfqStatus.draft;
  ProcurementPriority _priority = ProcurementPriority.medium;
  DateTime? _dueDate;
  bool _showDateError = false;

  final FocusNode _titleFocus = FocusNode();
  bool get _isEditing => widget.initialRfq != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRfq;
    final initialBudget = initial?.budget ?? 0;
    String budgetText = '';
    if (initialBudget > 0) {
      budgetText = initialBudget == initialBudget.truncateToDouble()
          ? initialBudget.toStringAsFixed(0)
          : initialBudget.toStringAsFixed(2);
    }

    _titleCtrl = TextEditingController(text: initial?.title ?? '');
    _ownerCtrl = TextEditingController(text: initial?.owner ?? '');
    _budgetCtrl = TextEditingController(text: budgetText);
    _invitedCtrl = TextEditingController(
      text: '${initial?.invitedCount ?? 0}',
    );
    _responsesCtrl = TextEditingController(
      text: '${initial?.responseCount ?? 0}',
    );

    final defaultCategory = widget.categoryOptions.isEmpty
        ? 'General'
        : widget.categoryOptions.first;
    _category = initial?.category ?? defaultCategory;
    if (!_isEditing || !widget.categoryOptions.contains(_category)) {
      _category = defaultCategory;
    }

    _status = initial?.status ?? RfqStatus.draft;
    _priority = initial?.priority ?? ProcurementPriority.medium;
    _dueDate = initial?.dueDate;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _titleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _ownerCtrl.dispose();
    _budgetCtrl.dispose();
    _invitedCtrl.dispose();
    _responsesCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  int _parseCurrency(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  String _formatDisplayDate(DateTime date) =>
      DateFormat('MMM d, yyyy').format(date);

  InputDecoration _dialogDecoration(
      {required String label,
      String? hint,
      Widget? prefixIcon,
      String? errorText}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      labelStyle: const TextStyle(
          fontWeight: FontWeight.w600, color: Color(0xFF475569)),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryOptions = widget.categoryOptions.isEmpty
        ? <String>[_category]
        : widget.categoryOptions;

    return ProcurementDialogShell(
      title: _isEditing ? 'Edit RFQ' : 'Create RFQ',
      subtitle: _isEditing
          ? 'Update request for quote details and timing.'
          : 'Kick off a request for quote with clear scope and timing.',
      icon: Icons.request_quote_outlined,
      contextChips: widget.contextChips,
      primaryLabel: _isEditing ? 'Save Changes' : 'Create RFQ',
      secondaryLabel: 'Cancel',
      onSecondary: () => Navigator.of(context).pop(),
      onPrimary: () {
        final valid = _formKey.currentState?.validate() ?? false;
        if (!valid) return;
        if (_dueDate == null) {
          setState(() => _showDateError = true);
          return;
        }
        final budget = _parseCurrency(_budgetCtrl.text);
        final invitedRaw = int.tryParse(_invitedCtrl.text.trim()) ?? 0;
        final responsesRaw = int.tryParse(_responsesCtrl.text.trim()) ?? 0;
        final invited = invitedRaw < 0 ? 0 : invitedRaw;
        final responses = responsesRaw.clamp(0, invited).toInt();
        final projectId = widget.initialRfq?.projectId ??
            ProjectDataHelper.getData(context).projectId ??
            'project-1';
        final rfq = RfqModel(
          id: widget.initialRfq?.id ??
              'RFQ-${DateTime.now().millisecondsSinceEpoch % 10000}',
          title: _titleCtrl.text.trim(),
          projectId: projectId,
          category: _category,
          owner: _ownerCtrl.text.trim().isEmpty
              ? 'Unassigned'
              : _ownerCtrl.text.trim(),
          budget: budget.toDouble(),
          dueDate: _dueDate!,
          invitedCount: invited,
          responseCount: responses,
          status: _status,
          priority: _priority,
          createdAt: widget.initialRfq?.createdAt ?? DateTime.now(),
        );
        Navigator.of(context).pop(rfq);
      },
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DialogSectionTitle(
              title: 'RFQ overview',
              subtitle: 'Define the category and owner.',
            ),
            VoiceTextFormField(
              controller: _titleCtrl,
              focusNode: _titleFocus,
              decoration: _dialogDecoration(
                  label: 'RFQ title',
                  hint: 'e.g. Network infrastructure upgrade'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'RFQ title is required.'
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    decoration: _dialogDecoration(label: 'Category'),
                    items: categoryOptions
                        .map((option) => DropdownMenuItem(
                            value: option, child: Text(option)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _category = value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: VoiceTextFormField(
                    controller: _ownerCtrl,
                    decoration: _dialogDecoration(
                        label: 'Owner', hint: 'e.g. J. Patel'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const DialogSectionTitle(
              title: 'Budget and schedule',
              subtitle: 'Set a due date and target budget.',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: VoiceTextFormField(
                    controller: _budgetCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _dialogDecoration(
                        label: 'Budget',
                        hint: 'e.g. 120000',
                        prefixIcon: const Icon(Icons.attach_money)),
                    validator: (value) {
                      final amount = _parseCurrency(value ?? '');
                      return amount <= 0 ? 'Enter a budget amount.' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dueDate ??
                            DateTime.now().add(const Duration(days: 21)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(DateTime.now().year + 5),
                      );
                      if (picked == null) return;
                      setState(() {
                        _dueDate = picked;
                        _showDateError = false;
                      });
                    },
                    child: InputDecorator(
                      decoration: _dialogDecoration(
                        label: 'Due date',
                        hint: 'Select date',
                        prefixIcon: const Icon(Icons.event),
                        errorText: _showDateError ? 'Select a date.' : null,
                      ),
                      child: Text(
                        _dueDate == null
                            ? 'Select date'
                            : _formatDisplayDate(_dueDate!),
                        style: TextStyle(
                          color: _dueDate == null
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const DialogSectionTitle(
              title: 'Vendor outreach',
              subtitle: 'Track invitations and responses.',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: VoiceTextFormField(
                    controller: _invitedCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _dialogDecoration(label: 'Invited', hint: '0'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: VoiceTextFormField(
                    controller: _responsesCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        _dialogDecoration(label: 'Responses', hint: '0'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<RfqStatus>(
                    value: _status,
                    decoration: _dialogDecoration(label: 'Status'),
                    items: RfqStatus.values
                        .map((option) => DropdownMenuItem(
                            value: option, child: Text(option.label)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _status = value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<ProcurementPriority>(
                    value: _priority,
                    decoration: _dialogDecoration(label: 'Priority'),
                    items: ProcurementPriority.values
                        .map((option) => DropdownMenuItem(
                            value: option, child: Text(option.label)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _priority = value);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CreatePoDialog extends StatefulWidget {
  const CreatePoDialog({
    super.key,
    required this.contextChips,
    required this.categoryOptions,
    this.sourceItems = const <ProcurementItemModel>[],
    this.sourceItemNumberById = const <String, String>{},
    this.prioritizeLongLeadSelection = false,
    this.initialPo,
  });

  final List<Widget> contextChips;
  final List<String> categoryOptions;
  final List<ProcurementItemModel> sourceItems;
  final Map<String, String> sourceItemNumberById;
  final bool prioritizeLongLeadSelection;
  final PurchaseOrderModel? initialPo;

  @override
  State<CreatePoDialog> createState() => _CreatePoDialogState();
}

class _CreatePoDialogState extends State<CreatePoDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _idCtrl;
  late TextEditingController _vendorCtrl;
  late TextEditingController _ownerCtrl;
  late TextEditingController _amountCtrl;

  late String _category;
  PurchaseOrderStatus _status = PurchaseOrderStatus.awaitingApproval;
  DateTime _orderedDate = DateTime.now();
  DateTime _expectedDate = DateTime.now().add(const Duration(days: 21));
  double _progress = 0.0;
  String? _selectedSourceItemId;

  final FocusNode _idFocus = FocusNode();
  bool get _isEditing => widget.initialPo != null;

  List<ProcurementItemModel> get _availableSourceItems => widget.sourceItems
      .where((item) => item.id.trim().isNotEmpty)
      .toList(growable: false);

  Map<String, String> get _resolvedItemNumbers {
    final mapping = <String, String>{...widget.sourceItemNumberById};
    for (var i = 0; i < _availableSourceItems.length; i++) {
      final item = _availableSourceItems[i];
      mapping.putIfAbsent(
        item.id,
        () => 'ITM-${(i + 1).toString().padLeft(3, '0')}',
      );
    }
    return mapping;
  }

  ProcurementItemModel? get _selectedSourceItem {
    final selectedId = _selectedSourceItemId;
    if (selectedId == null || selectedId.isEmpty) return null;
    for (final item in _availableSourceItems) {
      if (item.id == selectedId) return item;
    }
    return null;
  }

  String _itemNumberFor(ProcurementItemModel item, int index) {
    return _resolvedItemNumbers[item.id] ??
        'ITM-${(index + 1).toString().padLeft(3, '0')}';
  }

  void _applySelectedSourceItem(ProcurementItemModel item) {
    final sourceNumber = _resolvedItemNumbers[item.id];
    setState(() {
      _selectedSourceItemId = item.id;
      if (sourceNumber != null) {
        _idCtrl.text = sourceNumber;
      }
      if (item.category.trim().isNotEmpty &&
          widget.categoryOptions.contains(item.category.trim())) {
        _category = item.category.trim();
      }
      if (_ownerCtrl.text.trim().isEmpty &&
          item.responsibleMember.trim().isNotEmpty) {
        _ownerCtrl.text = item.responsibleMember.trim();
      }
      final parsedAmount = _parseCurrency(_amountCtrl.text);
      if (parsedAmount <= 0 && item.budget > 0) {
        _amountCtrl.text = item.budget.round().toString();
      }
      if (item.estimatedDelivery != null) {
        _expectedDate = item.estimatedDelivery!;
      }
      _status = PurchaseOrderStatus.awaitingApproval;
    });
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPo;
    _idCtrl = TextEditingController(text: initial?.poNumber ?? '');
    _vendorCtrl = TextEditingController(text: initial?.vendorName ?? '');
    _ownerCtrl = TextEditingController(text: initial?.owner ?? '');
    _amountCtrl = TextEditingController(
      text: initial != null && initial.amount > 0
          ? initial.amount.round().toString()
          : '',
    );
    _category =
        initial != null && widget.categoryOptions.contains(initial.category)
            ? initial.category
            : widget.categoryOptions.first;
    _status = initial?.status ?? PurchaseOrderStatus.awaitingApproval;
    _orderedDate = initial?.orderedDate ?? DateTime.now();
    _expectedDate =
        initial?.expectedDate ?? DateTime.now().add(const Duration(days: 21));
    _progress = initial?.progress ?? 0.0;

    if (!_isEditing && _availableSourceItems.isNotEmpty) {
      final defaultItem = _availableSourceItems.first;
      _selectedSourceItemId = defaultItem.id;
      final sourceNumber = _resolvedItemNumbers[defaultItem.id];
      if (sourceNumber != null) {
        _idCtrl.text = sourceNumber;
      }
      if (defaultItem.category.trim().isNotEmpty &&
          widget.categoryOptions.contains(defaultItem.category.trim())) {
        _category = defaultItem.category.trim();
      }
      if (defaultItem.budget > 0 && _parseCurrency(_amountCtrl.text) <= 0) {
        _amountCtrl.text = defaultItem.budget.round().toString();
      }
      if (defaultItem.estimatedDelivery != null) {
        _expectedDate = defaultItem.estimatedDelivery!;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _idFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _vendorCtrl.dispose();
    _ownerCtrl.dispose();
    _amountCtrl.dispose();
    _idFocus.dispose();
    super.dispose();
  }

  int _parseCurrency(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  String _formatDisplayDate(DateTime date) =>
      DateFormat('MMM d, yyyy').format(date);

  InputDecoration _dialogDecoration(
      {required String label,
      String? hint,
      Widget? prefixIcon,
      String? errorText}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      labelStyle: const TextStyle(
          fontWeight: FontWeight.w600, color: Color(0xFF475569)),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _isEditing;
    final categoryOptions = widget.categoryOptions.contains(_category)
        ? widget.categoryOptions
        : [_category, ...widget.categoryOptions];
    final sourceItems = _availableSourceItems;

    return ProcurementDialogShell(
      title: isEditing ? 'Edit Purchase Order' : 'Create Purchase Order',
      subtitle: isEditing
          ? 'Update ownership, financials, and delivery timing.'
          : 'Select an identified item first, then issue a PO with clear ownership and delivery timing.',
      icon: Icons.receipt_long_outlined,
      contextChips: widget.contextChips,
      primaryLabel: isEditing ? 'Save Changes' : 'Create PO',
      secondaryLabel: 'Cancel',
      onSecondary: () => Navigator.of(context).pop(),
      onPrimary: () {
        final valid = _formKey.currentState?.validate() ?? false;
        if (!valid) return;
        final selectedItem = _selectedSourceItem;
        if (!isEditing && sourceItems.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Add procurement items first, then create a PO from a selected item.',
              ),
            ),
          );
          return;
        }
        if (!isEditing && sourceItems.isNotEmpty && selectedItem == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Select an item from the procurement list first.'),
            ),
          );
          return;
        }
        final amount = _parseCurrency(_amountCtrl.text);
        final selectedItemNumber =
            selectedItem == null ? null : _resolvedItemNumbers[selectedItem.id];
        final poId = (!isEditing && selectedItemNumber != null)
            ? selectedItemNumber
            : (_idCtrl.text.trim().isEmpty
                ? 'PO-${DateTime.now().millisecondsSinceEpoch % 10000}'
                : _idCtrl.text.trim());
        final projectId = widget.initialPo?.projectId ??
            ProjectDataHelper.getData(context).projectId ??
            'project-1';
        final po = PurchaseOrderModel(
          id: widget.initialPo?.id ?? poId,
          poNumber: poId,
          projectId: projectId,
          vendorName: _vendorCtrl.text.trim(),
          vendorId: selectedItem?.vendorId,
          category: _category,
          owner: _ownerCtrl.text.trim().isEmpty
              ? 'Unassigned'
              : _ownerCtrl.text.trim(),
          orderedDate: _orderedDate,
          expectedDate: _expectedDate,
          amount: amount.toDouble(),
          progress: _progress,
          status: _status,
          createdAt: DateTime.now(),
        );
        Navigator.of(context).pop(po);
      },
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isEditing) ...[
              DialogSectionTitle(
                title: 'Source item',
                subtitle: sourceItems.isEmpty
                    ? 'No procurement items available yet. Add items first in Scope Details.'
                    : 'Pick one identified item. Its item number becomes the PO number.',
              ),
              const SizedBox(height: 8),
              if (sourceItems.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Text(
                    'No source items available.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedSourceItemId,
                  decoration:
                      _dialogDecoration(label: 'Item from procurement list'),
                  items: List<DropdownMenuItem<String>>.generate(
                    sourceItems.length,
                    (index) {
                      final item = sourceItems[index];
                      return DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(
                          '${_itemNumberFor(item, index)} · ${item.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                  onChanged: (value) {
                    if (value == null) return;
                    for (final item in sourceItems) {
                      if (item.id == value) {
                        _applySelectedSourceItem(item);
                        break;
                      }
                    }
                  },
                  validator: (value) {
                    if (sourceItems.isEmpty) return null;
                    if (value == null || value.trim().isEmpty) {
                      return 'Select a source item.';
                    }
                    return null;
                  },
                ),
              if (widget.prioritizeLongLeadSelection && sourceItems.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Early start mode: prioritize vital long-lead items (LLEs).',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                  ),
                ),
              const SizedBox(height: 16),
            ],
            const DialogSectionTitle(
              title: 'PO details',
              subtitle: 'Define vendor, owner, and category.',
            ),
            VoiceTextFormField(
              controller: _idCtrl,
              focusNode: _idFocus,
              decoration: _dialogDecoration(
                label: 'PO number',
                hint: isEditing
                    ? 'PO identifier'
                    : 'Auto-linked to selected item number',
              ),
              readOnly: !isEditing && _selectedSourceItem != null,
            ),
            const SizedBox(height: 12),
            VoiceTextFormField(
              controller: _vendorCtrl,
              decoration: _dialogDecoration(
                  label: 'Vendor', hint: 'e.g. GreenLeaf Office'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Vendor is required.'
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    decoration: _dialogDecoration(label: 'Category'),
                    items: categoryOptions
                        .map((option) => DropdownMenuItem(
                            value: option, child: Text(option)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _category = value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: VoiceTextFormField(
                    controller: _ownerCtrl,
                    decoration:
                        _dialogDecoration(label: 'Owner', hint: 'e.g. L. Chen'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const DialogSectionTitle(
              title: 'Amounts and dates',
              subtitle: 'Track financials and delivery.',
            ),
            const SizedBox(height: 8),
            VoiceTextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: _dialogDecoration(
                  label: 'Amount',
                  hint: 'e.g. 72000',
                  prefixIcon: const Icon(Icons.attach_money)),
              validator: (value) {
                final amount = _parseCurrency(value ?? '');
                return amount <= 0 ? 'Enter a PO amount.' : null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _orderedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(DateTime.now().year + 5),
                      );
                      if (picked == null) return;
                      setState(() => _orderedDate = picked);
                    },
                    child: InputDecorator(
                      decoration: _dialogDecoration(
                          label: 'Ordered date',
                          prefixIcon: const Icon(Icons.event)),
                      child: Text(
                        _formatDisplayDate(_orderedDate),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _expectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(DateTime.now().year + 5),
                      );
                      if (picked == null) return;
                      setState(() => _expectedDate = picked);
                    },
                    child: InputDecorator(
                      decoration: _dialogDecoration(
                          label: 'Expected date',
                          prefixIcon: const Icon(Icons.event_available)),
                      child: Text(
                        _formatDisplayDate(_expectedDate),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PurchaseOrderStatus>(
              value: _status,
              decoration: _dialogDecoration(label: 'Status'),
              items: PurchaseOrderStatus.values
                  .map((option) => DropdownMenuItem(
                      value: option, child: Text(option.label)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _status = value);
              },
            ),
            const SizedBox(height: 12),
            const Text('Progress',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569))),
            Slider(
              value: _progress,
              min: 0,
              max: 1,
              divisions: 10,
              label: '${(_progress * 100).round()}%',
              activeColor: const Color(0xFF2563EB),
              onChanged: (value) => setState(() => _progress = value),
            ),
          ],
        ),
      ),
    );
  }
}

class AddContractDialog extends StatefulWidget {
  const AddContractDialog({
    super.key,
    required this.contextChips,
    required this.categoryOptions, // Just for context, mainly service types
    this.initialContract,
  });

  final List<Widget> contextChips;
  final List<String> categoryOptions;
  final ContractModel? initialContract;

  @override
  State<AddContractDialog> createState() => _AddContractDialogState();
}

class _AddContractDialogState extends State<AddContractDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _contractorCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _costCtrl;
  late TextEditingController _ownerCtrl;

  ContractStatus _status = ContractStatus.draft;
  DateTime? _startDate;
  DateTime? _endDate;
  bool get _isEditing => widget.initialContract != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.initialContract;
    _titleCtrl = TextEditingController(text: existing?.title ?? '');
    _contractorCtrl =
        TextEditingController(text: existing?.contractorName ?? '');
    _descCtrl = TextEditingController(text: existing?.description ?? '');
    _costCtrl = TextEditingController(
      text: existing == null || existing.estimatedCost <= 0
          ? ''
          : existing.estimatedCost.toStringAsFixed(0),
    );
    _ownerCtrl = TextEditingController(text: existing?.owner ?? '');
    _status = existing?.status ?? ContractStatus.draft;
    _startDate = existing?.startDate;
    _endDate = existing?.endDate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contractorCtrl.dispose();
    _descCtrl.dispose();
    _costCtrl.dispose();
    _ownerCtrl.dispose();
    super.dispose();
  }

  int _parseCurrency(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  String _formatDisplayDate(DateTime date) =>
      DateFormat('MMM d, yyyy').format(date);

  InputDecoration _dialogDecoration(
      {required String label,
      String? hint,
      Widget? prefixIcon,
      String? errorText}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      labelStyle: const TextStyle(
          fontWeight: FontWeight.w600, color: Color(0xFF475569)),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProcurementDialogShell(
      title: _isEditing ? 'Edit Contract' : 'Add Contract',
      subtitle: _isEditing
          ? 'Update contract terms, owner, and duration.'
          : 'Define contract terms, owner, and duration.',
      icon: Icons.gavel_outlined,
      contextChips: widget.contextChips,
      primaryLabel: _isEditing ? 'Save Changes' : 'Add Contract',
      secondaryLabel: 'Cancel',
      onSecondary: () => Navigator.of(context).pop(),
      onPrimary: () {
        final valid = _formKey.currentState?.validate() ?? false;
        if (!valid) return;

        final cost = _parseCurrency(_costCtrl.text);
        final projectId = widget.initialContract?.projectId ??
            ProjectDataHelper.getData(context).projectId ??
            'project-1';

        // duration string calculation
        String durationStr = '';
        if (_startDate != null && _endDate != null) {
          final days = _endDate!.difference(_startDate!).inDays;
          if (days > 30) {
            durationStr = '${(days / 30).round()} Months';
          } else {
            durationStr = '$days Days';
          }
        }

        final contract = ContractModel(
          id: widget.initialContract?.id ??
              'CNT-${DateTime.now().millisecondsSinceEpoch % 10000}',
          projectId: projectId,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          contractorName: _contractorCtrl.text.trim(),
          estimatedCost: cost.toDouble(),
          duration: durationStr,
          startDate: _startDate,
          endDate: _endDate,
          status: _status,
          owner: _ownerCtrl.text.trim().isEmpty
              ? 'Unassigned'
              : _ownerCtrl.text.trim(),
          createdAt: widget.initialContract?.createdAt ?? DateTime.now(),
        );
        Navigator.of(context).pop(contract);
      },
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DialogSectionTitle(
              title: 'Contract basics',
              subtitle: 'Identify the agreement and parties.',
            ),
            VoiceTextFormField(
              controller: _titleCtrl,
              decoration: _dialogDecoration(
                  label: 'Contract item',
                  hint: 'e.g. Electrical Services Agreement'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Title is required.'
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: VoiceTextFormField(
                    controller: _contractorCtrl,
                    decoration: _dialogDecoration(
                        label: 'Contractor', hint: 'e.g. Acme Electric'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Required.'
                            : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: VoiceTextFormField(
                    controller: _ownerCtrl,
                    decoration: _dialogDecoration(
                        label: 'Contract Owner', hint: 'e.g. T. Ndlovu'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            VoiceTextFormField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: _dialogDecoration(
                  label: 'Scope description',
                  hint: 'Brief summary of services...'),
            ),
            const SizedBox(height: 18),
            const DialogSectionTitle(
              title: 'Terms & Value',
              subtitle: 'Set the financial and timeline bounds.',
            ),
            const SizedBox(height: 8),
            VoiceTextFormField(
              controller: _costCtrl,
              keyboardType: TextInputType.number,
              decoration: _dialogDecoration(
                  label: 'Total Value',
                  hint: 'e.g. 150000',
                  prefixIcon: const Icon(Icons.attach_money)),
              validator: (value) {
                final amount = _parseCurrency(value ?? '');
                return amount <= 0 ? 'Enter value.' : null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(DateTime.now().year + 5),
                      );
                      if (picked == null) return;
                      setState(() => _startDate = picked);
                    },
                    child: InputDecorator(
                      decoration: _dialogDecoration(
                          label: 'Start Date',
                          prefixIcon: const Icon(Icons.calendar_today)),
                      child: Text(
                        _startDate == null
                            ? 'Select'
                            : _formatDisplayDate(_startDate!),
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _startDate != null
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate ??
                            DateTime.now().add(const Duration(days: 90)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(DateTime.now().year + 5),
                      );
                      if (picked == null) return;
                      setState(() => _endDate = picked);
                    },
                    child: InputDecorator(
                      decoration: _dialogDecoration(
                          label: 'End Date',
                          prefixIcon: const Icon(Icons.event_busy)),
                      child: Text(
                        _endDate == null
                            ? 'Select'
                            : _formatDisplayDate(_endDate!),
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _endDate != null
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ContractStatus>(
              value: _status,
              decoration: _dialogDecoration(label: 'Status'),
              items: ContractStatus.values.map((option) {
                final words = option.name
                    .split('_')
                    .where((word) => word.trim().isNotEmpty)
                    .map((word) =>
                        '${word[0].toUpperCase()}${word.substring(1)}')
                    .toList();
                return DropdownMenuItem(
                  value: option,
                  child: Text(words.join(' ')),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _status = value);
              },
            ),
          ],
        ),
      ),
    );
  }
}
