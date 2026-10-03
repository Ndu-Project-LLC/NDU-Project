import 'package:flutter/material.dart';

/// How the risk register lays out its rows.
enum RiskRegisterView { table, cards }

/// The Cards/Table switch for the risk register, matching the segmented
/// control the app's other registers use so the screens read as one system.
///
/// Segmented rather than two separate buttons because only one view is ever
/// active; the white pill on the grey track makes the current view obvious
/// without leaning on colour that would fight the page's accent.
class RiskRegisterViewToggle extends StatelessWidget {
  const RiskRegisterViewToggle({
    super.key,
    required this.view,
    required this.onChanged,
  });

  final RiskRegisterView view;
  final ValueChanged<RiskRegisterView> onChanged;

  static const Color _track = Color(0xFFF3F4F6);
  static const Color _inactive = Color(0xFF6B7280);
  static const Color _active = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _track,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(
            label: 'Cards',
            icon: Icons.view_agenda_outlined,
            selected: view == RiskRegisterView.cards,
            onTap: () => onChanged(RiskRegisterView.cards),
          ),
          _segment(
            label: 'Table',
            icon: Icons.table_chart_outlined,
            selected: view == RiskRegisterView.table,
            onTap: () => onChanged(RiskRegisterView.table),
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label view',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? _active : _inactive),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? _active : _inactive,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One risk, as the fields a card shows.
///
/// The table renders the same data from its own [RiskEntryTableRow], but a card
/// can lead with the description and keep the score, owner and status as
/// labelled chips — detail the table has to truncate into narrow columns or
/// push behind a horizontal scroll.
@immutable
class RiskCardModel {
  const RiskCardModel({
    required this.id,
    required this.description,
    required this.category,
    required this.probability,
    required this.impact,
    required this.score,
    required this.discipline,
    required this.role,
    required this.owner,
    required this.status,
  });

  final String id;
  final String description;
  final String category;
  final String probability;
  final String impact;
  final String score;
  final String discipline;
  final String role;
  final String owner;
  final String status;
}

/// The risk register's rows as a responsive card grid.
class RiskCardGrid extends StatelessWidget {
  const RiskCardGrid({
    super.key,
    required this.risks,
    required this.onView,
    required this.onEdit,
  });

  final List<RiskCardModel> risks;
  final ValueChanged<RiskCardModel> onView;
  final ValueChanged<RiskCardModel> onEdit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // One column on a phone, two on a tablet, three on a desktop, sized so
        // a card never gets narrower than its description can be read in.
        final columns = constraints.maxWidth >= 1000
            ? 3
            : (constraints.maxWidth >= 640 ? 2 : 1);
        const spacing = 16.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final risk in risks)
              SizedBox(
                width: cardWidth,
                child: _RiskCard(risk: risk, onView: onView, onEdit: onEdit),
              ),
          ],
        );
      },
    );
  }
}

class _RiskCard extends StatelessWidget {
  const _RiskCard({
    required this.risk,
    required this.onView,
    required this.onEdit,
  });

  final RiskCardModel risk;
  final ValueChanged<RiskCardModel> onView;
  final ValueChanged<RiskCardModel> onEdit;

