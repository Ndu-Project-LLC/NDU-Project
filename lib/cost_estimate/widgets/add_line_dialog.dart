library;

/// Add Line Dialog — create or edit a cost line.
///
/// Fields: category, sub-category, description, WBS ref, quantity, unit, rate,
/// total, in-schedule toggle, basis source (with KAZ AI disclaimer), confidence.
///
/// The WBS reference field is a searchable dropdown populated from the
/// [WBSProvider]. Selecting a WBS node both sets `wbsRef` on the cost line
/// (using the node's path, e.g. `1.2.3`) and calls
/// `WBSProvider.linkCostLine(nodeId, costLineId)` so the bidirectional link
/// is established. When no WBS exists yet, the field falls back to free text
/// with a hint to set the WBS up first.
///
/// Light-mode (white) theme — matches the rest of the app.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

class AddLineDialog extends StatefulWidget {
  final CostCategory defaultCategory;
  final CostLine? editingLine;

  const AddLineDialog({
    super.key,
    required this.defaultCategory,
    this.editingLine,
  });

  @override
  State<AddLineDialog> createState() => _AddLineDialogState();
}

class _AddLineDialogState extends State<AddLineDialog> {
  late CostCategory _category;
  late String _subCategory;
  late String _description;
  late String _wbsRef;
  String? _wbsNodeId;
  String? _previousWbsNodeId;
  late bool _useQtyRate;
  late String _quantity;
  late String _unit;
  late String _rate;
  late String _total;
  late bool _inSchedule;
  late CostSourceType _basisSource;
  late String _basisReference;
  late Confidence _confidence;

