/// WBS Packages card for the Schedule module.
///
/// The product owner reviewing the Schedule (voice note, 2026-09-10) pointed at
/// a card and said, twice:
///
/// > "this card is supposed to show the WBS packages"
///
/// and then, on the same walkthrough:
///
/// > "the schedule should be able to put out everything that's like on the WBS
/// > [so it] should be able to find itself on the schedule … while it's on the
/// > schedule, it should be an option to attach the timelines of what the WBS
/// > item is from the start and when it's supposed to finish in order to attach
/// > any cost related item within the schedule, which then will be able to show
/// > up on the schedule, and on the cost estimate overview, as well as on the
/// > WBS cost estimates."
///
/// So this card is the Schedule's WBS work-package ledger:
///
/// - **It shows the packages.** Every node the WBS decomposes, in tree order,
///   with its code and name — not a count of them.
/// - **It says where each one is.** `On schedule` / `Not scheduled` per row,
///   with the planned window from the WBS and the window the linked schedule
///   activities roll up to.
/// - **It carries the timelines both ways.** "Add N to schedule" brings the
///   missing packages across (keeping `wbsNodeId` + the package's planned
///   dates); "Fill schedule dates from WBS" splits a package's planned window
///   between its un-dated schedule rows; "Attach schedule dates to WBS" is the
///   reverse, and is the action the builder also offers.
/// - **It reads their cost, never writes it.** A package that is already costed
///   shows a `Costed <amount>` / `Cost item attached` pill, but cost is entered
///   only in Cost Estimate and Cost by WBS — Schedule has no add-cost action.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/schedule/utils/schedule_wbs_packages.dart';
import 'package:ndu_project/schedule/utils/schedule_wbs_timelines.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/widgets/spell_check/spell_checking_text_controller.dart';

class ScheduleWbsPackagesCard extends StatefulWidget {
  const ScheduleWbsPackagesCard({super.key});

  /// Test seam: how many rows render before the list is cut off and a
  /// "Show all N" control appears. Kept small so the card stays a card.
  static const int initialVisibleRows = 8;

  @override
  State<ScheduleWbsPackagesCard> createState() =>
      _ScheduleWbsPackagesCardState();
}

class _ScheduleWbsPackagesCardState extends State<ScheduleWbsPackagesCard> {
  static const _accent = Color(0xFFB8860B);
  static const _gold = Color(0xFFFFC812);
  static const _textPrimary = Color(0xFF1A1D1F);
  static const _textSecondary = Color(0xFF6B7280);
  static const _border = Color(0xFFE4E7EC);

  bool _collapsed = false;
  bool _showAll = false;
  bool _busy = false;
  String _query = '';
  final TextEditingController _searchCtrl = SpellCheckTextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wbsProvider = context.watch<WBSProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final estimateProvider = context.watch<CostEstimateProvider>();

    final wbs = wbsProvider.wbs;
    final activities = scheduleProvider.schedule?.activities ?? const [];
    final rows = buildWbsPackageRows(wbs: wbs, activities: activities);
    final lines = estimateProvider.estimate?.lines ?? const <CostLine>[];

