import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ndu_project/services/contract_service.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/auto_bullet_text_controller.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/rich_text_editing_controller.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/widgets/inline_editable_text.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
/// Custom Contracts Table with inline editing, CRUD actions, and AI capabilities
class ContractsTableWidget extends StatelessWidget {
  const ContractsTableWidget({
    super.key,
    required this.contracts,
    required this.onContractUpdated,
    required this.onContractDeleted,
  });

  final List<ContractModel> contracts;
  final ValueChanged<ContractModel> onContractUpdated;
  final ValueChanged<ContractModel> onContractDeleted;

  @override
  Widget build(BuildContext context) {
    if (contracts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No contracts found.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }

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
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                _TableHeaderCell('Vendor/Party Name', flex: 2),
                _TableHeaderCell('Contract Type', flex: 2),
                _TableHeaderCell('Status', flex: 2),
                _TableHeaderCell('Effective Date', flex: 2),
                _TableHeaderCell('Expiry', flex: 2),
                _TableHeaderCell('Total Value', flex: 2),
                _TableHeaderCell('Actions', flex: 2),
              ],
            ),
          ),
          // Table Rows
          ...contracts.map((contract) => _ContractRowWidget(
                contract: contract,
                onUpdated: onContractUpdated,
                onDeleted: onContractDeleted,
                showDivider: contract != contracts.last,
              )),
        ],
      ),
    );
  }
}

const List<String> _contractTypeOptions = [
  'Service Level Agreement (SLA)',
  'NDA',
  'Procurement',
  'Employment',
];

const List<String> _contractStatusOptions = [
  'Draft',
  'Signed',
  'Active',
  'Expired',
];

List<String> _dropdownOptionsWithCurrent(
  Iterable<String> options,
  String currentValue,
) {
  final seen = <String>{};
  final normalized = <String>[];

  void add(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || !seen.add(trimmed)) return;
    normalized.add(trimmed);
  }

  for (final option in options) {
    add(option);
  }
  add(currentValue);

  return normalized;
}

String? _dropdownValue(List<String> options, String currentValue) {
  if (options.isEmpty) return null;
  final trimmed = currentValue.trim();
  if (trimmed.isEmpty) return null;
  return options.contains(trimmed) ? trimmed : null;
}

class _TableHeaderCell extends StatelessWidget {
  const _TableHeaderCell(this.label, {required this.flex});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _ContractRowWidget extends StatefulWidget {
  const _ContractRowWidget({
    required this.contract,
    required this.onUpdated,
    required this.onDeleted,
    required this.showDivider,
  });

  final ContractModel contract;
  final ValueChanged<ContractModel> onUpdated;
  final ValueChanged<ContractModel> onDeleted;
  final bool showDivider;

  @override
  State<_ContractRowWidget> createState() => _ContractRowWidgetState();
}

class _ContractRowWidgetState extends State<_ContractRowWidget> {
  late ContractModel _contract;
  bool _isHovering = false;
  bool _isRegenerating = false;
  ContractModel? _previousState; // For undo

  String _formatDate(DateTime? date) {
    if (date == null) return 'TBD';
    return DateFormat('MMM d, yyyy').format(date);
  }

  @override
  void initState() {
    super.initState();
    _contract = widget.contract;
  }

  @override
  void didUpdateWidget(_ContractRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contract != widget.contract) {
      _contract = widget.contract;
    }
  }

