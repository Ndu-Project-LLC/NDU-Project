library;

/// Review Screen — email composer, calendar link, double-acceptance gate.
///
/// Verbatim warning: "Upon finalization, a baseline would be set for the Scope,
/// Cost and Schedule. Scope changes would trigger Management of Change (for
/// waterfall projects)."
///
/// Rendered inside the Cost Estimate module's [ResponsiveScaffold] body —
/// no Scaffold of its own. Light-mode (white) theme.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CostEstimateProvider>(
      builder: (context, provider, _) {
        final estimate = provider.estimate!;
        final isBaselined = estimate.status == EstimateStatus.baselined ||
            estimate.status == EstimateStatus.rebaselined;
        final review = estimate.review ??
            ReviewApproval(
              requiredApprovers: [],
              acceptanceStep1: (confirmed: false, by: null, at: null),
              acceptanceStep2: (confirmed: false, by: null, at: null),
            );
        final isApprover = provider.currentRole == RBACRole.approver ||
            provider.currentRole == RBACRole.admin;
        final canReview = isApprover &&
            (estimate.status == EstimateStatus.draft ||
                estimate.status == EstimateStatus.inReview);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.fact_check, color: LightModeColors.accent, size: 20),
                  SizedBox(width: 8),
                  Text('Review & Acceptance',
                      style: TextStyle(
                          color: Color(0xFF1A1D1F),
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              // Baselined state
              if (isBaselined)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF16A34A)
                            .withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Color(0xFF16A34A), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Baseline locked — v${estimate.baseline?.version}',
                              style: const TextStyle(
                                  color: Color(0xFF16A34A),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Re-baselines remaining: ${estimate.baseline?.rebaselineRemaining}',
                              style: const TextStyle(
                                  color: Color(0xFF495057), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              // Schedule prompt
              if (canReview && review.meetingScheduled == null)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: LightModeColors.accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: LightModeColors.accent
                            .withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month,
                          color: LightModeColors.accent, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Schedule cost estimate review',
                          style: TextStyle(
                              color: Color(0xFFD97706),
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _showEmailComposer(context, provider, estimate),
                        icon: const Icon(Icons.mail, size: 14),
                        label: const Text('Email & schedule'),
                        style: FilledButton.styleFrom(
                          backgroundColor: LightModeColors.accent,
                          foregroundColor: LightModeColors.lightOnPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              // Acceptance progress
              if (review.acceptanceStep1.confirmed ||
                  review.acceptanceStep2.confirmed) ...[
                _buildAcceptanceStep(
                  1,
                  'Alignment confirmed',
                  'Everyone who needs to approve is aligned on scope, schedule, and cost.',
                  review.acceptanceStep1.confirmed,
                ),
                const SizedBox(height: 8),
                _buildAcceptanceStep(
                  2,
                  'Baseline acknowledged',
                  'Upon finalization, a baseline would be set for the Scope, Cost and Schedule.',
                  review.acceptanceStep2.confirmed,
                ),
                const SizedBox(height: 24),
              ],
              // Begin acceptance button
              if (canReview &&
                  review.meetingScheduled != null &&
                  !review.acceptanceStep1.confirmed)
                Center(
                  child: FilledButton.icon(
                    onPressed: () => _showAcceptanceGate(context, provider, estimate),
                    icon: const Icon(Icons.shield, size: 16),
                    label: const Text('Begin acceptance'),
                    style: FilledButton.styleFrom(
                      backgroundColor: LightModeColors.accent,
                      foregroundColor: LightModeColors.lightOnPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                    ),
                  ),
                ),
              // Empty state when nothing to show yet
              if (!isBaselined &&
                  !(canReview && review.meetingScheduled == null) &&
                  !(review.acceptanceStep1.confirmed ||
                      review.acceptanceStep2.confirmed) &&
                  !(canReview &&
                      review.meetingScheduled != null &&
                      !review.acceptanceStep1.confirmed))
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE4E7EC)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.fact_check,
                            color: Color(0xFF9CA3AF), size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'Review & acceptance flow opens here',
                          style: TextStyle(
                              color: Color(0xFF1A1D1F),
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isApprover
                              ? 'Submit the estimate for review to start the double-acceptance gate.'
                              : 'Only approvers and admins can drive the review flow. Switch role on the Stakeholders tab to test.',
                          style: const TextStyle(
                              color: Color(0xFF6B7280), fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAcceptanceStep(
      int num, String title, String desc, bool done) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: done
            ? const Color(0xFF16A34A).withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: done
              ? const Color(0xFF16A34A).withValues(alpha: 0.3)
              : const Color(0xFFE4E7EC),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: done ? const Color(0xFF16A34A) : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: done
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFE4E7EC),
              ),
            ),
            child: done
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Center(
                    child: Text('$num',
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 11)),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Color(0xFF1A1D1F),
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(desc,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEmailComposer(
      BuildContext context, CostEstimateProvider provider, CostEstimate estimate) {
    final recipients = <String>{
      ...estimate.stakeholders.map((s) => s.email),
      ...estimate.access.map((a) => a.userEmail),
    }.toList();
    final subjectCtrl =
        TextEditingController(text: 'Cost Estimate Review Required — ${estimate.projectName}');
    final bodyCtrl = TextEditingController(text: '''Hello,

A cost estimate for ${estimate.projectName} is ready for review.

Estimate details:
  - Class: ${estimate.className.label}
  - Delivery model: ${estimate.deliveryModel.label}
  - Cost baseline: ${formatCurrency(estimate.totals.costBaseline, estimate.currency)}
  - Total authorized budget: ${formatCurrency(estimate.totals.totalAuthorizedBudget, estimate.currency)}

Please review the estimate and confirm your alignment on scope, schedule, and cost.

Upon finalization, a baseline will be set for the Scope, Cost and Schedule. Scope changes will trigger Management of Change (for waterfall projects).

Schedule the cost estimate review meeting to discuss.

Thank you,''');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.mail, color: LightModeColors.accent, size: 18),
            SizedBox(width: 8),
            Text('Schedule cost estimate review',
                style: TextStyle(color: Color(0xFF1A1D1F), fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text('To: ${recipients.join(", ")}',
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 11)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: subjectCtrl,
                decoration: const InputDecoration(
                    labelText: 'Subject',
                    labelStyle: TextStyle(color: Color(0xFF6B7280))),
                style: const TextStyle(color: Color(0xFF1A1D1F)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bodyCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                    labelText: 'Message',
                    labelStyle: TextStyle(color: Color(0xFF6B7280))),
                style: const TextStyle(
                    color: Color(0xFF1A1D1F), fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          FilledButton(
            onPressed: () {
              provider.updateReview(ReviewApproval(
                requiredApprovers: [],
                meetingScheduled: ReviewMeeting(
                  date: DateTime.now().add(const Duration(days: 7)),
                  title: 'Cost Estimate Review — ${estimate.projectName}',
                  calendarLink: '',
                  attendees: recipients,
                ),
                emailDraft: EmailDraft(
                  to: recipients,
                  subject: subjectCtrl.text,
                  body: bodyCtrl.text,
                  sentAt: DateTime.now(),
                ),
                acceptanceStep1: (confirmed: false, by: null, at: null),
                acceptanceStep2: (confirmed: false, by: null, at: null),
              ));
              provider.submitForReview();
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
                backgroundColor: LightModeColors.accent,
                foregroundColor: LightModeColors.lightOnPrimary),
            child: const Text('Send & submit for review'),
          ),
        ],
      ),
    );
  }

  void _showAcceptanceGate(
      BuildContext context, CostEstimateProvider provider, CostEstimate estimate) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AcceptanceGateDialog(
        provider: provider,
        estimate: estimate,
      ),
    );
  }
}

