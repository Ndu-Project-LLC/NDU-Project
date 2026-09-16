import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ndu_project/models/acceptance_criteria.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';

// Mirrors the Acceptance Criteria Planning screen's palette so the modal reads
// as part of that page instead of a generic system dialog.
const Color _kHeadline = Color(0xFF111827);
const Color _kMuted = Color(0xFF6B7280);
const Color _kBorder = Color(0xFFE5E7EB);
const Color _kAccent = Color(0xFFD97706);

/// The bundle of criteria a brand new template starts from.
///
/// The dialog used to add a template with two blank criteria and *no* way to
/// say anything else about it — every other choice (name, work item type,
/// format, what the criteria should be) had to be made afterwards, field by
/// field, in the editor below. Picking a starting point here is the difference
/// between a usable template and an empty one.
class _CriteriaSeed {
  const _CriteriaSeed(this.label, this.hint, this.categories);

  final String label;
  final String hint;
  final List<CriterionCategory> categories;
}

const List<_CriteriaSeed> _kSeeds = <_CriteriaSeed>[
  _CriteriaSeed(
    'Starter set',
    'Functional + Non-Functional, ready to fill in',
    <CriterionCategory>[
      CriterionCategory.functional,
      CriterionCategory.nonFunctional,
    ],
  ),
  _CriteriaSeed(
    'Quality pack',
    'Security + Performance + Accessibility',
    <CriterionCategory>[
      CriterionCategory.security,
      CriterionCategory.performance,
      CriterionCategory.accessibility,
    ],
  ),
  _CriteriaSeed(
    'Complete set',
    'One criterion for every category',
    CriterionCategory.values,
  ),
  _CriteriaSeed(
    'Start empty',
    'Add criteria yourself later',
    <CriterionCategory>[],
  ),
];

/// Collects everything needed to create an acceptance criteria template, then
/// returns it — nothing is added to the page until the caller accepts it.
class AcceptanceCriteriaTemplateDialog extends StatefulWidget {
  const AcceptanceCriteriaTemplateDialog({
    super.key,
    this.initialWorkItemType = WorkItemType.userStory,
    this.initialFormat = AcFormat.checklist,
    this.existingTemplates = const <AcceptanceCriteriaTemplate>[],
  });

  /// Work item type the page is currently filtered to.
  final WorkItemType initialWorkItemType;

  /// Format the page is currently editing with.
  final AcFormat initialFormat;

  /// Used for the duplicate-name guard and the "N already exist" hint, so the
  /// user is told about a clash before they create it rather than after.
  final List<AcceptanceCriteriaTemplate> existingTemplates;

  /// Shows the modal and resolves to the created template, or `null` if the
  /// user backed out.
  static Future<AcceptanceCriteriaTemplate?> show(
    BuildContext context, {
    WorkItemType initialWorkItemType = WorkItemType.userStory,
    AcFormat initialFormat = AcFormat.checklist,
    List<AcceptanceCriteriaTemplate> existingTemplates =
        const <AcceptanceCriteriaTemplate>[],
  }) {
    return showDialog<AcceptanceCriteriaTemplate>(
      context: context,
      // A half-filled form should not vanish because the backdrop was tapped;
      // Cancel (or Esc) is how the user says no.
      barrierDismissible: false,
      builder: (_) => AcceptanceCriteriaTemplateDialog(
        initialWorkItemType: initialWorkItemType,
        initialFormat: initialFormat,
        existingTemplates: existingTemplates,
      ),
    );
  }

  @override
  State<AcceptanceCriteriaTemplateDialog> createState() =>
      _AcceptanceCriteriaTemplateDialogState();
}

