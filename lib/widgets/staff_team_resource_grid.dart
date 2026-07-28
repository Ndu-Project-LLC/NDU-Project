import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ndu_project/models/staffing_row.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/table_import_helper.dart';
import 'dart:async';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';

class StaffTeamResourceGrid extends StatefulWidget {
  const StaffTeamResourceGrid({
    super.key,
    required this.rows,
    required this.onRowsChanged,
  });

  final List<StaffingRow> rows;
  final ValueChanged<List<StaffingRow>> onRowsChanged;

  @override
  State<StaffTeamResourceGrid> createState() => _StaffTeamResourceGridState();
}

class _StaffTeamResourceGridState extends State<StaffTeamResourceGrid> {
  List<StaffingRow> get _rows => widget.rows;
  List<String> _aiSuggestions = [];
  bool _loadingSuggestions = false;
  String? _suggestionError;

  @override
  void initState() {
    super.initState();
    _loadAiSuggestions();
  }

  Future<void> _loadAiSuggestions() async {
    setState(() {
      _loadingSuggestions = true;
      _suggestionError = null;
    });

    try {
      final data = ProjectDataHelper.getData(context);
      final contextText = ProjectDataHelper.buildExecutivePlanContext(
        data,
        sectionLabel: 'Staff Team Orchestration',
      );

      if (contextText.trim().isEmpty) {
        setState(() {
          _aiSuggestions = [];
          _loadingSuggestions = false;
        });
        return;
      }

      final ai = OpenAiServiceSecure();
      final suggestions = await ai.generateStaffingRoleSuggestions(
        context: contextText,
        maxSuggestions: 4,
      );

      if (mounted) {
        setState(() {
          _aiSuggestions = suggestions;
          _loadingSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestionError = e.toString();
          _loadingSuggestions = false;
          _aiSuggestions = [];
        });
      }
    }
  }

  void _addSuggestion(String roleName) {
    final newRow = StaffingRow(
      role: roleName,
      quantity: 1,
      isInternal: true,
      status: 'Not Started',
    );
    final updated = [..._rows, newRow];
    widget.onRowsChanged(updated);
  }

  void _addNewRow() {
    _showAddRoleModal();
  }

