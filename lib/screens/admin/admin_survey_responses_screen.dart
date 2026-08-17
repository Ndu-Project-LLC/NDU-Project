import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/user_model.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/services/navigation_context_service.dart';
import 'package:ndu_project/services/profile_onboarding_service.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/widgets/unified_phase_header.dart';

// Conditional import: web impl uses dart:html to trigger a browser
// download; non-web stub returns false so the caller can fall back to
// logging the CSV to the debug console.
import 'csv_download_web.dart'
    if (dart.library.html) 'csv_download_web_html.dart'
    as csv_download;

/// Admin-panel view of every user's profile-onboarding (survey) responses.
///
/// The survey itself lives on [ProfileOnboardingScreen] and the answers are
/// persisted by [ProfileOnboardingService] to Firestore at
/// `users/{uid}/profile/onboarding`. This screen is the read-only admin
/// counterpart — it lists every user's responses in one place so the admin
/// team can audit them at a glance.
///
/// Data sources:
///   - [UserService.watchAllUsers] — top-level `users/{uid}` docs (for the
///     email + display name cross-reference).
///   - [ProfileOnboardingService.watchAllForAdmin] — every user's
///     `profile/onboarding` doc, streamed live so the admin panel sees
///     responses the moment a user submits the survey.
///
/// The Firestore rule on `users/{uid}/profile/{document=**}` grants
/// `isAdmin()` read access (in addition to the document owner), which is
/// what makes the second stream possible.
class AdminSurveyResponsesScreen extends StatefulWidget {
  const AdminSurveyResponsesScreen({super.key});

  @override
  State<AdminSurveyResponsesScreen> createState() =>
      _AdminSurveyResponsesScreenState();
}

