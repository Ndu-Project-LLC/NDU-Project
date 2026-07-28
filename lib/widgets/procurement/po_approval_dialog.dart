import 'package:flutter/material.dart';
import 'package:ndu_project/models/procurement/procurement_models.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
/// Dialog for approving or rejecting a Purchase Order
class PoApprovalDialog extends StatefulWidget {
  const PoApprovalDialog({
    super.key,
    required this.po,
    required this.projectOwnerId,
    required this.projectOwnerName,
  });

  final PurchaseOrderModel po;
  final String projectOwnerId;
  final String projectOwnerName;

  @override
  State<PoApprovalDialog> createState() => _PoApprovalDialogState();
}

class _PoApprovalDialogState extends State<PoApprovalDialog> {
  final _commentsController = TextEditingController();
  String _selectedAction = 'approve'; // 'approve' or 'reject'
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    final result = PoApprovalResult(
      action: _selectedAction,
      comments: _commentsController.text.trim(),
      escalateTo: widget.po.approverId,
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final po = widget.po;

    return AlertDialog(
      title: Text('${_selectedAction == 'approve' ? 'Approve' : 'Reject'} PO #${po.poNumber}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInfoRow('Vendor', po.vendorName),
            const SizedBox(height: 8),
            _buildInfoRow('Amount', '\$${po.amount.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildInfoRow('Category', po.category),
            const SizedBox(height: 8),
            _buildInfoRow('Current Approver', po.approverName ?? 'Not assigned'),
            if (po.daysUntilEscalation != null) ...[
              const SizedBox(height: 8),
              _buildEscalationWarning(po.daysUntilEscalation!),
            ],
            const SizedBox(height: 16),
            const Text('Action'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'approve',
                  label: Text('Approve'),
                  icon: Icon(Icons.check_circle, size: 16),
                ),
                ButtonSegment(
                  value: 'reject',
                  label: Text('Reject'),
                  icon: Icon(Icons.cancel, size: 16),
                ),
              ],
              selected: {_selectedAction},
              onSelectionChanged: (Set<String> selected) {
                setState(() => _selectedAction = selected.first);
              },
            ),
            const SizedBox(height: 16),
            VoiceTextField(
              controller: _commentsController,
              decoration: InputDecoration(
                labelText: _selectedAction == 'reject'
                    ? 'Rejection reason *'
                    : 'Comments (optional)',
                hintText: _selectedAction == 'reject'
                    ? 'Explain why this PO is being rejected'
                    : 'Add any notes for the record',
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
              textInputAction: TextInputAction.newline,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_isSubmitting ||
                  (_selectedAction == 'reject' && _commentsController.text.trim().isEmpty))
              ? null
              : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_selectedAction == 'approve' ? 'Approve' : 'Reject'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  Widget _buildEscalationWarning(int daysUntil) {
    final isUrgent = daysUntil == 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUrgent ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUrgent ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: isUrgent ? const Color(0xFFDC2626) : const Color(0xFFD97706),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isUrgent
                  ? 'This approval is overdue and should be escalated to ${widget.projectOwnerName}'
                  : 'Approval deadline in $daysUntil day${daysUntil == 1 ? '' : 's'}',
              style: TextStyle(
                color: isUrgent ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Result of PO approval dialog
class PoApprovalResult {
  final String action; // 'approve' or 'reject'
  final String comments;
  final String? escalateTo;

  const PoApprovalResult({
    required this.action,
    required this.comments,
    this.escalateTo,
  });

  bool get isApprove => action == 'approve';
  bool get isReject => action == 'reject';
}

/// Show PO approval dialog
Future<PoApprovalResult?> showPoApprovalDialog(
  BuildContext context, {
  required PurchaseOrderModel po,
  required String projectOwnerId,
  required String projectOwnerName,
}) {
  return showDialog<PoApprovalResult>(
    context: context,
    builder: (context) => PoApprovalDialog(
      po: po,
      projectOwnerId: projectOwnerId,
      projectOwnerName: projectOwnerName,
    ),
  );
}

/// Simple dialog for escalating a PO
class PoEscalationDialog extends StatefulWidget {
  const PoEscalationDialog({
    super.key,
    required this.po,
    required this.availableEscalationTargets,
  });

  final PurchaseOrderModel po;
  final List<EscalationTarget> availableEscalationTargets;

  @override
  State<PoEscalationDialog> createState() => _PoEscalationDialogState();
}

class _PoEscalationDialogState extends State<PoEscalationDialog> {
  String? _selectedTargetId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Escalate PO Approval'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('PO #${widget.po.poNumber} from ${widget.po.vendorName}'),
          const SizedBox(height: 16),
          const Text('Escalate to:'),
          const SizedBox(height: 8),
          ...widget.availableEscalationTargets.map(
            (target) => _EscalationTargetTile(
              target: target,
              selected: _selectedTargetId == target.id,
              onTap: () => setState(() => _selectedTargetId = target.id),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedTargetId == null
              ? null
              : () => Navigator.pop(context, _selectedTargetId),
          child: const Text('Escalate'),
        ),
      ],
    );
  }
}

class _EscalationTargetTile extends StatelessWidget {
  const _EscalationTargetTile({
    required this.target,
    required this.selected,
    required this.onTap,
  });

  final EscalationTarget target;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFF7E6) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  selected ? const Color(0xFFFDE68A) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color:
                    selected ? const Color(0xFFD97706) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      target.role,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Escalation target for PO approval
class EscalationTarget {
  final String id;
  final String name;
  final String role;

  const EscalationTarget({
    required this.id,
    required this.name,
    required this.role,
  });
}