  /// World-class modal dialog for adding a new staffing role.
  void _showAddRoleModal() {
    final roleController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final startDateController = TextEditingController();
    final durationController = TextEditingController();
    final costController = TextEditingController();
    final descController = TextEditingController();
    final notesController = TextEditingController();
    bool isInternal = true;
    String status = 'Not Started';
    bool aiLoading = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 24,
          child: Container(
            width: 560,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──
                Container(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded, size: 22, color: Color(0xFF4338CA)),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Add Staffing Role', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                            SizedBox(height: 2),
                            Text('Define the role, timeline, and cost details', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF6B7280)),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),
                // ── Form Body ──
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Role Name
                        _ModalField(
                          label: 'Role / Capability',
                          controller: roleController,
                          hint: 'e.g. Senior Cloud Architect',
                          icon: Icons.work_outline_rounded,
                          autofocus: true,
                        ),
                        const SizedBox(height: 16),
                        // Qty + Type row
                        Row(
                          children: [
                            Expanded(
                              child: _ModalField(
                                label: 'Quantity',
                                controller: qtyController,
                                hint: '1',
                                icon: Icons.groups_outlined,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ModalField(
                                label: 'Start Date',
                                controller: startDateController,
                                hint: 'Month 1',
                                icon: Icons.calendar_today_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _ModalField(
                                label: 'Duration (months)',
                                controller: durationController,
                                hint: '6',
                                icon: Icons.schedule_rounded,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ModalField(
                                label: 'Monthly Rate',
                                controller: costController,
                                hint: '5000',
                                icon: Icons.attach_money_rounded,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Type + Status
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                                  const SizedBox(height: 6),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE5E7EB)),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: DropdownButton<bool>(
                                      value: isInternal,
                                      isExpanded: true,
                                      underline: const SizedBox(),
                                      iconSize: 18,
                                      style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                                      items: const [
                                        DropdownMenuItem(value: true, child: Text('Internal')),
                                        DropdownMenuItem(value: false, child: Text('External')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) setModalState(() => isInternal = v);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                                  const SizedBox(height: 6),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE5E7EB)),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: DropdownButton<String>(
                                      value: status,
                                      isExpanded: true,
                                      underline: const SizedBox(),
                                      iconSize: 18,
                                      style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                                      items: const [
                                        DropdownMenuItem(value: 'Not Started', child: Text('Not Started')),
                                        DropdownMenuItem(value: 'In Progress', child: Text('In Progress')),
                                        DropdownMenuItem(value: 'Active', child: Text('Active')),
                                        DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) setModalState(() => status = v);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Description
                        const Text('Role Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                        const SizedBox(height: 6),
                        TextField(
                          controller: descController,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Brief description of responsibilities...',
                            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF4338CA), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Notes
                        const Text('Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                        const SizedBox(height: 6),
                        TextField(
                          controller: notesController,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Additional notes...',
                            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF4338CA), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                // ── Footer ──
                Container(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      // KAZ AI suggestion button
                      OutlinedButton.icon(
                        onPressed: aiLoading
                            ? null
                            : () async {
                                setModalState(() => aiLoading = true);
                                try {
                                  final data = ProjectDataHelper.getData(context);
                                  final ctx = ProjectDataHelper.buildExecutivePlanContext(data, sectionLabel: 'Staff Team Orchestration');
                                  final ai = OpenAiServiceSecure();
                                  final suggestions = await ai.generateStaffingRoleSuggestions(context: ctx, maxSuggestions: 1);
                                  if (suggestions.isNotEmpty) {
                                    roleController.text = suggestions.first;
                                  }
                                } catch (_) {
                                  // silent
                                }
                                if (ctx.mounted) setModalState(() => aiLoading = false);
                              },
                        icon: aiLoading
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.auto_awesome_rounded, size: 16),
                        label: Text(aiLoading ? 'Generating...' : 'KAZ AI Suggest'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF7C3AED),
                          side: const BorderSide(color: Color(0xFFDDD6FE)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Spacer(),
                      // Cancel
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                      ),
                      const SizedBox(width: 8),
                      // Add Role
                      FilledButton.icon(
                        onPressed: () {
                          final newRow = StaffingRow(
                            role: roleController.text.trim(),
                            quantity: int.tryParse(qtyController.text) ?? 1,
                            isInternal: isInternal,
                            startDate: startDateController.text.trim(),
                            durationMonths: durationController.text.trim(),
                            monthlyCost: costController.text.trim(),
                            roleDescription: descController.text.trim(),
                            notes: notesController.text.trim(),
                            status: status,
                          );
                          final updated = [..._rows, newRow];
                          widget.onRowsChanged(updated);
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Role'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shows a world-class import dialog with Download Template, Upload File,
  /// and Paste CSV options. Uses the shared TableImportHelper.
  void _showImportDialog() async {
    final headers = [
      'Role', 'Qty', 'Type', 'Start Date', 'Duration (months)',
      'Monthly Rate', 'Status'
    ];
    final sampleRows = [
      ['Project Manager', '1', 'Internal', 'Jan 2024', '6', '4000', 'Active'],
      ['Technical Lead', '2', 'Internal', 'Jan 2024', '8', '5000', 'Active'],
      ['Business Analyst', '1', 'External', 'Feb 2024', '4', '3500', 'Not Started'],
      ['Quality Assurance', '2', 'Internal', 'Mar 2024', '6', '3000', 'Not Started'],
    ];

    final rows = await TableImportHelper.showImportDialog(
      context,
      tableTitle: 'Staffing Needs',
      headers: headers,
      sampleRows: sampleRows,
    );

    if (rows == null || rows.isEmpty || !mounted) return;

    final newRows = <StaffingRow>[];
    for (final parts in rows) {
      newRows.add(StaffingRow(
        role: parts.isNotEmpty ? parts[0] : '',
        quantity: parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1,
        isInternal: parts.length > 2
            ? parts[2].toLowerCase() != 'external'
            : true,
        startDate: parts.length > 3 ? parts[3] : '',
        durationMonths: parts.length > 4 ? parts[4] : '',
        monthlyCost: parts.length > 5 ? parts[5] : '',
        status: parts.length > 6 ? parts[6] : 'Not Started',
      ));
    }

    if (newRows.isNotEmpty) {
      widget.onRowsChanged([..._rows, ...newRows]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported ${newRows.length} rows'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Downloads a CSV template file via the browser.
  void _downloadTemplate() {
    TableImportHelper.downloadTemplate(
      filename: 'staffing_needs_template.csv',
      headers: ['Role', 'Name', 'Qty', 'Employment', 'Category', 'Location', 'Start (Mob.)', 'End (Release)', 'NDU Access', 'Status'],
      sampleRows: [
        ['Project Manager', '', '1', 'Full Time', 'Employee', 'Houston, TX', 'Jan 2024', 'Dec 2024', 'Yes', 'Active'],
        ['Technical Lead', '', '2', 'Full Time', 'Employee', 'Houston, TX', 'Jan 2024', 'Nov 2024', 'Yes', 'Active'],
        ['Business Analyst', '', '1', 'Part Time', 'Contractor', 'Remote', 'Feb 2024', 'Jun 2024', 'No', 'Not Started'],
        ['Quality Assurance', '', '2', 'Full Time', 'Employee', 'Austin, TX', 'Mar 2024', 'Sep 2024', 'Yes', 'Not Started'],
      ],
    );
  }

  void _updateRow(int index, StaffingRow updatedRow) {
    final updated = List<StaffingRow>.from(_rows);
    updated[index] = updatedRow;
    widget.onRowsChanged(updated);
  }

  Future<void> _removeRow(int index) async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Delete Staffing Row',
      itemLabel: _rows[index].role,
    );
    if (!confirmed) return;
    final updated = List<StaffingRow>.from(_rows);
    updated.removeAt(index);
    widget.onRowsChanged(updated);
  }

  int get _totalHeadcount => _rows.fold(0, (sum, row) => sum + row.quantity);
  double get _totalInvestment =>
      _rows.fold(0.0, (sum, row) => sum + row.subtotal);
  double get _internalHeadcount {
    return _rows
        .where((r) => r.isInternal)
        .fold(0, (sum, row) => sum + row.quantity)
        .toDouble();
  }

  double get _externalHeadcount {
    return _rows
        .where((r) => !r.isInternal)
        .fold(0, (sum, row) => sum + row.quantity)
        .toDouble();
  }

  double get _internalPercent {
    final total = _totalHeadcount;
    if (total == 0) return 0.0;
    return (_internalHeadcount / total) * 100;
  }

  double get _externalPercent {
    final total = _totalHeadcount;
    if (total == 0) return 0.0;
    return (_externalHeadcount / total) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryCards(),
        const SizedBox(height: 24),
        if (_aiSuggestions.isNotEmpty || _loadingSuggestions) ...[
          _buildAiSuggestions(),
          const SizedBox(height: 20),
        ],
        _buildResourceGrid(),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return LayoutBuilder(builder: (context, constraints) {
      final useCompact = constraints.maxWidth < 680;
      if (useCompact) {
        return Column(
          children: [
            _PremiumSummaryCard(
              title: 'Total Headcount',
              value: _totalHeadcount.toString(),
              icon: Icons.people_outline_rounded,
              accentColor: const Color(0xFF4338CA),
              accentBg: const Color(0xFFEEF2FF),
            ),
            const SizedBox(height: 12),
            _PremiumSummaryCard(
              title: 'Total Investment',
              value: '\$${_totalInvestment.toStringAsFixed(0)}',
              icon: Icons.account_balance_wallet_outlined,
              accentColor: const Color(0xFF059669),
              accentBg: const Color(0xFFECFDF5),
            ),
            const SizedBox(height: 12),
            _PremiumSummaryCard(
              title: 'Staffing Mix',
              value:
                  '${_internalPercent.toStringAsFixed(0)}% Int · ${_externalPercent.toStringAsFixed(0)}% Ext',
              icon: Icons.pie_chart_outline_rounded,
              accentColor: const Color(0xFFD97706),
              accentBg: const Color(0xFFFEF3C7),
            ),
          ],
        );
      }

      return Row(
        children: [
          Expanded(
              child: _PremiumSummaryCard(
            title: 'Total Headcount',
            value: _totalHeadcount.toString(),
            icon: Icons.people_outline_rounded,
            accentColor: const Color(0xFF4338CA),
            accentBg: const Color(0xFFEEF2FF),
          )),
          const SizedBox(width: 16),
          Expanded(
              child: _PremiumSummaryCard(
            title: 'Total Investment',
            value: '\$${_totalInvestment.toStringAsFixed(0)}',
            icon: Icons.account_balance_wallet_outlined,
            accentColor: const Color(0xFF059669),
            accentBg: const Color(0xFFECFDF5),
          )),
          const SizedBox(width: 16),
          Expanded(
              child: _PremiumSummaryCard(
            title: 'Staffing Mix',
            value:
                '${_internalPercent.toStringAsFixed(0)}% Int · ${_externalPercent.toStringAsFixed(0)}% Ext',
            icon: Icons.pie_chart_outline_rounded,
            accentColor: const Color(0xFFD97706),
            accentBg: const Color(0xFFFEF3C7),
          )),
        ],
      );
    });
  }

  Widget _buildAiSuggestions() {
    if (_loadingSuggestions) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Row(
          children: [
            SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Loading AI suggestions...',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ],
        ),
      );
    }

    if (_suggestionError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFC107)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, color: Color(0xFFFF9800), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Could not load AI suggestions: $_suggestionError',
                style: const TextStyle(fontSize: 13, color: Color(0xFF856404)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome,
                    size: 14, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Text(
                'KAZ AI Suggestions',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5B21B6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _aiSuggestions
                .map((role) => _PremiumSuggestionPill(
                      role: role,
                      onTap: () => _addSuggestion(role),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceGrid() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.table_chart_outlined,
                      size: 20, color: Color(0xFF4338CA)),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Staffing Needs',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Define roles, timelines, and costs for each resource',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _addNewRow,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Role'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                // Table-level Import button (matches LaunchDataTable pattern)
                OutlinedButton.icon(
                  onPressed: _showImportDialog,
                  icon: const Icon(Icons.upload_file_outlined, size: 16),
                  label: const Text('Import'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4338CA),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                // Template download button
                OutlinedButton.icon(
                  onPressed: _downloadTemplate,
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Template'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7280),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          if (_rows.isEmpty)
            _buildEmptyState()
          else ...[
            _buildTableHeader(),
            ...List.generate(_rows.length, (index) {
              final row = _rows[index];
              final isLast = index == _rows.length - 1;
              return _PremiumStaffingRow(
                row: row,
                index: index,
                onChanged: (updated) => _updateRow(index, updated),
                onDelete: () => _removeRow(index),
                showDivider: !isLast,
              );
            }),
            _buildTableFooter(),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline_rounded,
                  color: Color(0xFF9CA3AF), size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'No staff roles defined yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add roles to build your resource plan, or use KAZ AI suggestions above.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF1F2937),
      ),
      child: const Row(
        children: [
          _PremiumHeaderCell('Role', flex: 3),
          _PremiumHeaderCell('Name', flex: 2),
          _PremiumHeaderCell('Qty', flex: 1),
          _PremiumHeaderCell('Employment', flex: 2),
          _PremiumHeaderCell('Category', flex: 2),
          _PremiumHeaderCell('Location', flex: 2),
          _PremiumHeaderCell('Start (Mob.)', flex: 2),
          _PremiumHeaderCell('End (Release)', flex: 2),
          _PremiumHeaderCell('NDU Access', flex: 1),
          _PremiumHeaderCell('Status', flex: 2),
          _PremiumHeaderCell('Actions', flex: 2),
        ],
      ),
    );
  }

  Widget _buildTableFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${_rows.length} role${_rows.length == 1 ? '' : 's'} · $_totalHeadcount total headcount',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const Spacer(),
          Text(
            'Total Investment: \$${_totalInvestment.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumSummaryCard extends StatelessWidget {
  const _PremiumSummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.accentBg,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final Color accentBg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: accentColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumSuggestionPill extends StatelessWidget {
  const _PremiumSuggestionPill({
    required this.role,
    required this.onTap,
  });

  final String role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFC4B5FD)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.add, size: 12, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(
              role,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5B21B6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumHeaderCell extends StatelessWidget {
  const _PremiumHeaderCell(this.label, {required this.flex});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: TextAlign.left,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFFFFFFFF),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _PremiumStaffingRow extends StatefulWidget {
  const _PremiumStaffingRow({
    required this.row,
    required this.index,
    required this.onChanged,
    required this.onDelete,
    required this.showDivider,
  });

  final StaffingRow row;
  final int index;
  final ValueChanged<StaffingRow> onChanged;
  final VoidCallback onDelete;
  final bool showDivider;

  @override
  State<_PremiumStaffingRow> createState() => _PremiumStaffingRowState();
}

class _PremiumStaffingRowState extends State<_PremiumStaffingRow> {
  late StaffingRow _row;
  bool _isHovering = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _row = widget.row;
  }

  @override
  void didUpdateWidget(_PremiumStaffingRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row != widget.row) {
      _row = widget.row;
    }
  }

  void _updateRow(StaffingRow updated) {
    setState(() => _row = updated);
    widget.onChanged(updated);
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
        return const Color(0xFF059669);
      case 'in progress':
      case 'active':
        return const Color(0xFFD97706);
      case 'planned':
      case 'not started':
        return const Color(0xFF6B7280);
      case 'open':
      case 'at risk':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF4338CA);
    }
  }

  Color _statusBg(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
        return const Color(0xFFECFDF5);
      case 'in progress':
      case 'active':
        return const Color(0xFFFFF7E6);
      case 'planned':
      case 'not started':
        return const Color(0xFFF3F4F6);
      case 'open':
      case 'at risk':
        return const Color(0xFFFEF2F2);
      default:
        return const Color(0xFFEEF2FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) =>
          Future.microtask(() => setState(() => _isHovering = true)),
      onExit: (_) =>
          Future.microtask(() => setState(() => _isHovering = false)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: _isEditing
            ? const Color(0xFFFFFDF5)
            : (_isHovering ? const Color(0xFFF8FAFC) : Colors.white),
        child: Column(
          children: [
            // Left border accent when editing
            Container(
              decoration: _isEditing
                  ? const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Color(0xFFF59E0B), width: 3),
                      ),
                    )
                  : null,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Role ──
                  Expanded(
                    flex: 4,
                    child: _isEditing
                        ? _PremiumEditableCell(
                            value: _row.role,
                            hint: 'Role / capability',
                            onChanged: (v) => _updateRow(_row.copyWith(role: v)),
                            align: TextAlign.left,
                          )
                        : _ReadOnlyCell(
                            value: _row.role,
                            hint: '—',
                            bold: true,
                            align: TextAlign.left,
                          ),
                  ),
                  // ── Qty ──
                  Expanded(
                    flex: 1,
                    child: _isEditing
                        ? _PremiumEditableCell(
                            value: _row.quantity.toString(),
                            hint: '1',
                            onChanged: (v) {
                              final qty = int.tryParse(v) ?? 1;
                              _updateRow(_row.copyWith(quantity: qty));
                            },
                          )
                        : _ReadOnlyCell(
                            value: _row.quantity.toString(),
                            hint: '—',
                          ),
                  ),
                  // ── Type ──
                  Expanded(
                    flex: 2,
                    child: _isEditing
                        ? Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _row.isInternal
                                    ? const Color(0xFFEEF2FF)
                                    : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _row.isInternal
                                      ? const Color(0xFFC7D2FE)
                                      : const Color(0xFFFDE68A),
                                ),
                              ),
                              child: DropdownButton<bool>(
                                value: _row.isInternal,
                                isDense: true,
                                underline: const SizedBox(),
                                iconSize: 14,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _row.isInternal
                                      ? const Color(0xFF4338CA)
                                      : const Color(0xFF92400E),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: true,
                                      child: Text('Internal',
                                          style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(
                                      value: false,
                                      child: Text('External',
                                          style: TextStyle(fontSize: 12))),
                                ],
                                onChanged: (v) => v != null
                                    ? _updateRow(_row.copyWith(isInternal: v))
                                    : null,
                              ),
                            ),
                          )
                        : Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _row.isInternal
                                    ? const Color(0xFFEEF2FF)
                                    : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _row.isInternal ? 'Internal' : 'External',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _row.isInternal
                                      ? const Color(0xFF4338CA)
                                      : const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ),
                  ),
                  // ── Start Date ──
                  Expanded(
                    flex: 2,
                    child: _isEditing
                        ? _PremiumEditableCell(
                            value: _row.startDate,
                            hint: 'Start date',
                            onChanged: (v) =>
                                _updateRow(_row.copyWith(startDate: v)),
                          )
                        : _ReadOnlyCell(
                            value: _row.startDate,
                            hint: '—',
                          ),
                  ),
                  // ── Duration ──
                  Expanded(
                    flex: 2,
                    child: _isEditing
                        ? _PremiumEditableCell(
                            value: _row.durationMonths,
                            hint: 'Months',
                            onChanged: (v) =>
                                _updateRow(_row.copyWith(durationMonths: v)),
                          )
                        : _ReadOnlyCell(
                            value: _row.durationMonths,
                            hint: '—',
                          ),
                  ),
                  // ── Monthly Rate ──
                  Expanded(
                    flex: 2,
                    child: _isEditing
                        ? _PremiumEditableCell(
                            value: _row.monthlyCost,
                            hint: '\$0',
                            onChanged: (v) =>
                                _updateRow(_row.copyWith(monthlyCost: v)),
                          )
                        : _ReadOnlyCell(
                            value: _row.monthlyCost,
                            hint: '—',
                          ),
                  ),
                  // ── Subtotal (always read-only) ──
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        _row.subtotalFormatted,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                  ),
                  // ── Status ──
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusBg(_row.status),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _statusColor(_row.status).withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          _row.status,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _statusColor(_row.status),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // ── Actions ──
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: _isEditing
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check_circle_rounded,
                                      size: 18, color: Color(0xFF10B981)),
                                  onPressed: () {
                                    setState(() => _isEditing = false);
                                  },
                                  tooltip: 'Save',
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(
                                      minWidth: 28, minHeight: 28),
                                  splashRadius: 14,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 16, color: Color(0xFFEF4444)),
                                  onPressed: widget.onDelete,
                                  tooltip: 'Delete',
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(
                                      minWidth: 28, minHeight: 28),
                                  splashRadius: 14,
                                ),
                              ],
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // KAZ AI button — always visible
                                _KazAiActionButton(
                                  role: _row,
                                  onUpdated: (updated) => _updateRow(updated),
                                ),
                                if (_isHovering) ...[
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 16, color: Color(0xFF6B7280)),
                                    onPressed: () {
                                      setState(() => _isEditing = true);
                                    },
                                    tooltip: 'Edit',
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(
                                        minWidth: 28, minHeight: 28),
                                    splashRadius: 14,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 16, color: Color(0xFFEF4444)),
                                    onPressed: widget.onDelete,
                                    tooltip: 'Delete',
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(
                                        minWidth: 28, minHeight: 28),
                                    splashRadius: 14,
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.showDivider)
              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          ],
        ),
      ),
    );
  }
}