class _AdminSurveyResponsesScreenState
    extends State<AdminSurveyResponsesScreen> {
  /// One of: 'all' | 'completed' | 'in_progress' | 'skipped' | 'not_started'.
  String _filterBy = 'all';

  /// Free-text search across email / display name / position / country.
  String _searchQuery = '';

  /// Cached filtered rows used by the CSV export bar at the bottom of the
  /// screen. Updated on every build pass where filtering is applied.
  List<_SurveyRow> _lastFilteredRows = const [];

  @override
  void initState() {
    super.initState();
    // Record admin dashboard context for logo navigation.
    NavigationContextService.instance
        .setLastAdminDashboard(AppRoutes.adminSurveyResponses);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: const Row(
          children: [
            Icon(Icons.assignment_outlined,
                color: Color(0xFFFFC107), size: 28),
            SizedBox(width: 12),
            Text(
              'Survey Responses',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: UnifiedProfileMenu(compact: true),
          ),
        ],
      ),
      body: SafeArea(
        top: true,
        child: Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: StreamBuilder<List<UserModel>>(
                stream: UserService.watchAllUsers(),
                builder: (context, usersSnapshot) {
                  if (usersSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (usersSnapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                                'Error loading users: ${usersSnapshot.error}'),
                          ],
                        ),
                      ),
                    );
                  }

                  final users = usersSnapshot.data ?? const [];

                  return StreamBuilder<List<AdminOnboardingRecord>>(
                    stream: ProfileOnboardingService.watchAllForAdmin(),
                    builder: (context, onboardingSnapshot) {
                      if (onboardingSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (onboardingSnapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lock_outline,
                                    size: 64, color: Colors.amber),
                                const SizedBox(height: 16),
                                const Text(
                                  'Unable to read survey responses',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'This usually means the Firestore rules '
                                  'have not been deployed yet, or the '
                                  'signed-in admin account lacks permission. '
                                  'Error: ${onboardingSnapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final records = onboardingSnapshot.data ??
                          const <AdminOnboardingRecord>[];

                      // Cross-reference: pair each onboarding record with
                      // its UserModel (for email + display name). Users
                      // without an onboarding doc are still surfaced as
                      // "not started" so the admin can see who hasn't
                      // taken the survey yet.
                      final byUid = {for (final r in records) r.uid: r};
                      final rows = <_SurveyRow>[];
                      for (final u in users) {
                        final rec = byUid[u.uid];
                        rows.add(_SurveyRow(
                          user: u,
                          answers: rec?.answers,
                        ));
                      }

                      // Most recently completed first; users who haven't
                      // started sink to the bottom.
                      rows.sort((a, b) {
                        final ta = a.answers?.completedAt;
                        final tb = b.answers?.completedAt;
                        if (ta == null && tb == null) return 0;
                        if (ta == null) return 1;
                        if (tb == null) return -1;
                        return tb.compareTo(ta);
                      });

                      final filtered = _applyFilter(rows);

                      if (filtered.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.assignment_outlined,
                                  size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No survey responses match this filter',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Try switching the filter above or clearing '
                                'the search box.',
                                style: TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(32),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) => _SurveyResponseCard(
                          row: filtered[index],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            _buildCsvExportBar(rowsSource: _lastFilteredRows),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        border: Border(
            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              {'label': 'All', 'value': 'all'},
              {'label': 'Completed', 'value': 'completed'},
              {'label': 'In Progress', 'value': 'in_progress'},
              {'label': 'Skipped', 'value': 'skipped'},
              {'label': 'Not Started', 'value': 'not_started'},
            ].map((filter) {
              return ChoiceChip(
                label: Text(filter['label']!),
                selected: _filterBy == filter['value'],
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _filterBy = filter['value']!);
                  }
                },
                selectedColor: const Color(0xFFFFC107),
                backgroundColor: Colors.grey.withValues(alpha: 0.1),
                labelStyle: TextStyle(
                  color: _filterBy == filter['value']
                      ? Colors.black
                      : Colors.black87,
                  fontWeight: _filterBy == filter['value']
                      ? FontWeight.w700
                      : FontWeight.w600,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by email, name, position, or country…',
              hintStyle: const TextStyle(color: Colors.black54),
              prefixIcon: const Icon(Icons.search, color: Colors.black54),
              filled: true,
              fillColor: Colors.grey.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value.trim());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCsvExportBar({required List<_SurveyRow> rowsSource}) {
    final count = rowsSource.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        border: Border(
            top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count == 0
                  ? 'No rows to export'
                  : 'Showing $count survey response${count == 1 ? '' : 's'}',
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: count == 0
                ? null
                : () async {
                    final csv = _buildCsv(rowsSource);
                    final encoded = utf8.encode(csv);
                    final ok = await csv_download.downloadCsv(
                      bytes: encoded,
                      filename:
                          'survey_responses_${DateTime.now().toIso8601String().split('T').first}.csv',
                    );
                    if (!ok) {
                      // Fallback: print to debug console so the admin
                      // can still grab the CSV from devtools if the
                      // browser blocks the download.
                      debugPrint('CSV download failed — content:\n$csv');
                    }
                  },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.download),
            label: const Text('Export CSV'),
          ),
        ],
      ),
    );
  }

  List<_SurveyRow> _applyFilter(List<_SurveyRow> rows) {
    var out = rows;
    switch (_filterBy) {
      case 'completed':
        out = out
            .where((r) =>
                r.answers != null &&
                r.answers!.completedAt != null &&
                !r.answers!.skipped)
            .toList();
        break;
      case 'in_progress':
        out = out
            .where((r) =>
                r.answers != null &&
                r.answers!.completedAt == null &&
                !r.answers!.skipped)
            .toList();
        break;
      case 'skipped':
        out = out.where((r) => r.answers?.skipped == true).toList();
        break;
      case 'not_started':
        out = out.where((r) => r.answers == null).toList();
        break;
      default:
        break;
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      out = out.where((r) {
        final a = r.answers;
        final haystack = <String>[
          r.user.email,
          r.user.displayName,
          a?.position ?? '',
          a?.positionOther ?? '',
          a?.country ?? '',
          a?.countryOther ?? '',
          a?.currency ?? '',
          a?.currencyOther ?? '',
          a?.organizationOverview ?? '',
          ...(a?.currentTools ?? const []),
        ].join(' ').toLowerCase();
        return haystack.contains(q);
      }).toList();
    }

    // Cache for the CSV export bar.
    _lastFilteredRows = out;
    return out;
  }

  String _buildCsv(List<_SurveyRow> rows) {
    final buf = StringBuffer();
    buf.writeln('uid,email,displayName,completedAt,skipped,position,'
        'isDecisionMaker,country,currency,currentTools,organizationOverview,'
        'invitedEmails,maxTeamSizePerProject,tierAtSignup');
    for (final r in rows) {
      final a = r.answers;
      final cells = <String>[
        r.user.uid,
        r.user.email,
        r.user.displayName,
        a?.completedAt != null
            ? a!.completedAt!.toUtc().toIso8601String()
            : '',
        (a?.skipped ?? false).toString(),
        a?.positionDisplay ?? '',
        a?.isDecisionMaker?.toString() ?? '',
        a?.countryDisplay ?? '',
        a?.currencyDisplay ?? '',
        (a?.currentToolsDisplay ?? const []).join('; '),
        a?.organizationOverview ?? '',
        (a?.invitedEmails ?? const []).join('; '),
        a?.maxTeamSizePerProject?.toString() ?? '',
        a?.tierAtSignup ?? '',
      ];
      buf.writeln(cells.map(_csvCell).join(','));
    }
    return buf.toString();
  }

  String _csvCell(String input) {
    final v = input.replaceAll('"', '""');
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"$v"';
    }
    return v;
  }
}

