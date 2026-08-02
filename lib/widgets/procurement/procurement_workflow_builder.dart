import 'package:flutter/material.dart';
import 'package:ndu_project/models/procurement/procurement_models.dart';
import 'package:ndu_project/models/procurement/procurement_workflow_step.dart';

class ProcurementWorkflowBuilder extends StatelessWidget {
  const ProcurementWorkflowBuilder({
    super.key,
    required this.scopeItems,
    required this.customizeWorkflowByScope,
    required this.selectedScopeId,
    required this.selectedScopeName,
    required this.workflowDisabledForSelection,
    required this.workflowTotalWeeks,
    required this.workflowSteps,
    required this.workflowLoading,
    required this.workflowSaving,
    required this.onCustomizeByScopeChanged,
    required this.onWorkflowScopeSelected,
    required this.onAddWorkflowStep,
    required this.onEditWorkflowStep,
    required this.onDeleteWorkflowStep,
    required this.onMoveWorkflowStep,
    required this.onResetWorkflow,
    required this.onSaveWorkflow,
    required this.onApplyWorkflowToAllScopes,
  });

  final List<ProcurementItemModel> scopeItems;
  final bool customizeWorkflowByScope;
  final String? selectedScopeId;
  final String selectedScopeName;
  final bool workflowDisabledForSelection;
  final int workflowTotalWeeks;
  final List<ProcurementWorkflowStep> workflowSteps;
  final bool workflowLoading;
  final bool workflowSaving;
  final ValueChanged<bool> onCustomizeByScopeChanged;
  final ValueChanged<String> onWorkflowScopeSelected;
  final Future<void> Function() onAddWorkflowStep;
  final Future<void> Function(ProcurementWorkflowStep step) onEditWorkflowStep;
  final ValueChanged<String> onDeleteWorkflowStep;
  final void Function(int index, int direction) onMoveWorkflowStep;
  final VoidCallback onResetWorkflow;
  final VoidCallback onSaveWorkflow;
  final VoidCallback onApplyWorkflowToAllScopes;

  @override
  Widget build(BuildContext context) {
    final hasScopes = scopeItems.isNotEmpty;
    final disableActions = workflowDisabledForSelection || workflowSaving;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('Apply to All Scopes'),
                selected: !customizeWorkflowByScope,
                onSelected: workflowSaving
                    ? null
                    : (_) => onCustomizeByScopeChanged(false),
              ),
              ChoiceChip(
                label: const Text('Customize by Scope'),
                selected: customizeWorkflowByScope,
                onSelected: hasScopes && !workflowSaving
                    ? (_) => onCustomizeByScopeChanged(true)
                    : null,
              ),
              if (customizeWorkflowByScope)
                SizedBox(
                  width: 320,
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedScopeId,
                    decoration: const InputDecoration(
                      labelText: 'Procurement Scope',
                      isDense: true,
                    ),
                    items: scopeItems
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item.id,
                            child: Text(
                              item.name.trim().isEmpty
                                  ? 'Untitled Scope'
                                  : item.name.trim(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: workflowSaving
                        ? null
                        : (value) {
                            if (value == null) return;
                            onWorkflowScopeSelected(value);
                          },
                  ),
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: workflowDisabledForSelection
                      ? const Color(0xFFF3F4F6)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                ),
                child: Text(
                  'Total Cycle: $workflowTotalWeeks week${workflowTotalWeeks == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: workflowDisabledForSelection
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF1F2937),
                  ),
                ),
              ),
              if (workflowLoading || workflowSaving)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (customizeWorkflowByScope && !hasScopes)
            const Text(
              'No procurement scopes found. Add scope rows first.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            )
          else if (workflowDisabledForSelection)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD1D5DB)),
              ),
              child: Text(
                'Bidding is not required for "${selectedScopeName.trim().isEmpty ? 'this scope' : selectedScopeName.trim()}". The procurement workflow is greyed out for this selection.',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF4B5563),
                  height: 1.35,
                ),
              ),
            )
          else if (workflowSteps.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Text(
                'No workflow steps yet. Add your first step to build the procurement cycle.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < workflowSteps.length; i++) ...[
                  _ProcurementWorkflowStepRow(
                    step: workflowSteps[i],
                    index: i,
                    onEdit: () => onEditWorkflowStep(workflowSteps[i]),
                    onDelete: () => onDeleteWorkflowStep(workflowSteps[i].id),
                    onMoveUp: i == 0 ? null : () => onMoveWorkflowStep(i, -1),
                    onMoveDown: i == workflowSteps.length - 1
                        ? null
                        : () => onMoveWorkflowStep(i, 1),
                  ),
                  if (i != workflowSteps.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              TextButton.icon(
                onPressed: disableActions ? null : onAddWorkflowStep,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Step'),
              ),
              OutlinedButton.icon(
                onPressed: disableActions ? null : onResetWorkflow,
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text('Reset Preset'),
              ),
              ElevatedButton.icon(
                onPressed: disableActions ? null : onSaveWorkflow,
                icon: workflowSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 16),
                label: Text(
                  customizeWorkflowByScope
                      ? 'Save Scope Workflow'
                      : 'Save Workflow',
                ),
              ),
              TextButton.icon(
                onPressed: disableActions ? null : onApplyWorkflowToAllScopes,
                icon: const Icon(Icons.publish_rounded, size: 16),
                label: const Text('Apply to All Scopes'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProcurementWorkflowStepRow extends StatelessWidget {
  const _ProcurementWorkflowStepRow({
    required this.step,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final ProcurementWorkflowStep step;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final unitLabel = step.duration == 1 ? step.unit : '${step.unit}s';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.name.trim().isEmpty ? 'Untitled Step' : step.name.trim(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${step.duration} $unitLabel',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            visualDensity: VisualDensity.compact,
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
          IconButton(
            tooltip: 'Delete',
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
          IconButton(
            tooltip: 'Move up',
            visualDensity: VisualDensity.compact,
            onPressed: onMoveUp,
            icon: const Icon(Icons.arrow_upward_rounded, size: 18),
          ),
          IconButton(
            tooltip: 'Move down',
            visualDensity: VisualDensity.compact,
            onPressed: onMoveDown,
            icon: const Icon(Icons.arrow_downward_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