  @override
  Widget build(BuildContext context) {
    final status = statusColors(risk.status);
    final score = risk.score.trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => onView(risk),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _headerRow(status),
                const SizedBox(height: 8),
                _description(),
                const SizedBox(height: 12),
                _probabilityImpactRow(),
                const SizedBox(height: 10),
                _scoreRow(score),
                if (_hasMeta) ...[
                  const SizedBox(height: 10),
                  const Divider(
                      height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
                  const SizedBox(height: 10),
                  _metaRow(),
                ],
                const SizedBox(height: 8),
                _actionsRow(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasMeta =>
      risk.discipline.trim().isNotEmpty ||
      risk.role.trim().isNotEmpty ||
      risk.owner.trim().isNotEmpty;

  /// Category on the leading edge, status pill on the trailing edge.
  Widget _headerRow(({Color background, Color foreground}) status) {
    final category = risk.category.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            category.isEmpty ? 'Uncategorised' : category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _StatusPill(label: risk.status, colors: status),
      ],
    );
  }

  /// The description leads, because it is what identifies the risk.
  Widget _description() {
    final description = risk.description.trim();
    return Text(
      description.isEmpty ? 'No description' : description,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: Color(0xFF111827),
      ),
    );
  }/// Probability and Impact, the two inputs the score is derived from.
  ///
  /// A [Wrap] rather than a [Row]: on a one-column card the labels and pills
  /// can exceed the width, and wrapping keeps every tag readable instead of
  /// overflowing.
  Widget _probabilityImpactRow() {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _labelledLevel('Probability', risk.probability),
        _labelledLevel('Impact', risk.impact),
      ],
    );
  }

  Widget _labelledLevel(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        const SizedBox(width: 6),
        RiskLevelTag(label: value),
      ],
    );
  }

  /// The overall scale, so it reads as the summary of the two tags above it.
  Widget _scoreRow(String score) {
    return Row(
      children: [
        const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF9CA3AF)),
        const SizedBox(width: 6),
        const Text('Risk Score',
            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        const SizedBox(width: 6),
        Text(
          score.isEmpty ? '—' : score,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  /// Only the secondary fields the risk actually carries, so a sparse risk
  /// does not show three empty labels.
  Widget _metaRow() {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        if (risk.discipline.trim().isNotEmpty)
          _MetaPair(label: 'Discipline', value: risk.discipline),
        if (risk.role.trim().isNotEmpty)
          _MetaPair(label: 'Role', value: risk.role),
        if (risk.owner.trim().isNotEmpty)
          _MetaPair(label: 'Owner', value: risk.owner),
      ],
    );
  }

  /// Trailing actions, mirroring the table's actions column. The whole card is
  /// already tappable to view, so Edit is the only explicit button needed.
  Widget _actionsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton.icon(
          onPressed: () => onView(risk),
          icon: const Icon(Icons.visibility_outlined, size: 16),
          label: const Text('View'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF6B7280),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
        ),
        const SizedBox(width: 4),
        TextButton.icon(
          onPressed: () => onEdit(risk),
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Edit'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF111827),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
        ),
      ],
    );
  }
}

/// The status pill's colours, shared with the register table so a risk looks
/// the same in both views.
({Color background, Color foreground}) statusColors(String status) {
  switch (status) {
    case 'In Progress':
      return (
        background: const Color(0xFFFFF7E6),
        foreground: const Color(0xFF92400E),
      );
    case 'Monitoring':
      return (
        background: const Color(0xFFE0F2F1),
        foreground: const Color(0xFF065F46),
      );
    default:
      return (
        background: const Color(0xFFE5E7EB),
        foreground: const Color(0xFF374151),
      );
  }
}

/// A "Label value" pair for the card's secondary metadata.
class _MetaPair extends StatelessWidget {
  const _MetaPair({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ',
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.colors});

  final String label;
  final ({Color background, Color foreground}) colors;

  @override
  Widget build(BuildContext context) {
    final text = label.trim().isEmpty ? 'Unknown' : label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: colors.foreground),
      ),
    );
  }
}

/// A Low/Medium/High pill.
///
/// Moved here from the register table so the card and the table cannot drift
/// apart: the same High is the same red in both.
class RiskLevelTag extends StatelessWidget {
  const RiskLevelTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final level = label.trim().toLowerCase();
    final Color background;
    final Color textColor;

    if (level == 'high') {
      background = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFB91C1C);
    } else if (level == 'medium') {
      background = const Color(0xFFFEF3C7);
      textColor = const Color(0xFF92400E);
    } else {
      background = const Color(0xFFDCFCE7);
      textColor = const Color(0xFF166534);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500, color: textColor),
      ),
    );
  }
}