    final onSchedule = rows.where((r) => r.onSchedule).length;
    final missing = rows.length - onSchedule;
    final priced = rows.where((r) => r.isPriced).length;
    // Each button is enabled exactly when tapping it would write something —
    // computed from the same data the action writes from, never a package-level
    // proxy. A package whose rows are *partly* dated still has fillable rows,
    // and dated rows are precisely the input the WBS attach needs.
    final canAttachToWbs = collectScheduleTimelines(activities).isNotEmpty;
    final fillableFromWbs =
        countActivitiesFillableFromWbs(wbs: wbs, activities: activities);

    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? rows
        : rows
            .where((r) =>
                r.label.toLowerCase().contains(query) ||
                r.name.toLowerCase().contains(query) ||
                r.code.toLowerCase().contains(query))
            .toList(growable: false);
    final visible = _showAll
        ? filtered
        : filtered
            .take(ScheduleWbsPackagesCard.initialVisibleRows)
            .toList(growable: false);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(rows.length, onSchedule, missing),
          if (!_collapsed) ...[
            const Divider(height: 1, color: _border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _stat('${rows.length}', 'WBS packages', _accent),
                  _stat(
                      '$onSchedule',
                      'on the schedule',
                      onSchedule == rows.length
                          ? const Color(0xFF16A34A)
                          : _gold),
                  _stat(
                      '$missing',
                      'not scheduled yet',
                      missing == 0
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFEF4444)),
                  _stat(
                      '$priced',
                      'with a cost item',
                      priced == rows.length && rows.isNotEmpty
                          ? const Color(0xFF16A34A)
                          : _accent),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: (_busy || missing == 0)
                        ? null
                        : () => _addMissingToSchedule(missing),
                    icon: const Icon(Icons.playlist_add, size: 16),
                    label: Text(missing == 0
                        ? 'Every WBS package is on the schedule'
                        : 'Add $missing to schedule'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFF1F5F9),
                      disabledForegroundColor: _textSecondary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: (_busy || fillableFromWbs == 0)
                        ? null
                        : () => _fillScheduleDatesFromWbs(),
                    icon: const Icon(Icons.south, size: 16),
                    label: const Text('Fill schedule dates from WBS'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      side: const BorderSide(color: _border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: (_busy || !canAttachToWbs)
                        ? null
                        : _attachScheduleDatesToWbs,
                    icon: const Icon(Icons.north, size: 16),
                    label: const Text('Attach schedule dates to WBS'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      side: const BorderSide(color: _border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  hintText: 'Search WBS packages by code or name',
                  hintStyle: const TextStyle(fontSize: 13),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            if (rows.isEmpty)
              _emptyState()
            else if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Text(
                  'No WBS package matches "$_query".',
                  style: const TextStyle(fontSize: 13, color: _textSecondary),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Column(
                  children: [
                    for (final row in visible) _row(row, lines),
                    if (!_showAll &&
                        filtered.length >
                            ScheduleWbsPackagesCard.initialVisibleRows)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => setState(() => _showAll = true),
                          child: Text('Show all ${filtered.length} packages'),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _header(int total, int onSchedule, int missing) {
    return InkWell(
      onTap: () => setState(() => _collapsed = !_collapsed),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.account_tree_outlined,
                  size: 18, color: _accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WBS Packages',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    total == 0
                        ? 'Build the WBS and its packages will appear here, ready to schedule.'
                        : missing == 0
                            ? 'All $total work packages are on the schedule. $onSchedule scheduled.'
                            : '$missing of $total work packages are not on the schedule yet.',
                    style: const TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ],
              ),
            ),
            if (total > 0)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: missing == 0
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: missing == 0
                          ? const Color(0xFFBBF7D0)
                          : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Text(
                    missing == 0 ? 'Fully scheduled' : '$missing unscheduled',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: missing == 0
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB45309),
                    ),
                  ),
                ),
              ),
            Icon(
              _collapsed ? Icons.expand_more : Icons.expand_less,
              color: _textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: _textSecondary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No WBS work packages yet. Open the WBS module and decompose the '
              'scope into packages — each one then schedules from here.',
              style: TextStyle(fontSize: 12, color: _textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(WbsPackageRow row, List<CostLine> lines) {
    final priced = _costedValue(row, lines);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFD),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _pill(
                      row.onSchedule ? 'On schedule' : 'Not scheduled',
                      row.onSchedule
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFEF4444),
                    ),
                    if (row.isPriced) ...[
                      const SizedBox(width: 6),
                      _pill(
                        priced > 0
                            ? 'Costed ${_money(priced)}'
                            : 'Cost item attached',
                        _accent,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _timelineLine(row),
                  style: const TextStyle(fontSize: 11, color: _textSecondary),
                ),
              ],
            ),
          ),
          // Cost is entered in Cost Estimate / Cost by WBS, never here, so a
          // scheduled package only offers the schedule action.
          if (!row.onSchedule) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _busy ? null : () => _addOneToSchedule(row),
              icon: const Icon(Icons.add, size: 14),
              label:
                  const Text('Add to schedule', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                foregroundColor: _accent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _timelineLine(WbsPackageRow row) {
    final planned = _window(row.plannedStart, row.plannedFinish);
    final scheduled = _window(row.scheduledStart, row.scheduledFinish);
    final parts = <String>[];
    if (planned.isNotEmpty) parts.add('WBS planned $planned');
    if (scheduled.isNotEmpty) parts.add('scheduled $scheduled');
    if (row.activityNames.isNotEmpty) {
      parts.add(row.activityNames.first.length > 46
          ? '${row.activityNames.first.substring(0, 46)}…'
          : row.activityNames.first);
    }
    if (parts.isEmpty) {
      return 'No dates yet — add it to the schedule, then attach start and finish.';
    }
    return parts.join('  ·  ');
  }

  String _window(DateTime? start, DateTime? finish) {
    if (start == null && finish == null) return '';
    final s = start == null ? '—' : _shortDate(start);
    final f = finish == null ? '—' : _shortDate(finish);
    return '$s → $f';
  }

  String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Money already attached to this package, walked from the estimate lines
  /// this row references — the same figure the cost estimate shows.
  double _costedValue(WbsPackageRow row, List<CostLine> lines) {
    var total = 0.0;
    for (final id in row.costLineIds) {
      for (final line in lines) {
        if (line.id == id) total += effectiveLineTotal(line);
      }
    }
    return total;
  }

  String _money(double value) {
    if (value >= 1000000) return '\$${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '\$${(value / 1000).toStringAsFixed(0)}K';
    return '\$${value.toStringAsFixed(0)}';
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  Future<void> _addMissingToSchedule(int expected) async {
    final scheduleProvider = context.read<ScheduleProvider>();
    final wbsProvider = context.read<WBSProvider>();
    setState(() => _busy = true);
    try {
      final missing = wbsPackagesMissingFromSchedule(
        wbs: wbsProvider.wbs,
        activities: scheduleProvider.schedule?.activities ?? const [],
      );
      final added = scheduleProvider.attachWbsPackages(missing);
      _toast(added == 0
          ? 'Every WBS package is already on the schedule.'
          : 'Added $added WBS work package${added == 1 ? '' : 's'} to the '
                  'schedule${added < expected ? ' (${expected - added} were already there)' : ''}.'
              .trim());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addOneToSchedule(WbsPackageRow row) async {
    final scheduleProvider = context.read<ScheduleProvider>();
    setState(() => _busy = true);
    try {
      final added = scheduleProvider.attachWbsPackages([
        WbsPackagePull(
          nodeId: row.nodeId,
          code: row.code,
          name: row.name,
          level: row.level,
          description: null,
          plannedStart: row.plannedStart,
          plannedFinish: row.plannedFinish,
        ),
      ]);
      _toast(
        added == 0
            ? '${row.label} could not be added — the schedule is not ready yet.'
            : '${row.label} added to the schedule.',
        warning: added == 0,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fillScheduleDatesFromWbs() async {
    final scheduleProvider = context.read<ScheduleProvider>();
    final wbsProvider = context.read<WBSProvider>();
    setState(() => _busy = true);
    try {
      final rows = buildWbsPackageRows(
        wbs: wbsProvider.wbs,
        activities: scheduleProvider.schedule?.activities ?? const [],
      );
      final windows = <String, ({DateTime? start, DateTime? finish})>{
        for (final row in rows)
          if (row.hasPlannedWindow)
            row.nodeId: (start: row.plannedStart, finish: row.plannedFinish),
      };
      final filled = scheduleProvider.applyWbsPlannedDates(windows);
      _toast(
        filled == 0
            ? 'Every scheduled package already has its own dates.'
            // The window is split between the blank rows of each package, so
            // the result is a run of consecutive activities, not N copies of
            // the same span.
            : 'Split the WBS planned window across $filled schedule '
                'row${filled == 1 ? '' : 's'}. Adjust any row in the Activity '
                'Tree.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _attachScheduleDatesToWbs() {
    final scheduleProvider = context.read<ScheduleProvider>();
    final wbsProvider = context.read<WBSProvider>();
    final schedule = scheduleProvider.schedule;
    if (schedule == null) return;

    // A package whose schedule rows cover less than the window already planned
    // on the WBS is deliberately left alone — the attach widens, it does not
    // truncate. Counting them lets the message say so, rather than reporting a
    // bare "attached N packages" and leaving the rest looking untouched for no
    // stated reason.
    final rows = buildWbsPackageRows(
      wbs: wbsProvider.wbs,
      activities: schedule.activities,
    );
    final keptPlanned = rows.where((row) {
      if (!row.onSchedule || !row.hasPlannedWindow || !row.hasScheduleDates) {
        return false;
      }
      final startsLater = row.plannedStart != null &&
          row.scheduledStart != null &&
          row.scheduledStart!.isAfter(row.plannedStart!);
      final finishesEarlier = row.plannedFinish != null &&
          row.scheduledFinish != null &&
          row.scheduledFinish!.isBefore(row.plannedFinish!);
      return startsLater || finishesEarlier;
    }).length;

    final timelines = collectScheduleTimelines(schedule.activities);
    if (timelines.isEmpty) {
      _toast(
        'No scheduled dates to attach yet — give the WBS-linked rows a start '
        'and finish first.',
        warning: true,
      );
      return;
    }

    final updated = wbsProvider.applyScheduleTimelines(timelines);
    final keptNote = keptPlanned == 0
        ? ''
        : ' $keptPlanned package${keptPlanned == 1 ? '' : 's'} '
            '${keptPlanned == 1 ? 'is' : 'are'} planned wider on the WBS and '
            '${keptPlanned == 1 ? 'was' : 'were'} left as planned.';
    _toast(
      updated == 0
          ? 'WBS timelines are already up to date.$keptNote'
          : 'Attached scheduled dates to $updated WBS '
              'package${updated == 1 ? '' : 's'}.$keptNote',
    );
  }

  /// One message, one place. Each handler clears the previous SnackBar first:
  /// these actions are pressed repeatedly while working down a list, and
  /// queued messages leave the last few stale and unread.
  void _toast(String message, {bool warning = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: warning ? const Color(0xFFF59E0B) : Colors.white,
          duration: Duration(seconds: warning ? 5 : 4),
        ),
      );
  }
}
