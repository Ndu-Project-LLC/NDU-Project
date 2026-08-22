import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/services/navigation_context_service.dart';
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
/// Data source:
///   The `getAdminSurveyResponses` Callable Cloud Function (defined in
///   functions/index.js). It uses the Admin SDK, so it bypasses Firestore
///   rules — which matters because the firestore.rules deploy is currently
///   blocked by a missing STAGING_DEPLOY_TOKEN secret in CI, so the
///   direct-Firestore-read path can't be relied on. The Cloud Function
///   reads every user's `users/{uid}` document + their
///   `users/{uid}/profile/onboarding` document in parallel and returns
///   the combined payload as JSON.
///
/// Authorisation: the Cloud Function checks that the caller's email is in
/// ADMIN_EMAILS (currently `chungu424@gmail.com`) and throws
/// `permission-denied` otherwise. This screen is wrapped in
/// `AdminAuthWrapper` so it's only reachable by signed-in admins; the CF
/// check is a defence-in-depth second gate.
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

  /// Cached snapshot of the most recent Cloud Function response. Used by
  /// the CSV export bar so the admin can export the currently-filtered
  /// rows without re-fetching.
  List<_SurveyRow> _lastAllRows = const [];

  /// The active fetch future. Replaced by [_refresh] when the admin
  /// clicks the refresh button.
  late Future<List<_SurveyRow>> _fetchFuture;

  @override
  void initState() {
    super.initState();
    // Record admin dashboard context for logo navigation.
    NavigationContextService.instance
        .setLastAdminDashboard(AppRoutes.adminSurveyResponses);
    _fetchFuture = _fetchRows();
  }

  Future<List<_SurveyRow>> _fetchRows() async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'getAdminSurveyResponses',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );
    final result =
        await callable.call<Map<String, dynamic>>(<String, dynamic>{});
    final data = result.data;
    final usersList = (data['users'] as List<dynamic>?) ?? const [];
    final rows = <_SurveyRow>[];
    for (final u in usersList) {
      final map = u as Map<String, dynamic>;
      rows.add(_SurveyRow.fromJson(map));
    }
    // Sort: most recently completed first; users who haven't started
    // sink to the bottom.
    rows.sort((a, b) {
      final ta = a.completedAt;
      final tb = b.completedAt;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
    _lastAllRows = rows;
    return rows;
  }

  void _refresh() {
    setState(() {
      _fetchFuture = _fetchRows();
    });
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
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, color: Colors.black),
            tooltip: 'Refresh',
          ),
          const Padding(
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
              child: FutureBuilder<List<_SurveyRow>>(
                future: _fetchFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Loading survey responses…',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    final err = snapshot.error.toString();
                    final isPermission = err.contains('permission-denied') ||
                        err.contains('admin');
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isPermission
                                  ? Icons.lock_outline
                                  : Icons.error_outline,
                              size: 64,
                              color: isPermission
                                  ? Colors.amber
                                  : Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isPermission
                                  ? 'Admin access required'
                                  : 'Unable to load survey responses',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isPermission
                                  ? 'Your account is not on the admin email '
                                      'allowlist (chungu424@gmail.com). The Cloud '
                                      'Function getAdminSurveyResponses refuses '
                                      'to read other users\' survey answers for '
                                      'non-admin callers.'
                                  : 'The Cloud Function getAdminSurveyResponses '
                                      'could not be reached. Make sure it has been '
                                      'deployed (firebase deploy --only functions) '
                                      'and that you are signed in as an admin.\n\n'
                                      'Error: $err',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _refresh,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final rows = snapshot.data ?? const <_SurveyRow>[];
                  final filtered = _applyFilter(rows);

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
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
              ),
            ),
            _buildCsvExportBar(rowsSource: _lastFilteredRows),
          ],
        ),
      ),
    );
  }

  /// Cached filtered rows used by the CSV export bar at the bottom of the
  /// screen. Updated on every build pass where filtering is applied.
  List<_SurveyRow> _lastFilteredRows = const [];

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
                r.onboarding != null &&
                r.completedAt != null &&
                !r.onboarding!.skipped)
            .toList();
        break;
      case 'in_progress':
        out = out
            .where((r) =>
                r.onboarding != null &&
                r.completedAt == null &&
                !r.onboarding!.skipped)
            .toList();
        break;
      case 'skipped':
        out = out.where((r) => r.onboarding?.skipped == true).toList();
        break;
      case 'not_started':
        out = out.where((r) => r.onboarding == null).toList();
        break;
      default:
        break;
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      out = out.where((r) {
        final o = r.onboarding;
        final haystack = <String>[
          r.email,
          r.displayName,
          o?.position ?? '',
          o?.positionOther ?? '',
          o?.country ?? '',
          o?.countryOther ?? '',
          o?.currency ?? '',
          o?.currencyOther ?? '',
          o?.organizationOverview ?? '',
          ...(o?.currentTools ?? const []),
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
    buf.writeln('uid,email,displayName,createdAt,completedAt,skipped,position,'
        'isDecisionMaker,country,currency,currentTools,organizationOverview,'
        'invitedEmails,maxTeamSizePerProject,tierAtSignup');
    for (final r in rows) {
      final o = r.onboarding;
      final cells = <String>[
        r.uid,
        r.email,
        r.displayName,
        r.createdAt?.toUtc().toIso8601String() ?? '',
        r.completedAt?.toUtc().toIso8601String() ?? '',
        (o?.skipped ?? false).toString(),
        o?.positionDisplay ?? '',
        o?.isDecisionMaker?.toString() ?? '',
        o?.countryDisplay ?? '',
        o?.currencyDisplay ?? '',
        (o?.currentToolsDisplay ?? const []).join('; '),
        o?.organizationOverview ?? '',
        (o?.invitedEmails ?? const []).join('; '),
        o?.maxTeamSizePerProject?.toString() ?? '',
        o?.tierAtSignup ?? '',
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

/// Single row in the admin survey-responses table. Built directly from the
/// Cloud Function's JSON payload (no Firestore types involved).
class _SurveyRow {
  final String uid;
  final String email;
  final String displayName;
  final DateTime? createdAt;
  final bool isAdmin;
  final bool isActive;
  final _OnboardingAnswers? onboarding;

  /// Convenience accessor: the onboarding's completedAt (or null when the
  /// user has not started the survey).
  DateTime? get completedAt => onboarding?.completedAt;

  const _SurveyRow({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.createdAt,
    required this.isAdmin,
    required this.isActive,
    required this.onboarding,
  });

  factory _SurveyRow.fromJson(Map<String, dynamic> json) {
    final onboardingJson = json['onboarding'] as Map<String, dynamic>?;
    return _SurveyRow(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      createdAt: _parseIso(json['createdAt']),
      isAdmin: json['isAdmin'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      onboarding: onboardingJson != null
          ? _OnboardingAnswers.fromJson(onboardingJson)
          : null,
    );
  }

  static DateTime? _parseIso(dynamic v) {
    if (v == null) return null;
    if (v is String && v.isNotEmpty) {
      return DateTime.tryParse(v);
    }
    return null;
  }
}

/// Plain-Dart mirror of [ProfileOnboardingAnswers] — only the fields the
/// admin screen needs. We avoid importing the service-side class because
/// that pulls in the Firestore types, and the Cloud Function hands us
/// plain JSON.
class _OnboardingAnswers {
  final String? position;
  final String? positionOther;
  final bool? isDecisionMaker;
  final String? country;
  final String? countryOther;
  final String? currency;
  final String? currencyOther;
  final List<String> currentTools;
  final String? currentToolsOther;
  final String? organizationOverview;
  final List<String> invitedEmails;
  final int? maxTeamSizePerProject;
  final String? tierAtSignup;
  final DateTime? completedAt;
  final bool skipped;
  final DateTime? updatedAt;

  const _OnboardingAnswers({
    required this.position,
    required this.positionOther,
    required this.isDecisionMaker,
    required this.country,
    required this.countryOther,
    required this.currency,
    required this.currencyOther,
    required this.currentTools,
    required this.currentToolsOther,
    required this.organizationOverview,
    required this.invitedEmails,
    required this.maxTeamSizePerProject,
    required this.tierAtSignup,
    required this.completedAt,
    required this.skipped,
    required this.updatedAt,
  });

  factory _OnboardingAnswers.fromJson(Map<String, dynamic> json) {
    return _OnboardingAnswers(
      position: json['position'] as String?,
      positionOther: json['positionOther'] as String?,
      isDecisionMaker: json['isDecisionMaker'] as bool?,
      country: json['country'] as String?,
      countryOther: json['countryOther'] as String?,
      currency: json['currency'] as String?,
      currencyOther: json['currencyOther'] as String?,
      currentTools: ((json['currentTools'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      currentToolsOther: json['currentToolsOther'] as String?,
      organizationOverview: json['organizationOverview'] as String?,
      invitedEmails: ((json['invitedEmails'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      maxTeamSizePerProject: (json['maxTeamSizePerProject'] as num?)?.toInt(),
      tierAtSignup: json['tierAtSignup'] as String?,
      completedAt: _parseIso(json['completedAt']),
      skipped: (json['skipped'] as bool?) ?? false,
      updatedAt: _parseIso(json['updatedAt']),
    );
  }

  static DateTime? _parseIso(dynamic v) {
    if (v == null) return null;
    if (v is String && v.isNotEmpty) {
      return DateTime.tryParse(v);
    }
    return null;
  }

  String get positionDisplay {
    if (position == 'Other' && (positionOther?.isNotEmpty ?? false)) {
      return positionOther!.trim();
    }
    return position ?? '';
  }

  String get countryDisplay {
    if (country == 'Other' && (countryOther?.isNotEmpty ?? false)) {
      return countryOther!.trim();
    }
    return country ?? '';
  }

  String get currencyDisplay {
    if (currency == 'Other' && (currencyOther?.isNotEmpty ?? false)) {
      return currencyOther!.trim();
    }
    return currency ?? '';
  }

  List<String> get currentToolsDisplay {
    final out = <String>[...currentTools];
    final other = currentToolsOther?.trim();
    if (currentTools.contains('Other') && other != null && other.isNotEmpty) {
      out.remove('Other');
      out.add('Other: $other');
    }
    return out;
  }
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
    final o = row.onboarding;
    final status = _statusChip(o);

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
                      row.displayName.isNotEmpty
                          ? row.displayName[0].toUpperCase()
                          : (row.email.isNotEmpty
                              ? row.email[0].toUpperCase()
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
                          row.displayName.isNotEmpty
                              ? row.displayName
                              : '(no display name)',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          row.email,
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
                    child: _DetailGrid(row: row),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(_OnboardingAnswers? o) {
    String label;
    Color bg;
    Color fg;
    if (o == null) {
      label = 'Not started';
      bg = Colors.grey.withValues(alpha: 0.18);
      fg = Colors.black54;
    } else if (o.skipped) {
      label = 'Skipped';
      bg = Colors.orange.withValues(alpha: 0.18);
      fg = Colors.deepOrange;
    } else if (o.completedAt != null) {
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
  const _DetailGrid({required this.row});

  final _SurveyRow row;

  @override
  Widget build(BuildContext context) {
    final o = row.onboarding;
    if (o == null) {
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
    final fmt = DateFormat.yMMMd().add_jm();
    final rows = <_DetailRow>[
      _DetailRow(
        label: 'Account created',
        value: row.createdAt != null
            ? fmt.format(row.createdAt!.toLocal())
            : '—',
      ),
      _DetailRow(
        label: 'Survey completed at',
        value: o.completedAt != null ? fmt.format(o.completedAt!.toLocal()) : '—',
      ),
      _DetailRow(label: 'Skipped', value: o.skipped ? 'Yes' : 'No'),
      _DetailRow(
        label: 'Position',
        value: o.positionDisplay.isEmpty ? '—' : o.positionDisplay,
      ),
      _DetailRow(
        label: 'Decision maker?',
        value: o.isDecisionMaker == null
            ? '—'
            : (o.isDecisionMaker! ? 'Yes' : 'No'),
      ),
      _DetailRow(
        label: 'Country',
        value: o.countryDisplay.isEmpty ? '—' : o.countryDisplay,
      ),
      _DetailRow(
        label: 'Currency',
        value: o.currencyDisplay.isEmpty ? '—' : o.currencyDisplay,
      ),
      _DetailRow(
        label: 'Current tools',
        value: o.currentToolsDisplay.isEmpty
            ? '—'
            : o.currentToolsDisplay.join(', '),
      ),
      _DetailRow(
        label: 'Team invites sent',
        value: o.invitedEmails.isEmpty
            ? '—'
            : '${o.invitedEmails.length} (${o.invitedEmails.join(', ')})',
      ),
      _DetailRow(
        label: 'Max team size / project',
        value: o.maxTeamSizePerProject?.toString() ?? '—',
      ),
      _DetailRow(
        label: 'Tier at signup',
        value: o.tierAtSignup ?? '—',
      ),
      _DetailRow(
        label: 'Organization overview',
        value: (o.organizationOverview ?? '').isEmpty
            ? '—'
            : o.organizationOverview!,
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