/// Read-only cell that displays plain text (not an input field).
/// Used when a row is NOT in editing mode.
class _ReadOnlyCell extends StatelessWidget {
  const _ReadOnlyCell({
    required this.value,
    required this.hint,
    this.bold = false,
    this.align = TextAlign.center,
  });

  final String value;
  final String hint;
  final bool bold;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        value.isEmpty ? hint : value,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        softWrap: false,
        textAlign: align,
        style: TextStyle(
          fontSize: 13,
          color: value.isEmpty
              ? const Color(0xFF9CA3AF)
              : const Color(0xFF111827),
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

class _PremiumEditableCell extends StatelessWidget {
  const _PremiumEditableCell({
    required this.value,
    required this.hint,
    required this.onChanged,
    this.align = TextAlign.center,
  });

  final String value;
  final String hint;
  final ValueChanged<String> onChanged;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return VoiceTextField(
      controller: TextEditingController(text: value)
        ..selection = TextSelection.collapsed(offset: value.length),
      onChanged: onChanged,
      textAlign: align,
      enableDocxImport: false, // No per-cell import — use table-level import button
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF111827),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Color(0xFF9CA3AF),
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        isDense: true,
      ),
    );
  }
}

// ─── KAZ AI Action Button ──────────────────────────────────────────────────────
/// A compact KAZ AI button shown in the Actions column of each staffing row.
/// When pressed, it calls the OpenAI service to auto-fill/suggest role details
/// for the current row using the project context.
class _KazAiActionButton extends StatefulWidget {
  const _KazAiActionButton({
    required this.role,
    required this.onUpdated,
  });