class _AcceptanceGateDialog extends StatefulWidget {
  final CostEstimateProvider provider;
  final CostEstimate estimate;

  const _AcceptanceGateDialog({
    required this.provider,
    required this.estimate,
  });

  @override
  State<_AcceptanceGateDialog> createState() => _AcceptanceGateDialogState();
}

class _AcceptanceGateDialogState extends State<_AcceptanceGateDialog> {
  bool _step1Confirmed = false;
  bool _step2Confirmed = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Row(
        children: [
          Icon(Icons.shield, color: LightModeColors.accent, size: 18),
          SizedBox(width: 8),
          Text('Double Acceptance Gate',
              style: TextStyle(color: Color(0xFF1A1D1F), fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Two confirmations are required to lock the baseline.',
              style: TextStyle(color: Color(0xFF495057), fontSize: 13),
            ),
            const SizedBox(height: 16),
            // Step 1
            _buildStep(
              1,
              'Alignment Confirmation',
              'Confirm that everyone that needs to approve the estimate is aligned on the scope, schedule and cost.',
              _step1Confirmed,
              _step2Confirmed,
              () => setState(() => _step1Confirmed = true),
            ),
            const SizedBox(height: 12),
            // Step 2
            _buildStep(
              2,
              'Baseline Acknowledgment',
              'Upon finalization, a baseline would be set for the Scope, Cost and Schedule. Scope changes would trigger Management of Change (for waterfall projects).',
              _step2Confirmed,
              _step1Confirmed,
              () {
                setState(() => _step2Confirmed = true);
                widget.provider.setAcceptanceStep1(true);
                widget.provider.setAcceptanceStep2(true);
                widget.provider.lockBaseline();
                Navigator.of(context).pop();
              },
              isWarning: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close',
              style: TextStyle(color: Color(0xFF6B7280))),
        ),
      ],
    );
  }

  Widget _buildStep(
    int num,
    String title,
    String desc,
    bool confirmed,
    bool canConfirm,
    VoidCallback onConfirm, {
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: confirmed
            ? const Color(0xFF16A34A).withValues(alpha: 0.08)
            : isWarning
                ? LightModeColors.accent.withValues(alpha: 0.05)
                : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: confirmed
              ? const Color(0xFF16A34A).withValues(alpha: 0.4)
              : isWarning
                  ? LightModeColors.accent.withValues(alpha: 0.4)
                  : const Color(0xFFE4E7EC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: confirmed
                      ? const Color(0xFF16A34A)
                      : isWarning
                          ? LightModeColors.accent
                          : const Color(0xFFE5E7EB),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: confirmed
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text('$num',
                          style: TextStyle(
                            color: isWarning
                                ? LightModeColors.lightOnPrimary
                                : const Color(0xFF6B7280),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          )),
                ),
              ),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: Color(0xFF1A1D1F),
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(desc,
              style: const TextStyle(color: Color(0xFF495057), fontSize: 13)),
          if (isWarning) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: LightModeColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber,
                      color: LightModeColors.accent, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Cost baseline: ${formatCurrency(widget.estimate.totals.costBaseline, widget.estimate.currency)} · Change process: ${widget.estimate.deliveryModel.changeProcess}',
                      style: const TextStyle(
                          color: Color(0xFF495057), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (!confirmed)
            FilledButton(
              onPressed: canConfirm ? onConfirm : null,
              style: FilledButton.styleFrom(
                backgroundColor: LightModeColors.accent,
                foregroundColor: LightModeColors.lightOnPrimary,
                minimumSize: const Size.fromHeight(36),
              ),
              child: Text(num == 1
                  ? 'Confirm alignment'
                  : 'Approve & lock baseline'),
            )
          else
            const Row(
              children: [
                Icon(Icons.check_circle,
                    color: Color(0xFF16A34A), size: 14),
                SizedBox(width: 4),
                Text('Confirmed',
                    style:
                        TextStyle(color: Color(0xFF16A34A), fontSize: 12)),
              ],
            ),
        ],
      ),
    );
  }
}
