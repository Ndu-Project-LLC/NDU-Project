library;

/// Review Screen — Treasury-treated email composer, calendar link,
/// double-acceptance gate.
///
/// Design language:
///   "The Treasury" — premium, calm, light-mode executive cockpit built on
///   the NDU brand yellow (#FFC812) + amber (#D97706) gradient.
///
/// Verbatim warning: "Upon finalization, a baseline would be set for the Scope,
/// Cost and Schedule. Scope changes would trigger Management of Change (for
/// waterfall projects)."
///
/// Rendered inside the Cost Estimate module's [ResponsiveScaffold] body —
/// no Scaffold of its own.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';
import 'package:ndu_project/cost_estimate/widgets/treasury_components.dart';
import 'package:ndu_project/services/user_preferences_service.dart';

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
            const ReviewApproval(
              requiredApprovers: [],
              acceptanceStep1: (confirmed: false, by: null, at: null),
              acceptanceStep2: (confirmed: false, by: null, at: null),
            );
        final isApprover = provider.currentRole == RBACRole.approver ||
            provider.currentRole == RBACRole.admin;
        final canReview = isApprover &&
            (estimate.status == EstimateStatus.draft ||
                estimate.status == EstimateStatus.inReview);
        final currencySymbol = UserPreferencesService.currencySymbolSync;

        // Track acceptance progress count
        final acceptanceDone = [
          review.acceptanceStep1.confirmed,
          review.acceptanceStep2.confirmed,
        ].where((d) => d).length;

        // Compute "next step" label for the hero status
        String statusLabel;
        if (isBaselined) {
          statusLabel =
              'Baselined v${estimate.baseline?.version ?? 1}';
        } else if (review.acceptanceStep2.confirmed) {
          statusLabel = 'Accepted — ready to lock';
        } else if (review.acceptanceStep1.confirmed) {
          statusLabel = 'Step 1 done — step 2 pending';
        } else if (review.meetingScheduled != null) {
          statusLabel = 'Meeting scheduled';
        } else if (canReview) {
          statusLabel = 'Ready to schedule review';
        } else {
          statusLabel = 'Awaiting approver';
        }

        return Container(
          color: TreasuryTokens.canvas,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Hero command band ─────────────────────────────────
                TreasuryHeroBand(
                  eyebrow: 'COST ESTIMATE · REVIEW',
                  title: 'Review & Acceptance',
                  subtitle:
                      'Drive the double-acceptance gate. Schedule the review, confirm alignment, and lock the baseline.',
                  statusLabel: statusLabel,
                  statusLive: isBaselined,
                  contextChips: [
                    TreasuryHeroChip(
                      icon: Icons.flag_outlined,
                      label: 'Project',
                      value: estimate.projectName,
                    ),
                    TreasuryHeroChip(
                      icon: Icons.shield_outlined,
                      label: 'Baseline',
                      value:
                          '$currencySymbol${treasuryFmt(estimate.totals.costBaseline)}',
                    ),
                    TreasuryHeroChip(
                      icon: Icons.group_outlined,
                      label: 'Role',
                      value: provider.currentRole.label,
                    ),
                  ],
                  actions: [
                    if (canReview && review.meetingScheduled == null)
                      TreasuryHeroAction(
                        icon: Icons.mail_rounded,
                        label: 'Email & schedule',
                        primary: true,
                        onTap: () =>
                            _showEmailComposer(context, provider, estimate),
                      ),
                    if (canReview &&
                        review.meetingScheduled != null &&
                        !review.acceptanceStep1.confirmed)
                      TreasuryHeroAction(
                        icon: Icons.shield_rounded,
                        label: 'Begin acceptance',
                        primary: true,
                        onTap: () =>
                            _showAcceptanceGate(context, provider, estimate),
                      ),
                  ],
                ),
                const SizedBox(height: 22),

                // ── 2. Premium KPI strip ─────────────────────────────────
                TreasuryKpiStrip(
                  kpis: [
                    TreasuryKpiSpec(
                      label: 'Acceptance Progress',
                      value: '$acceptanceDone / 2',
                      sub: 'Steps confirmed',
                      icon: Icons.task_alt_rounded,
                      tint: const Color(0xFF10B981),
                      tintSoft: const Color(0xFFE7F8F0),
                    ),
                    TreasuryKpiSpec(
                      label: 'Cost Baseline',
                      value:
                          '$currencySymbol${treasuryFmt(estimate.totals.costBaseline)}',
                      sub: 'Locked once accepted',
                      icon: Icons.shield_outlined,
                      tint: const Color(0xFFD97706),
                      tintSoft: const Color(0xFFFFF3E0),
                    ),
                    TreasuryKpiSpec(
                      label: 'Stakeholders',
                      value: '${estimate.stakeholders.length}',
                      sub: 'To be notified',
                      icon: Icons.people_outline_rounded,
                      tint: const Color(0xFFB8860B),
                      tintSoft: const Color(0xFFEEF0FF),
                    ),
                    TreasuryKpiSpec(
                      label: 'Re-baselines',
                      value:
                          '${estimate.baseline?.rebaselineRemaining ?? 2} / 2',
                      sub: 'Available after lock',
                      icon: Icons.refresh_rounded,
                      tint: const Color(0xFFB8860B),
                      tintSoft: const Color(0xFFF4EEFF),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // ── 3. Baselined state banner (if applicable) ───────────
                if (isBaselined) ...[
                  _BaselinedLockedBanner(
                    version: estimate.baseline?.version ?? 1,
                    remaining: estimate.baseline?.rebaselineRemaining ?? 0,
                  ),
                  const SizedBox(height: 16),
                ],

                // ── 4. Schedule prompt (if can review + no meeting) ───
                if (canReview && review.meetingScheduled == null) ...[
                  _SchedulePromptCard(
                    onSchedule: () =>
                        _showEmailComposer(context, provider, estimate),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── 5. Acceptance progress ─────────────────────────────
                if (review.acceptanceStep1.confirmed ||
                    review.acceptanceStep2.confirmed) ...[
                  TreasurySectionCard(
                    title: 'Acceptance Progress',
                    subtitle: 'Double-acceptance gate — 2 steps',
                    child: Column(
                      children: [
                        _AcceptanceStepRow(
                          num: 1,
                          title: 'Alignment confirmed',
                          desc:
                              'Everyone who needs to approve is aligned on scope, schedule, and cost.',
                          done: review.acceptanceStep1.confirmed,
                        ),
                        const SizedBox(height: 10),
                        _AcceptanceStepRow(
                          num: 2,
                          title: 'Baseline acknowledged',
                          desc:
                              'Upon finalization, a baseline would be set for the Scope, Cost and Schedule.',
                          done: review.acceptanceStep2.confirmed,
                          isWarning: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── 6. Begin acceptance CTA ────────────────────────────
                if (canReview &&
                    review.meetingScheduled != null &&
                    !review.acceptanceStep1.confirmed) ...[
                  Center(
                    child: TreasuryPrimaryButton(
                      icon: Icons.shield_rounded,
                      label: 'Begin acceptance',
                      onPressed: () =>
                          _showAcceptanceGate(context, provider, estimate),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── 7. Empty state when nothing else to show ───────────
                if (!isBaselined &&
                    !(canReview && review.meetingScheduled == null) &&
                    !(review.acceptanceStep1.confirmed ||
                        review.acceptanceStep2.confirmed) &&
                    !(canReview &&
                        review.meetingScheduled != null &&
                        !review.acceptanceStep1.confirmed)) ...[
                  TreasuryEmptyState(
                    icon: Icons.fact_check_rounded,
                    title: 'Review & acceptance flow opens here',
                    body: isApprover
                        ? 'Submit the estimate for review to start the double-acceptance gate. Schedule a review meeting to align with stakeholders.'
                        : 'Only approvers and admins can drive the review flow. Switch role on the Stakeholders tab to test.',
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEmailComposer(BuildContext context,
      CostEstimateProvider provider, CostEstimate estimate) {
    final recipients = <String>{
      ...estimate.stakeholders.map((s) => s.email),
      ...estimate.access.map((a) => a.userEmail),
    }.toList();
    final subjectCtrl = TextEditingController(
        text: 'Cost Estimate Review Required — ${estimate.projectName}');
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
      builder: (ctx) => _TreasuryEmailDialog(
        recipients: recipients,
        subjectCtrl: subjectCtrl,
        bodyCtrl: bodyCtrl,
        onSend: () {
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
      ),
    );
  }

  void _showAcceptanceGate(BuildContext context,
      CostEstimateProvider provider, CostEstimate estimate) {
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

// ═══════════════════════════════════════════════════════════════════════════
// BASELINED LOCKED BANNER
// ═══════════════════════════════════════════════════════════════════════════

class _BaselinedLockedBanner extends StatelessWidget {
  const _BaselinedLockedBanner(
      {required this.version, required this.remaining});
  final int version;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_circle_rounded,
                size: 20, color: Color(0xFF10B981)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Baseline locked — v$version',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF047857),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Re-baselines remaining: $remaining. Scope changes will trigger variance entries.',
                  style: TextStyle(
                    fontSize: 12,
                    color: TreasuryTokens.muted,
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

// ═══════════════════════════════════════════════════════════════════════════
// SCHEDULE PROMPT CARD
// ═══════════════════════════════════════════════════════════════════════════

class _SchedulePromptCard extends StatelessWidget {
  const _SchedulePromptCard({required this.onSchedule});
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    return TreasurySectionCard(
      title: 'Schedule Cost Estimate Review',
      subtitle: 'Notify stakeholders and book the alignment meeting',
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: TreasuryTokens.brandSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: TreasuryTokens.brand.withValues(alpha: 0.30),
              ),
            ),
            child: Icon(Icons.calendar_month_rounded,
                size: 20, color: TreasuryTokens.brandDeep),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Compose an email + calendar invite',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: TreasuryTokens.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sends to all stakeholders with view access. The acceptance gate opens after the meeting is scheduled.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: TreasuryTokens.muted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          TreasuryPrimaryButton(
            icon: Icons.mail_rounded,
            label: 'Email & schedule',
            onPressed: onSchedule,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ACCEPTANCE STEP ROW
// ═══════════════════════════════════════════════════════════════════════════

class _AcceptanceStepRow extends StatelessWidget {
  const _AcceptanceStepRow({
    required this.num,
    required this.title,
    required this.desc,
    required this.done,
    this.isWarning = false,
  });
  final int num;
  final String title;
  final String desc;
  final bool done;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final accent = done
        ? const Color(0xFF10B981)
        : isWarning
            ? TreasuryTokens.warning
            : TreasuryTokens.muted;
    final accentSoft = done
        ? const Color(0xFFE7F8F0)
        : isWarning
            ? TreasuryTokens.warningSoft
            : TreasuryTokens.surfaceAlt;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: done ? accent : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: done ? accent : TreasuryTokens.hairline,
                width: 1.5,
              ),
            ),
            child: done
                ? const Icon(Icons.check_rounded,
                    size: 16, color: Colors.white)
                : Center(
                    child: Text('$num',
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        )),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: TreasuryTokens.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: TreasuryTokens.muted,
                    height: 1.45,
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

// ═══════════════════════════════════════════════════════════════════════════
// TREASURY EMAIL DIALOG
// ═══════════════════════════════════════════════════════════════════════════

class _TreasuryEmailDialog extends StatelessWidget {
  const _TreasuryEmailDialog({
    required this.recipients,
    required this.subjectCtrl,
    required this.bodyCtrl,
    required this.onSend,
  });
  final List<String> recipients;
  final TextEditingController subjectCtrl;
  final TextEditingController bodyCtrl;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: TreasuryTokens.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: TreasuryTokens.brandSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.mail_rounded,
                size: 16, color: TreasuryTokens.brandDeep),
          ),
          const SizedBox(width: 10),
          const Text('Schedule cost estimate review',
              style: TextStyle(
                  color: TreasuryTokens.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: TreasuryTokens.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: TreasuryTokens.hairline),
                ),
                child: Row(
                  children: [
                    Text('TO:'.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: TreasuryTokens.muted,
                        )),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(recipients.join(', '),
                          style: TextStyle(
                              color: TreasuryTokens.inkSoft,
                              fontSize: 11.5),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subjectCtrl,
              decoration: InputDecoration(
                labelText: 'Subject',
                labelStyle:
                    TextStyle(color: TreasuryTokens.muted, fontSize: 12),
                filled: true,
                fillColor: TreasuryTokens.surface,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: TreasuryTokens.hairline)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color: TreasuryTokens.brandDeep, width: 1.6)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: TreasuryTokens.hairline)),
              ),
              style: const TextStyle(
                  color: TreasuryTokens.ink, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyCtrl,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: 'Message',
                labelStyle:
                    TextStyle(color: TreasuryTokens.muted, fontSize: 12),
                filled: true,
                fillColor: TreasuryTokens.surface,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: TreasuryTokens.hairline)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color: TreasuryTokens.brandDeep, width: 1.6)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: TreasuryTokens.hairline)),
              ),
              style: const TextStyle(
                  color: TreasuryTokens.ink, fontSize: 12.5),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style:
                  TextStyle(color: TreasuryTokens.muted, fontSize: 13)),
        ),
        TreasuryPrimaryButton(
          icon: Icons.send_rounded,
          label: 'Send & submit for review',
          onPressed: onSend,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ACCEPTANCE GATE DIALOG
// ═══════════════════════════════════════════════════════════════════════════

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
      backgroundColor: TreasuryTokens.surface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: TreasuryTokens.brandSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.shield_rounded,
                size: 16, color: TreasuryTokens.brandDeep),
          ),
          const SizedBox(width: 10),
          const Text('Double Acceptance Gate',
              style: TextStyle(
                  color: TreasuryTokens.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Two confirmations are required to lock the baseline.',
              style:
                  TextStyle(color: TreasuryTokens.inkSoft, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _AcceptanceStep(
              1,
              'Alignment Confirmation',
              'Confirm that everyone that needs to approve the estimate is aligned on the scope, schedule and cost.',
              _step1Confirmed,
              _step2Confirmed,
              () => setState(() => _step1Confirmed = true),
            ),
            const SizedBox(height: 12),
            _AcceptanceStep(
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
              costBaseline: formatCurrency(
                  widget.estimate.totals.costBaseline,
                  widget.estimate.currency),
              changeProcess: widget.estimate.deliveryModel.label,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close',
              style:
                  TextStyle(color: TreasuryTokens.muted, fontSize: 13)),
        ),
      ],
    );
  }
}

class _AcceptanceStep extends StatelessWidget {
  final int num;
  final String title;
  final String desc;
  final bool confirmed;
  final bool canConfirm;
  final VoidCallback onConfirm;
  final bool isWarning;
  final String? costBaseline;
  final String? changeProcess;

  const _AcceptanceStep(
    this.num,
    this.title,
    this.desc,
    this.confirmed,
    this.canConfirm,
    this.onConfirm, {
    this.isWarning = false,
    this.costBaseline,
    this.changeProcess,
  });

  @override
  Widget build(BuildContext context) {
    final accent = confirmed
        ? const Color(0xFF10B981)
        : isWarning
            ? TreasuryTokens.warning
            : TreasuryTokens.muted;
    final accentSoft = confirmed
        ? const Color(0xFFE7F8F0)
        : isWarning
            ? TreasuryTokens.warningSoft
            : TreasuryTokens.surfaceAlt;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: confirmed ? accent : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: confirmed
                          ? accent
                          : TreasuryTokens.hairline),
                ),
                child: confirmed
                    ? const Icon(Icons.check_rounded,
                        size: 16, color: Colors.white)
                    : Center(
                        child: Text('$num',
                            style: TextStyle(
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            )),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        color: TreasuryTokens.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(desc,
              style: TextStyle(
                  color: TreasuryTokens.inkSoft, fontSize: 13, height: 1.45)),
          if (isWarning && costBaseline != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: TreasuryTokens.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: TreasuryTokens.warning
                        .withValues(alpha: 0.30)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 14, color: TreasuryTokens.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cost baseline: $costBaseline · Delivery model: ${changeProcess ?? ""}',
                      style: TextStyle(
                          color: TreasuryTokens.inkSoft, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (!confirmed)
            SizedBox(
              width: double.infinity,
              child: TreasuryPrimaryButton(
                icon: num == 1
                    ? Icons.check_rounded
                    : Icons.lock_rounded,
                label: num == 1
                    ? 'Confirm alignment'
                    : 'Approve & lock baseline',
                dark: num == 2,
                onPressed: canConfirm ? onConfirm : null,
              ),
            )
          else
            Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 14, color: const Color(0xFF10B981)),
                const SizedBox(width: 6),
                Text('Confirmed',
                    style: TextStyle(
                        color: const Color(0xFF047857),
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            ),
        ],
      ),
    );
  }
}
