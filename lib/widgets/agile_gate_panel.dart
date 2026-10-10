import 'package:flutter/material.dart';
import 'package:ndu_project/utils/agile_gate_definitions.dart';

const Color _kBorder = Color(0xFFE5E7EB);
const Color _kMuted = Color(0xFF6B7280);
const Color _kHeadline = Color(0xFF111827);
const Color _kAccent = Color(0xFFD97706);
const Color _kAccentBg = Color(0xFFFEF3C7);
const Color _kGovernanceBg = Color(0xFFF3F4F6);

/// The delivery gate, in order: **Definition of Ready → Acceptance Criteria →
/// Definition of Done**.
///
/// The review asked for acceptance criteria to sit above definition of done in
/// the gate, and for ready/done not to be maintained twice. So the two outer
/// gates are rendered here read-only from Backlog Governance (with a way to get
/// there), and the section's own editor is passed in as the middle block.
///
/// Presentational on purpose: it takes definitions and a child, so the ordering
/// the review asked for can be tested without Firestore.
class AgileGatePanel extends StatelessWidget {
  const AgileGatePanel({
    super.key,
    required this.ready,
    required this.done,
    required this.acceptanceCriteria,
    this.acceptanceCriteriaSummary = '',
    this.onOpenGovernance,
  });

  /// Definition of Ready, as Backlog Governance saved it.
  final AgileGateDefinition ready;

  /// Definition of Done, as Backlog Governance saved it.
  final AgileGateDefinition done;

  /// The acceptance criteria editor — the middle gate, owned by this section.
  final Widget acceptanceCriteria;

  final String acceptanceCriteriaSummary;

  /// Opens Backlog Governance, where the outer gates are maintained.
  final VoidCallback? onOpenGovernance;

  @override
  Widget build(BuildContext context) {
    // Driven by AgileGateDefinitions.order so the order cannot drift from the
    // one place that defines it.
    assert(
      AgileGateDefinitions.order == const [
        AgileGateStage.definitionOfReady,
        AgileGateStage.acceptanceCriteria,
        AgileGateStage.definitionOfDone,
      ],
      'The gate order changed — this panel renders ready, criteria, done.',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stageHeader(AgileGateStage.definitionOfReady),
        const SizedBox(height: 8),
        _governedCard(
          definition: ready,
          caption: 'Everything here must hold before the criteria below apply.',
        ),
        const SizedBox(height: 20),
        _stageHeader(AgileGateStage.acceptanceCriteria,
            summary: acceptanceCriteriaSummary),
        const SizedBox(height: 8),
        acceptanceCriteria,
        const SizedBox(height: 20),
        _stageHeader(AgileGateStage.definitionOfDone),
        const SizedBox(height: 8),
        _governedCard(
          definition: done,
          caption:
              'The work is only done once these hold *and* the criteria above are met.',
        ),
      ],
    );
  }

  Widget _stageHeader(AgileGateStage stage, {String summary = ''}) {
    final isMiddle = stage.ownedByAcceptanceCriteria;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isMiddle ? _kAccent : _kGovernanceBg,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${AgileGateDefinitions.order.indexOf(stage) + 1}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isMiddle ? Colors.white : const Color(0xFF374151),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            stage.label,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: _kHeadline),
          ),
        ),
        const SizedBox(width: 8),
        _badge(
          label: isMiddle ? 'THIS PAGE' : 'FROM GOVERNANCE',
          background: isMiddle ? _kAccentBg : _kGovernanceBg,
          foreground: isMiddle ? _kAccent : const Color(0xFF374151),
        ),
        if (summary.isNotEmpty) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(summary,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: _kMuted)),
          ),
        ],
      ],
    );
  }

  Widget _governedCard({
    required AgileGateDefinition definition,
    required String caption,
  }) {
    final lines = definition.displayLines;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(caption, style: const TextStyle(fontSize: 12, color: _kMuted)),
          const SizedBox(height: 10),
          if (definition.usesChecklist && lines.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final line in lines) _checkChip(line, definition),
              ],
            )
          else
            Text(
              lines.isEmpty ? 'Not defined yet.' : lines.first,
              style: const TextStyle(fontSize: 13, color: _kHeadline),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.lock_outline, size: 13, color: _kMuted),
              const SizedBox(width: 6),
              Expanded(
                child:                Text(
                  'Read-only here — ${definition.label} is maintained in '
                  '${AgileGateDefinitions.governanceScreenLabel}, so there is '
                  'only ever one definition.',
                  style: const TextStyle(fontSize: 11, color: _kMuted),
                ),
              ),
              if (onOpenGovernance != null)
                TextButton(
                  key: ValueKey('open-governance-${definition.stage.name}'),
                  onPressed: onOpenGovernance,
                  child: const Text(
                    'Open ${AgileGateDefinitions.governanceScreenLabel}',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _checkChip(String label, AgileGateDefinition definition) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, size: 12, color: Color(0xFF059669)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 11.5, color: _kHeadline)),
        ],
      ),
    );
  }

  Widget _badge({
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: foreground,
              letterSpacing: 0.6)),
    );
  }
}