class _AcceptanceCriteriaTemplateDialogState
    extends State<AcceptanceCriteriaTemplateDialog> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  late WorkItemType _workItemType = widget.initialWorkItemType;
  late AcFormat _format = widget.initialFormat;
  _CriteriaSeed _seed = _kSeeds.first;

  String get _name => _nameCtrl.text.trim();

  /// A template already using this name for this work item type. Names are
  /// compared case-insensitively and trimmed, because "Login flow" and
  /// "login flow " are the same template to a reader.
  AcceptanceCriteriaTemplate? get _clash {
    final key = _name.toLowerCase();
    if (key.isEmpty) return null;
    for (final t in widget.existingTemplates) {
      if (t.workItemType == _workItemType &&
          t.name.trim().toLowerCase() == key) {
        return t;
      }
    }
    return null;
  }

  /// Shown under the field instead of blocking the button silently — an empty
  /// name is not an error until the user has typed something.
  String? get _nameError {
    if (_name.isEmpty) return null;
    if (_clash != null) {
      return 'A ${_workItemType.label} template with this name already exists.';
    }
    return null;
  }

  bool get _canCreate => _name.isNotEmpty && _nameError == null;

  int get _siblingCount => widget.existingTemplates
      .where((t) => t.workItemType == _workItemType)
      .length;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged() => setState(() {});

  void _create() {
    if (!_canCreate) return;
    final template = AcceptanceCriteriaTemplate(
      name: _name,
      description: _descCtrl.text.trim(),
      workItemType: _workItemType,
      format: _format,
      criteria: <AcceptanceCriterion>[
        for (final category in _seed.categories)
          AcceptanceCriterion(description: '', category: category),
      ],
    );
    Navigator.of(context).pop(template);
  }

  String get _summary {
    final criteria = _seed.categories.length;
    final criteriaLabel = criteria == 0
        ? 'no criteria yet'
        : '$criteria ${criteria == 1 ? 'criterion' : 'criteria'}';
    final siblings = _siblingCount;
    final existing = siblings == 0
        ? 'You will have the first ${_workItemType.label} template.'
        : '${_workItemType.label} already has $siblings '
            '${siblings == 1 ? 'template' : 'templates'}.';
    return 'Creates a ${_workItemType.label} template in '
        '${_format.label} with $criteriaLabel. $existing';
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    // Escape cancels, exactly like Cancel and the X in the header.
    //
    // This has to be wired up by hand. `barrierDismissible: false` below is
    // what stops a stray backdrop tap throwing away a half-filled form, but
    // Flutter's own Escape-to-dismiss is only enabled when the route *is*
    // barrier-dismissible -- `_DismissModalAction.isEnabled` returns
    // `route.barrierDismissible` -- so with the barrier off, Escape did
    // nothing at all and the modal sat there blocking the page.
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: screen.height * 0.9,
          ),
          // The fields scroll but Cancel / Create stay pinned to the bottom, so
          // on a short window the way out is never scrolled off the screen.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(context),
                      const SizedBox(height: 18),
                      _nameField(),
                      const SizedBox(height: 14),
                      _descriptionField(),
                      const SizedBox(height: 14),
                      _typeAndFormat(),
                      const SizedBox(height: 14),
                      _seedPicker(),
                      const SizedBox(height: 16),
                      _summaryBanner(),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: _actions(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _kAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child:
              const Icon(Icons.playlist_add_check, size: 20, color: _kAccent),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New template',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              SizedBox(height: 2),
              Text(
                'Name it, choose where it belongs, and pick the criteria to start from.',
                style: TextStyle(fontSize: 12, color: _kMuted),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, size: 20, color: _kMuted),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kAccent, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.6),
      ),
    );
  }

  Widget _nameField() {
    return VoiceTextFormField(
      controller: _nameCtrl,
      autofocus: true,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.sentences,
      onFieldSubmitted: (_) {
        if (_canCreate) _create();
      },
      decoration: _decoration('Template name', hint: 'e.g. Checkout flow'),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }

  Widget _descriptionField() {
    return VoiceTextFormField(
      controller: _descCtrl,
      minLines: 2,
      maxLines: 4,
      decoration: _decoration('Description',
          hint: 'What this template is for (optional)'),
      validator: (_) => null,
    );
  }

  Widget _typeAndFormat() {
    // Two dropdowns side by side, stacked when the modal is narrow.
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 420;
        final fields = <Widget>[
          _dropdown<WorkItemType>(
            label: 'Work item type',
            value: _workItemType,
            values: WorkItemType.values,
            labelOf: (t) => t.label,
            // The duplicate check and the "N already exist" hint are both per
            // work item type, so switching type re-runs them in build.
            onChanged: (v) => setState(() => _workItemType = v),
          ),
          _dropdown<AcFormat>(
            label: 'Format',
            value: _format,
            values: AcFormat.values,
            labelOf: (f) => f.label,
            onChanged: (v) => setState(() => _format = v),
          ),
        ];
        if (narrow) {
          return Column(
            children: [
              fields[0],
              const SizedBox(height: 14),
              fields[1],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: fields[0]),
            const SizedBox(width: 12),
            Expanded(child: fields[1]),
          ],
        );
      },
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> values,
    required String Function(T) labelOf,
    required ValueChanged<T> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      isExpanded: true,
      initialValue: value,
      items: <DropdownMenuItem<T>>[
        for (final v in values)
          DropdownMenuItem<T>(
            value: v,
            child: Text(labelOf(v),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      decoration: _decoration(label),
    );
  }

  Widget _seedPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<_CriteriaSeed>(
          key: const ValueKey('acSeedDropdown'),
          isExpanded: true,
          initialValue: _seed,
          items: <DropdownMenuItem<_CriteriaSeed>>[
            for (final seed in _kSeeds)
              DropdownMenuItem<_CriteriaSeed>(
                value: seed,
                child: Text(seed.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13)),
              ),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _seed = v);
          },
          decoration: _decoration('Starting criteria'),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 2),
          child: Text(_seed.hint,
              style: const TextStyle(fontSize: 11.5, color: _kMuted)),
        ),
      ],
    );
  }

  Widget _summaryBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kAccent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: _kAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_summary,
                    style: const TextStyle(fontSize: 12, color: _kHeadline)),
                if (_nameError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_nameError!,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626))),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: _kMuted),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _canCreate ? _create : null,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Create template'),
          style: FilledButton.styleFrom(
            backgroundColor: _kAccent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _kBorder,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
      ],
    );
  }
}