/// Single row in the admin survey-responses table: a [UserModel] paired with
/// their optional [ProfileOnboardingAnswers] (null when the user hasn't
/// started the survey yet).
class _SurveyRow {
  final UserModel user;
  final ProfileOnboardingAnswers? answers;

  const _SurveyRow({required this.user, required this.answers});
}

/// Draws a single user's survey responses as an expandable card.
///
/// Collapsed state shows: email + display name + status chip + key answer
/// (position / decision-maker). Expanded state shows every answer field
/// in a tidy grid so the admin can read the whole survey at once.
class _SurveyResponseCard extends StatefulWidget {
  const _SurveyResponseCard({required this.row});

  final _SurveyRow row;

  @override
  State<_SurveyResponseCard> createState() => _SurveyResponseCardState();
}

class _SurveyResponseCardState extends State<_SurveyResponseCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final a = row.answers;
    final status = _statusChip(a);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFFFC107)
                        .withValues(alpha: 0.18),
                    child: Text(
                      row.user.displayName.isNotEmpty
                          ? row.user.displayName[0].toUpperCase()
                          : (row.user.email.isNotEmpty
                              ? row.user.email[0].toUpperCase()
                              : '?'),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.user.displayName.isNotEmpty
                              ? row.user.displayName
                              : '(no display name)',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          row.user.email,
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  status,
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOutCubic,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _DetailGrid(answers: a),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(ProfileOnboardingAnswers? a) {
    String label;
    Color bg;
    Color fg;
    if (a == null) {
      label = 'Not started';
      bg = Colors.grey.withValues(alpha: 0.18);
      fg = Colors.black54;
    } else if (a.skipped) {
      label = 'Skipped';
      bg = Colors.orange.withValues(alpha: 0.18);
      fg = Colors.deepOrange;
    } else if (a.completedAt != null) {
      label = 'Completed';
      bg = Colors.green.withValues(alpha: 0.18);
      fg = Colors.green.shade800;
    } else {
      label = 'In progress';
      bg = const Color(0xFFFFC107).withValues(alpha: 0.22);
      fg = Colors.amber.shade900;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.answers});

  final ProfileOnboardingAnswers? answers;

  @override
  Widget build(BuildContext context) {
    if (answers == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'This user has not started the onboarding survey yet. Their '
          'responses will appear here automatically once they complete at '
          'least one step.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }
    final a = answers!;
    final fmt = DateFormat.yMMMd().add_jm();
    final rows = <_DetailRow>[
      _DetailRow(
        label: 'Completed at',
        value: a.completedAt != null ? fmt.format(a.completedAt!.toLocal()) : '—',
      ),
      _DetailRow(label: 'Skipped', value: a.skipped ? 'Yes' : 'No'),
      _DetailRow(label: 'Position', value: a.positionDisplay.isEmpty ? '—' : a.positionDisplay),
      _DetailRow(
        label: 'Decision maker?',
        value: a.isDecisionMaker == null
            ? '—'
            : (a.isDecisionMaker! ? 'Yes' : 'No'),
      ),
      _DetailRow(
        label: 'Country',
        value: a.countryDisplay.isEmpty ? '—' : a.countryDisplay,
      ),
      _DetailRow(
        label: 'Currency',
        value: a.currencyDisplay.isEmpty ? '—' : a.currencyDisplay,
      ),
      _DetailRow(
        label: 'Current tools',
        value: a.currentToolsDisplay.isEmpty
            ? '—'
            : a.currentToolsDisplay.join(', '),
      ),
      _DetailRow(
        label: 'Team invites sent',
        value: a.invitedEmails.isEmpty
            ? '—'
            : '${a.invitedEmails.length} (${a.invitedEmails.join(', ')})',
      ),
      _DetailRow(
        label: 'Max team size / project',
        value: a.maxTeamSizePerProject?.toString() ?? '—',
      ),
      _DetailRow(
        label: 'Tier at signup',
        value: a.tierAtSignup ?? '—',
      ),
      _DetailRow(
        label: 'Organization overview',
        value: (a.organizationOverview ?? '').isEmpty
            ? '—'
            : a.organizationOverview!,
        multiline: true,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in rows) ...[
            r,
            if (r != rows.last)
              Divider(
                  height: 1,
                  color: Colors.grey.withValues(alpha: 0.18)),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.multiline = false,
  });

  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.55),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