  final StaffingRow role;
  final ValueChanged<StaffingRow> onUpdated;

  @override
  State<_KazAiActionButton> createState() => _KazAiActionButtonState();
}

class _KazAiActionButtonState extends State<_KazAiActionButton> {
  bool _loading = false;

  Future<void> _generate() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final data = ProjectDataHelper.getData(context);
      final ctx = ProjectDataHelper.buildExecutivePlanContext(
        data,
        sectionLabel: 'Staff Team Orchestration',
      );

      final ai = OpenAiServiceSecure();
      final suggestions = await ai.generateStaffingRoleSuggestions(
        context: ctx,
        maxSuggestions: 1,
      );

      if (suggestions.isNotEmpty && mounted) {
        final updated = widget.role.copyWith(
          role: suggestions.first,
          roleDescription: widget.role.roleDescription.isEmpty
              ? 'Auto-suggested by KAZ AI based on project context.'
              : widget.role.roleDescription,
        );
        widget.onUpdated(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('KAZ AI suggested: ${suggestions.first}'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF7C3AED),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('KAZ AI failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'KAZ AI — Auto-suggest role details',
      child: InkWell(
        onTap: _loading ? null : _generate,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: _loading ? const Color(0xFFF3F0FF) : const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFDDD6FE)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loading)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Color(0xFF7C3AED),
                  ),
                )
              else
                const Icon(Icons.auto_awesome_rounded,
                    size: 13, color: Color(0xFF7C3AED)),
              const SizedBox(width: 4),
              Text(
                _loading ? '...' : 'KAZ AI',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Modal Form Field ──────────────────────────────────────────────────────────
/// A styled form field used inside the Add Role modal dialog.
class _ModalField extends StatelessWidget {
  const _ModalField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF6B7280)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4338CA), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
          ),
        ),
      ],
    );
  }
}