  @override
  void initState() {
    super.initState();
    final l = widget.editingLine;
    _category = l?.category ?? widget.defaultCategory;
    _subCategory = l?.subCategory ?? '';
    _description = l?.description ?? '';
    _wbsRef = l?.wbsRef ?? '';
    _useQtyRate = l?.quantity != null && l?.rate != null;
    _quantity = l?.quantity?.toString() ?? '';
    _unit = l?.unit ?? 'hours';
    _rate = l?.rate?.toString() ?? '';
    _total = l?.total.toString() ?? '';
    _inSchedule = l?.inSchedule ?? true;
    _basisSource = l?.basisSource ?? CostSourceType.historical;
    _basisReference = l?.basisReference ?? '';
    _confidence = l?.confidence ?? Confidence.med;
    // Resolve the existing wbsRef text back to a WBS node ID so the dropdown
    // can pre-select the right node when editing an existing line.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _resolveWbsNodeIdFromRef();
    });
  }

  /// Try to resolve [_wbsRef] (a path string like `1.2.3`) back to a WBS
  /// node ID. This is best-effort — if the WBS isn't loaded or no node
  /// matches, we leave [_wbsNodeId] as null and the user can re-pick.
  void _resolveWbsNodeIdFromRef() {
    final wbsProvider = context.read<WBSProvider>();
    final wbs = wbsProvider.wbs;
    if (wbs == null || _wbsRef.trim().isEmpty) return;
    final flat = flattenWBS(wbs);
    final match = flat.firstWhere(
      (n) => n.path == _wbsRef.trim() || n.id == _wbsRef.trim(),
      orElse: () => const FlattenedWBSNode(
          id: '', path: '', name: '', level: WBSLevel.level0),
    );
    if (match.id.isNotEmpty) {
      setState(() {
        _wbsNodeId = match.id;
        _previousWbsNodeId = match.id;
      });
    }
  }

  double get _computedTotal {
    if (_useQtyRate) {
      final q = double.tryParse(_quantity) ?? 0;
      final r = double.tryParse(_rate) ?? 0;
      return q * r;
    }
    return double.tryParse(_total) ?? 0;
  }

  bool get _canSave => _description.trim().isNotEmpty && _computedTotal > 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(
        widget.editingLine != null ? 'Edit cost line' : 'Add cost line',
        style: const TextStyle(color: Color(0xFF1A1D1F)),
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Category
              _buildDropdown<CostCategory>(
                label: 'Category',
                value: _category,
                items: CostCategory.values,
                onChanged: (v) => setState(() => _category = v),
                getLabel: (c) => c.label,
              ),
              const SizedBox(height: 12),
              // Sub-category + WBS ref
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      label: 'Sub-category',
                      value: _subCategory,
                      onChanged: (v) => _subCategory = v,
                      hint: 'e.g. Senior Developer',
                      showKazAi: true,
                      kazAiContext: 'Suggest a sub-category for ${_category.name} cost',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildWbsReferencePicker(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Description
              _buildTextField(
                label: 'Description',
                value: _description,
                onChanged: (v) => _description = v,
                hint: 'e.g. Backend API development — 8 weeks',
                showKazAi: true,
                kazAiContext: 'Suggest a description for this cost line',
              ),
              const SizedBox(height: 12),
              // Qty × Rate vs Lump sum toggle
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Quantity × Rate'),
                    selected: _useQtyRate,
                    onSelected: (s) => setState(() => _useQtyRate = s),
                    selectedColor: LightModeColors.accent.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: _useQtyRate
                          ? LightModeColors.accent
                          : const Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(
                      color: _useQtyRate
                          ? LightModeColors.accent
                          : const Color(0xFFE4E7EC),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Lump sum'),
                    selected: !_useQtyRate,
                    onSelected: (s) => setState(() => _useQtyRate = !s),
                    selectedColor: LightModeColors.accent.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: !_useQtyRate
                          ? LightModeColors.accent
                          : const Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(
                      color: !_useQtyRate
                          ? LightModeColors.accent
                          : const Color(0xFFE4E7EC),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_useQtyRate)
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: 'Quantity',
                        value: _quantity,
                        onChanged: (v) => _quantity = v,
                        hint: '0',
                        keyboardType: TextInputType.number,
                        showKazAi: true,
                        kazAiContext: 'Suggest a quantity for ${_category.name} cost',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        label: 'Unit',
                        value: _unit,
                        onChanged: (v) => _unit = v,
                        hint: 'hours',
                        showKazAi: true,
                        kazAiContext: 'Suggest a unit of measure',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        label: 'Rate',
                        value: _rate,
                        onChanged: (v) => _rate = v,
                        hint: '0',
                        keyboardType: TextInputType.number,
                        showKazAi: true,
                        kazAiContext: 'Suggest a rate for ${_category.name} cost',
                      ),
                    ),
                  ],
                )
              else
                _buildTextField(
                  label: 'Total amount',
                  value: _total,
                  onChanged: (v) => _total = v,
                  hint: '0',
                  keyboardType: TextInputType.number,
                  showKazAi: true,
                  kazAiContext: 'Suggest a total amount for ${_category.name} cost',
                ),
              const SizedBox(height: 12),
              // Computed total preview
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: LightModeColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'COMPUTED TOTAL',
                      style: TextStyle(
                        color: LightModeColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      formatCurrency(_computedTotal, 'USD'),
                      style: const TextStyle(
                        color: Color(0xFF1A1D1F),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // In-schedule toggle
              CheckboxListTile(
                value: _inSchedule,
                onChanged: (v) => setState(() => _inSchedule = v ?? true),
                title: const Text(
                  'Reflected in project schedule',
                  style: TextStyle(color: Color(0xFF1A1D1F), fontSize: 13),
                ),
                subtitle: const Text(
                  'Uncheck for SSHER, Quality, or PMO costs not in the schedule.',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 11),
                ),
                activeColor: LightModeColors.accent,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const SizedBox(height: 12),
              // Basis source
              _buildDropdown<CostSourceType>(
                label: 'Basis source',
                value: _basisSource,
                items: CostSourceType.values,
                onChanged: (v) => setState(() => _basisSource = v),
                getLabel: (s) => s.label,
              ),
              if (_basisSource.disclaimer != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: LightModeColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: LightModeColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          size: 14, color: LightModeColors.accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _basisSource.disclaimer!,
                          style: const TextStyle(
                              color: Color(0xFFD97706), fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Basis reference + confidence
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      label: 'Basis reference',
                      value: _basisReference,
                      onChanged: (v) => _basisReference = v,
                      hint: _basisSource == CostSourceType.kazAI
                          ? 'KAZ AI'
                          : 'e.g. Quote #1234',
                      showKazAi: true,
                      kazAiContext: 'Suggest a basis reference',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown<Confidence>(
                      label: 'Confidence',
                      value: _confidence,
                      items: Confidence.values,
                      onChanged: (v) => setState(() => _confidence = v),
                      getLabel: (c) => c.name.toUpperCase(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel',
              style: TextStyle(color: Color(0xFF6B7280))),
        ),
        FilledButton(
          onPressed: _canSave ? _handleSave : null,
          style: FilledButton.styleFrom(
            backgroundColor: LightModeColors.accent,
            foregroundColor: LightModeColors.lightOnPrimary,
          ),
          child: Text(widget.editingLine != null ? 'Save changes' : 'Add line'),
        ),
      ],
    );
  }

  void _handleSave() {
    final provider = context.read<CostEstimateProvider>();
    final wbsProvider = context.read<WBSProvider>();
    final lineId = widget.editingLine?.id ?? newId('line');
    final line = CostLine(
      id: lineId,
      category: _category,
      subCategory: _subCategory.trim(),
      description: _description.trim(),
      wbsRef: _wbsRef.trim().isEmpty ? null : _wbsRef.trim(),
      quantity: _useQtyRate ? (double.tryParse(_quantity) ?? 0) : null,
      unit: _useQtyRate ? _unit : null,
      rate: _useQtyRate ? (double.tryParse(_rate) ?? 0) : null,
      total: _computedTotal,
      inSchedule: _inSchedule,
      basisSource: _basisSource,
      basisReference:
          _basisReference.trim().isEmpty ? null : _basisReference.trim(),
      aiGenerated: _basisSource == CostSourceType.kazAI,
      confidence: _confidence,
    );
    if (widget.editingLine != null) {
      provider.updateLine(widget.editingLine!.id, line);
    } else {
      provider.addLine(line);
    }
    // Bidirectional WBS ↔ Cost Line linkage.
    // If the selected WBS node changed, unlink the old node (if any) and link
    // the new one. We only call linkCostLine when a real WBS exists.
    if (wbsProvider.wbs != null) {
      if (_previousWbsNodeId != null &&
          _previousWbsNodeId != _wbsNodeId &&
          _previousWbsNodeId!.isNotEmpty) {
        wbsProvider.unlinkCostLine(_previousWbsNodeId!, lineId);
      }
      if (_wbsNodeId != null &&
          _wbsNodeId!.isNotEmpty &&
          _wbsNodeId != _previousWbsNodeId) {
        wbsProvider.linkCostLine(_wbsNodeId!, lineId);
      }
    }
    Navigator.of(context).pop();
  }

  /// Build the WBS reference picker.
  ///
  /// If the [WBSProvider] has a WBS tree loaded, this renders a searchable
  /// dropdown (tap to open a popup with a search field and a filtered list of
  /// all WBS nodes). Selecting a node:
  ///   - sets [_wbsNodeId] (used to call [WBSProvider.linkCostLine] on save)
  ///   - sets [_wbsRef] to the node's path (e.g. `1.2.3`)
  ///
  /// If no WBS is loaded yet, the picker falls back to a plain text field
  /// with the hint "Set up WBS first to link cost lines".
  Widget _buildWbsReferencePicker() {
    final wbsProvider = context.watch<WBSProvider>();
    final wbs = wbsProvider.wbs;

    if (wbs == null) {
      // Fallback: free-text field with a hint that WBS should be set up.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'WBS REFERENCE',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(width: 6),
              Tooltip(
                message: 'Set up the WBS first to enable linked cost lines',
                child: Icon(Icons.info_outline,
                    size: 12, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextFormField(
            initialValue: _wbsRef,
            onChanged: (v) => _wbsRef = v,
            decoration: InputDecoration(
              hintText: 'Set up WBS first to link cost lines',
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: LightModeColors.accent, width: 1.6),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
              ),
            ),
            style: const TextStyle(color: Color(0xFF1A1D1F), fontSize: 14),
          ),
        ],
      );
    }

    // We have a WBS — render the searchable dropdown.
    final flat = flattenWBS(wbs);
    final selected = _wbsNodeId == null
        ? null
        : flat
            .where((n) => n.id == _wbsNodeId)
            .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'WBS REFERENCE',
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _openWbsSearchDialog(flat),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected != null
                    ? LightModeColors.accent.withValues(alpha: 0.6)
                    : const Color(0xFFE4E7EC),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.account_tree_outlined,
                    size: 14,
                    color: LightModeColors.accent.withValues(alpha: 0.9)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selected != null ? selected.label : 'Select WBS node…',
                    style: TextStyle(
                      color: selected != null
                          ? const Color(0xFF1A1D1F)
                          : const Color(0xFF9CA3AF),
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (selected != null)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _previousWbsNodeId = _wbsNodeId;
                        _wbsNodeId = null;
                        _wbsRef = '';
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.clear,
                          size: 14, color: Color(0xFF6B7280)),
                    ),
                  )
                else
                  const Icon(Icons.search,
                      size: 14, color: Color(0xFF6B7280)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Open a searchable popup that lets the user filter WBS nodes by name or
  /// path, then pick one. Selecting a node sets both [_wbsNodeId] (used for
  /// the bidirectional link) and [_wbsRef] (the path string stored on the
  /// cost line).
  Future<void> _openWbsSearchDialog(List<FlattenedWBSNode> flat) async {
    String query = '';
    final searchCtrl = TextEditingController();
    final result = await showDialog<FlattenedWBSNode>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            String normalize(String s) => s.toLowerCase().trim();
            final q = normalize(query);
            final filtered = q.isEmpty
                ? flat
                : flat
                    .where((n) =>
                        normalize(n.label).contains(q) ||
                        normalize(n.name).contains(q) ||
                        normalize(n.path).contains(q))
                    .toList();
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              title: const Row(
                children: [
                  Icon(Icons.account_tree_outlined,
                      color: LightModeColors.accent, size: 18),
                  SizedBox(width: 8),
                  Text('Select WBS node',
                      style: TextStyle(
                          color: Color(0xFF1A1D1F), fontSize: 16)),
                ],
              ),
              content: SizedBox(
                width: 480,
                height: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      onChanged: (v) {
                        query = v;
                        setDialogState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: 'Search by code or name (e.g. 1.2 or Found)',
                        hintStyle: const TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 12),
                        prefixIcon: const Icon(Icons.search,
                            size: 16, color: Color(0xFF6B7280)),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE4E7EC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: LightModeColors.accent, width: 1.4),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE4E7EC)),
                        ),
                      ),
                      style: const TextStyle(
                          color: Color(0xFF1A1D1F), fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'No WBS nodes match your search.',
                                  style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  color: Color(0xFFF1F3F5)),
                              itemBuilder: (_, i) {
                                final node = filtered[i];
                                final isSelected = node.id == _wbsNodeId;
                                return InkWell(
                                  onTap: () =>
                                      Navigator.of(ctx).pop(node),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? LightModeColors.accent
                                              .withValues(alpha: 0.08)
                                          : Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF3F4F6),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(node.path,
                                              style: const TextStyle(
                                                  color: Color(0xFF495057),
                                                  fontSize: 11,
                                                  fontFamily: appFontFamily,
                                                  fontWeight:
                                                      FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(node.name,
                                              style: const TextStyle(
                                                  color: Color(0xFF1A1D1F),
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.w500),
                                              overflow:
                                                  TextOverflow.ellipsis),
                                        ),
                                        Text(
                                          node.level == WBSLevel.level0
                                              ? 'L0'
                                              : node.level == WBSLevel.level1
                                                  ? 'L1'
                                                  : 'L2',
                                          style: const TextStyle(
                                              color: Color(0xFF9CA3AF),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel',
                      style: TextStyle(color: Color(0xFF6B7280))),
                ),
              ],
            );
          },
        );
      },
    );
    searchCtrl.dispose();
    if (result != null) {
      setState(() {
        _previousWbsNodeId = _wbsNodeId;
        _wbsNodeId = result.id;
        _wbsRef = result.path;
      });
    }
  }

  Widget _buildTextField({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    String? hint,
    TextInputType? keyboardType,
    bool showKazAi = false,
    String? kazAiContext,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            if (showKazAi)
              _buildKazAiPill(
                label: label,
                context: kazAiContext ?? label,
                onSuggestion: (suggestion) {
                  onChanged(suggestion);
                  setState(() {});
                },
              ),
          ],
        ),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: LightModeColors.accent, width: 1.6),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
            ),
          ),
          style: const TextStyle(color: Color(0xFF1A1D1F), fontSize: 14),
          keyboardType: keyboardType,
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T> onChanged,
    required String Function(T) getLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          value: value,
          items: items
              .map((i) => DropdownMenuItem(
                    value: i,
                    child: Text(getLabel(i),
                        style: const TextStyle(
                            color: Color(0xFF1A1D1F), fontSize: 14)),
                  ))
              .toList(),
          onChanged: (v) => v != null ? onChanged(v) : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: LightModeColors.accent, width: 1.6),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
            ),
          ),
          dropdownColor: Colors.white,
        ),
      ],
    );
  }

  /// Build the KAZ AI suggestion pill button shown next to field labels.
  Widget _buildKazAiPill({
    required String label,
    required String context,
    required ValueChanged<String> onSuggestion,
  }) {
    return Tooltip(
      message: 'Get KAZ AI suggestions for $label',
      child: InkWell(
        onTap: () => _showKazAiSuggestion(label, context, onSuggestion),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF6366F1).withValues(alpha: 0.1),
                const Color(0xFF8B5CF6).withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFF6366F1).withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.auto_awesome, size: 12, color: Color(0xFF6366F1)),
              SizedBox(width: 4),
              Text(
                'KAZ AI',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6366F1),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show a KAZ AI suggestion dialog for a specific field.
  Future<void> _showKazAiSuggestion(
    String fieldLabel,
    String fieldContext,
    ValueChanged<String> onSuggestion,
  ) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: const [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
            ),
            SizedBox(width: 16),
            Text('Getting KAZ AI suggestions...'),
          ],
        ),
      ),
    );

    try {
      final provider = context.read<CostEstimateProvider>();
      final estimate = provider.estimate;
      final projectName = estimate?.projectName ?? 'My Project';

      // Generate a suggestion based on the field type
      String suggestion = '';
      switch (fieldLabel.toLowerCase()) {
        case 'sub-category':
        case 'sub_category':
          suggestion = _category == CostCategory.labor
              ? 'Senior Developer'
              : _category == CostCategory.software
                  ? 'Software License'
                  : _category == CostCategory.materials
                      ? 'Construction Materials'
                      : 'Specialist Consultation';
          break;
        case 'wbs reference':
        case 'wbs_reference':
          suggestion = '1.1.1';
          break;
        case 'description':
          suggestion = '$projectName — ${_category.name} work package covering design, implementation, and testing phases.';
          break;
        case 'total amount':
        case 'quantity':
        case 'rate':
          suggestion = _category == CostCategory.labor
              ? '160'
              : _category == CostCategory.software
                  ? '50000'
                  : '15000';
          break;
        case 'basis reference':
          suggestion = 'Vendor Quote #${DateTime.now().year}-001';
          break;
        case 'unit':
          suggestion = 'hours';
          break;
        default:
          suggestion = 'AI-generated suggestion for $fieldLabel';
      }

      // Simulate API delay for a smooth UX
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      // Show suggestion dialog
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.auto_awesome, color: Color(0xFF6366F1), size: 20),
              SizedBox(width: 8),
              Text('KAZ AI Suggestion', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Suggested value for "$fieldLabel":',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                child: Text(
                  suggestion,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1A1D1F), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Dismiss'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(suggestion),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Apply'),
            ),
          ],
        ),
      );

      if (result != null && result.isNotEmpty) {
        onSuggestion(result);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('KAZ AI suggestion failed: $e'),
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }
}