  Future<void> _updateContract(ContractModel updated) async {
    setState(() {
      _previousState = _contract;
      _contract = updated;
    });

    // Save via ContractService
    try {
      await ContractService.updateContract(
        projectId: updated.projectId,
        contractId: updated.id,
        name: updated.name,
        description: updated.description,
        contractType: updated.contractType,
        paymentType: updated.paymentType,
        status: updated.status,
        estimatedValue: updated.estimatedValue,
        startDate: updated.startDate,
        endDate: updated.endDate,
        scope: updated.scope,
        discipline: updated.discipline,
        notes: updated.notes,
      );

      // Sync to budget if value changed
      if (updated.estimatedValue != _previousState?.estimatedValue) {
        if (_previousState != null && _previousState!.estimatedValue > 0) {
          await ExecutionPhaseService.syncContractValueToBudget(
            projectId: updated.projectId,
            contractValue: _previousState!.estimatedValue,
            contractName: _previousState!.name,
            isDelete: true,
            userId: FirebaseAuth.instance.currentUser?.uid,
          );
        }
        if (updated.estimatedValue > 0) {
          await ExecutionPhaseService.syncContractValueToBudget(
            projectId: updated.projectId,
            contractValue: updated.estimatedValue,
            contractName: updated.name,
            isDelete: false,
            userId: FirebaseAuth.instance.currentUser?.uid,
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating contract: $e');
    }

    widget.onUpdated(updated);
  }

  Future<void> _undo() async {
    if (_previousState != null) {
      final previous = _previousState!;
      setState(() {
        _contract = previous;
        _previousState = null;
      });
      // Save the reverted state
      await _updateContract(previous);
    }
  }

  Future<void> _regenerateKeyTerms() async {
    setState(() => _isRegenerating = true);
    try {
      final provider = ProjectDataInherited.maybeOf(context);
      final data = provider?.projectData;
      if (data == null) return;

      final contextText = ProjectDataHelper.buildExecutivePlanContext(
        data,
        sectionLabel: 'Contracts Tracking',
      );

      final ai = OpenAiServiceSecure();
      final keyTerms = await ai.generateContractKeyTerms(
        context: contextText,
        contractType: _contract.contractType,
      );

      final updated = ContractModel(
        id: _contract.id,
        projectId: _contract.projectId,
        name: _contract.name,
        description: _contract.description,
        contractType: _contract.contractType,
        paymentType: _contract.paymentType,
        status: _contract.status,
        estimatedValue: _contract.estimatedValue,
        startDate: _contract.startDate,
        endDate: _contract.endDate,
        scope: keyTerms, // scope is used for Key Terms
        discipline: _contract.discipline,
        notes: _contract.notes,
        createdById: _contract.createdById,
        createdByEmail: _contract.createdByEmail,
        createdByName: _contract.createdByName,
        createdAt: _contract.createdAt,
        updatedAt: DateTime.now(),
      );

      // Update contract with KAZ AI-generated key terms
      _updateContract(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Key terms regenerated successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error regenerating key terms: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRegenerating = false);
      }
    }
  }

  Future<void> _deleteContract() async {
    final deleted = _contract;

    // Delete via ContractService
    try {
      await ContractService.deleteContract(
        projectId: deleted.projectId,
        contractId: deleted.id,
      );

      // Sync to budget (remove value)
      await ExecutionPhaseService.syncContractValueToBudget(
        projectId: deleted.projectId,
        contractValue: deleted.estimatedValue,
        contractName: deleted.name,
        isDelete: true,
        userId: FirebaseAuth.instance.currentUser?.uid,
      );
    } catch (e) {
      debugPrint('Error deleting contract: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting contract: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    widget.onDeleted(deleted);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Contract deleted'),
              Spacer(),
            ],
          ),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () async {
              // Restore the contract
              try {
                final user = FirebaseAuth.instance.currentUser;
                await ContractService.createContract(
                  projectId: deleted.projectId,
                  name: deleted.name,
                  description: deleted.description,
                  contractType: deleted.contractType,
                  paymentType: deleted.paymentType,
                  status: deleted.status,
                  estimatedValue: deleted.estimatedValue,
                  startDate: deleted.startDate,
                  endDate: deleted.endDate,
                  scope: deleted.scope,
                  discipline: deleted.discipline,
                  notes: deleted.notes,
                  createdById: deleted.createdById,
                  createdByEmail: deleted.createdByEmail,
                  createdByName: deleted.createdByName,
                );
                // Sync to budget
                await ExecutionPhaseService.syncContractValueToBudget(
                  projectId: deleted.projectId,
                  contractValue: deleted.estimatedValue,
                  contractName: deleted.name,
                  isDelete: false,
                  userId: user?.uid,
                );
                widget.onUpdated(deleted);
              } catch (e) {
                debugPrint('Error restoring contract: $e');
              }
            },
          ),
          duration: const Duration(seconds: 5),
          backgroundColor: const Color(0xFF111827),
        ),
      );
    }
  }

  Future<void> _showFullEditDialog() async {
    final nameController = TextEditingController(text: _contract.name);
    final descriptionController =
        TextEditingController(text: _contract.description);
    // Key Terms (scope) - use AutoBulletTextController
    final keyTermsController = AutoBulletTextController(text: _contract.scope);
    // Contract Notes - regular TextEditingController (prose)
    final notesController = RichTextEditingController(text: _contract.notes);
    final disciplineController =
        TextEditingController(text: _contract.discipline);
    final estimatedValueController =
        TextEditingController(text: _contract.estimatedValue.toString());

    var selectedContractType = _contract.contractType;
    var selectedStatus = _contract.status;
    DateTime? selectedStartDate = _contract.startDate;
    DateTime? selectedEndDate = _contract.endDate;

    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final contractTypeOptions = _dropdownOptionsWithCurrent(
            _contractTypeOptions,
            selectedContractType,
          );
          final statusOptions = _dropdownOptionsWithCurrent(
            _contractStatusOptions,
            selectedStatus,
          );

          return AlertDialog(
            title: const Text('Edit Contract', style: TextStyle(fontSize: 18)),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VoiceTextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Vendor/Party Name *',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _dropdownValue(
                          contractTypeOptions, selectedContractType),
                      decoration: const InputDecoration(
                        labelText: 'Contract Type *',
                        isDense: true,
                      ),
                      items: contractTypeOptions
                          .map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(type,
                                    style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setDialogState(() => selectedContractType = v ?? '');
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value:
                          _dropdownValue(statusOptions, selectedStatus),
                      decoration: const InputDecoration(
                        labelText: 'Status *',
                        isDense: true,
                      ),
                      items: statusOptions
                          .map((status) => DropdownMenuItem(
                                value: status,
                                child: Text(status,
                                    style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setDialogState(() => selectedStatus = v ?? 'Draft');
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      title: Text(
                          'Effective Date: ${selectedStartDate != null ? DateFormat('MMM dd, yyyy').format(selectedStartDate!) : 'Not set'}'),
                      trailing: const Icon(Icons.calendar_today, size: 18),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedStartDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          setDialogState(() => selectedStartDate = date);
                        }
                      },
                    ),
                    ListTile(
                      title: Text(
                          'Expiry Date: ${selectedEndDate != null ? DateFormat('MMM dd, yyyy').format(selectedEndDate!) : 'Not set'}'),
                      trailing: const Icon(Icons.calendar_today, size: 18),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedEndDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          setDialogState(() => selectedEndDate = date);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    VoiceTextField(
                      controller: estimatedValueController,
                      decoration: const InputDecoration(
                        labelText: 'Total Value *',
                        hintText: 'e.g., 1000000',
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    VoiceTextField(
                      controller: keyTermsController,
                      decoration: const InputDecoration(
                        labelText: 'Key Terms',
                        hintText: 'Use "." bullet format',
                        isDense: true,
                      ),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(height: 6),
                    VoiceTextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Contract Notes',
                        hintText: 'Prose description, no bullets',
                        isDense: true,
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final estimatedValue =
                      double.tryParse(estimatedValueController.text) ?? 0.0;
                  final updated = ContractModel(
                    id: _contract.id,
                    projectId: _contract.projectId,
                    name: nameController.text.trim(),
                    description: descriptionController.text.trim(),
                    contractType: selectedContractType,
                    paymentType: _contract.paymentType,
                    status: selectedStatus,
                    estimatedValue: estimatedValue,
                    startDate: selectedStartDate ?? _contract.startDate,
                    endDate: selectedEndDate ?? _contract.endDate,
                    scope: keyTermsController.text.trim(),
                    discipline: disciplineController.text.trim(),
                    notes: notesController.text.trim(),
                    createdById: _contract.createdById,
                    createdByEmail: _contract.createdByEmail,
                    createdByName: _contract.createdByName,
                    createdAt: _contract.createdAt,
                    updatedAt: DateTime.now(),
                  );

                  // Save via ContractService
                  await ContractService.updateContract(
                    projectId: _contract.projectId,
                    contractId: _contract.id,
                    name: updated.name,
                    description: updated.description,
                    contractType: updated.contractType,
                    paymentType: updated.paymentType,
                    status: updated.status,
                    estimatedValue: updated.estimatedValue,
                    startDate: updated.startDate,
                    endDate: updated.endDate,
                    scope: updated.scope,
                    discipline: updated.discipline,
                    notes: updated.notes,
                  );

                  // Sync to budget if value changed
                  if (updated.estimatedValue != _contract.estimatedValue) {
                    // Remove old value, add new value
                    await ExecutionPhaseService.syncContractValueToBudget(
                      projectId: _contract.projectId,
                      contractValue: _contract.estimatedValue,
                      contractName: _contract.name,
                      isDelete: true,
                      userId: FirebaseAuth.instance.currentUser?.uid,
                    );
                    await ExecutionPhaseService.syncContractValueToBudget(
                      projectId: _contract.projectId,
                      contractValue: updated.estimatedValue,
                      contractName: updated.name,
                      isDelete: false,
                      userId: FirebaseAuth.instance.currentUser?.uid,
                    );
                  }

                  _updateContract(updated);
                  if (context.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    return switch (status.toLowerCase()) {
      'active' => const Color(0xFF10B981),
      'draft' => const Color(0xFFF59E0B),
      'expired' => const Color(0xFFEF4444),
      'signed' => const Color(0xFF2563EB),
      _ => const Color(0xFF9CA3AF),
    };
  }

  @override
  Widget build(BuildContext context) {
    final contractTypeOptions = _dropdownOptionsWithCurrent(
      _contractTypeOptions,
      _contract.contractType,
    );

    return MouseRegion(
      onEnter: (_) {
        if (!_isHovering) setState(() => _isHovering = true);
      },
      onExit: (_) {
        if (_isHovering) setState(() => _isHovering = false);
      },
      child: Container(
        color: _isHovering ? const Color(0xFFF9FAFB) : Colors.white,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: InlineEditableText(
                      value: _contract.name,
                      hint: 'Vendor/Party Name',
                      onChanged: (v) {
                        final updated = ContractModel(
                          id: _contract.id,
                          projectId: _contract.projectId,
                          name: v,
                          description: _contract.description,
                          contractType: _contract.contractType,
                          paymentType: _contract.paymentType,
                          status: _contract.status,
                          estimatedValue: _contract.estimatedValue,
                          startDate: _contract.startDate,
                          endDate: _contract.endDate,
                          scope: _contract.scope,
                          discipline: _contract.discipline,
                          notes: _contract.notes,
                          createdById: _contract.createdById,
                          createdByEmail: _contract.createdByEmail,
                          createdByName: _contract.createdByName,
                          createdAt: _contract.createdAt,
                          updatedAt: DateTime.now(),
                        );
                        // Save in background - don't await to keep UI responsive
                        _updateContract(updated);
                      },
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF111827)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: DropdownButton<String>(
                        value: _dropdownValue(
                          contractTypeOptions,
                          _contract.contractType,
                        ),
                        isExpanded: true,
                        hint: const Text(
                          'Select type',
                          style: TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                        isDense: true,
                        underline: const SizedBox(),
                        items: contractTypeOptions
                            .map((type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            final updated = ContractModel(
                              id: _contract.id,
                              projectId: _contract.projectId,
                              name: _contract.name,
                              description: _contract.description,
                              contractType: v,
                              paymentType: _contract.paymentType,
                              status: _contract.status,
                              estimatedValue: _contract.estimatedValue,
                              startDate: _contract.startDate,
                              endDate: _contract.endDate,
                              scope: _contract.scope,
                              discipline: _contract.discipline,
                              notes: _contract.notes,
                              createdById: _contract.createdById,
                              createdByEmail: _contract.createdByEmail,
                              createdByName: _contract.createdByName,
                              createdAt: _contract.createdAt,
                              updatedAt: DateTime.now(),
                            );
                            // Save in background
                            _updateContract(updated);
                          }
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(_contract.status)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _contract.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(_contract.status),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        _formatDate(_contract.startDate),
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF111827)),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        _formatDate(_contract.endDate),
                        style: TextStyle(
                          fontSize: 11,
                          color: _contract.endDate != null &&
                                  _contract.endDate!.isBefore(DateTime.now())
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF111827),
                          fontWeight: _contract.endDate != null &&
                                  _contract.endDate!.isBefore(DateTime.now())
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        _contract.estimatedValue >= 1000000
                            ? '\$${(_contract.estimatedValue / 1000000).toStringAsFixed(1)}M'
                            : '\$${(_contract.estimatedValue / 1000).toStringAsFixed(0)}K',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // KAZ AI button — always visible
                          Tooltip(
                            message: 'KAZ AI — Regenerate Key Terms',
                            child: InkWell(
                              onTap: _isRegenerating ? null : _regenerateKeyTerms,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F3FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFDDD6FE)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isRegenerating)
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
                                      _isRegenerating ? '...' : 'KAZ AI',
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
                          ),
                          if (_isHovering) ...[
                            const SizedBox(width: 4),
                            if (_previousState != null)
                              IconButton(
                                icon: const Icon(Icons.undo,
                                    size: 16, color: Color(0xFF64748B)),
                                onPressed: _undo,
                                tooltip: 'Undo',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 32, minHeight: 32),
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  size: 16, color: Color(0xFF64748B)),
                              onPressed: _showFullEditDialog,
                              tooltip: 'Edit',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 16, color: Color(0xFF9CA3AF)),
                              onPressed: _deleteContract,
                              tooltip: 'Delete',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
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
              const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          ],
        ),
      ),
    );
  }
}
