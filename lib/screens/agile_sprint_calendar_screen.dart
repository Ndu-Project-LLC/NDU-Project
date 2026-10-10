import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/models/feature_model.dart';
import 'package:ndu_project/models/agile_release_plan.dart';
import 'package:ndu_project/models/roadmap_sprint.dart';
import 'package:ndu_project/models/staffing_row.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/roadmap_service.dart';
import 'package:ndu_project/services/agile_wireframe_service.dart';
import 'package:ndu_project/services/epic_feature_service.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/utils/agile_capacity_model.dart';
import 'package:ndu_project/utils/agile_ceremony_schedule.dart';
import 'package:ndu_project/utils/agile_schedule_controls.dart';
import 'package:ndu_project/utils/download_helper.dart';
import 'package:ndu_project/services/user_preferences_service.dart';
import 'package:ndu_project/utils/unique_id.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/launch_data_table.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/responsive.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

import 'package:ndu_project/widgets/delete_success_snackbar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/spell_check/spell_checking_text_controller.dart';

const Color _kBackground = Colors.white;
const Color _kBorder = Color(0xFFE5E7EB);
const Color _kMuted = Color(0xFF6B7280);
const Color _kHeadline = Color(0xFF111827);
const Color _kAccent = Color(0xFFD97706);

class AgileSprintCalendarScreen extends StatefulWidget {
  const AgileSprintCalendarScreen({super.key});

  @override
  State<AgileSprintCalendarScreen> createState() =>
      _AgileSprintCalendarScreenState();
}

class _AgileSprintCalendarScreenState extends State<AgileSprintCalendarScreen> {
  List<RoadmapSprint> _sprints = [];
  List<AgileTask> _storyCache = [];
  List<Feature> _features = [];
  String? _storyCacheProjectId;
  bool _isLoading = true;
  Map<AgileCeremony, AgileCeremonyEntry> _ceremonies = {};
  List<AgileReleasePlan> _releases = [];
  List<StaffingRow> _staffing = [];
  List<ExternalCostItem> _externalCosts = [];
  int _sprintDays = AgileCapacityModel.fallbackSprintDays;
  String _searchQuery = '';
  final TextEditingController _searchController = SpellCheckTextEditingController();
  Timer? _saveDebounce;

  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  final NumberFormat _moneyFormat = NumberFormat('#,##0');

  List<RoadmapSprint> get _filteredSprints {
    if (_searchQuery.isEmpty) return _sprints;
    final q = _searchQuery.toLowerCase();
    return _sprints
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            s.goal.toLowerCase().contains(q))
        .toList();
  }

  String? get _projectId {
    try {
      return ProjectDataInherited.maybeOf(context)?.projectData.projectId;
    } catch (e) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final pid = _projectId;
    if (pid == null) return;
    setState(() => _isLoading = true);
    try {
      final sprints = await RoadmapService.loadSprints(projectId: pid);
      final calendarData = await AgileWireframeService.loadSprintCalendar(pid);
      final stories =
          await ExecutionPhaseService.loadAgileTasks(projectId: pid);
      final features = await EpicFeatureService.loadAllFeatures(pid);
      final releases = await AgileWireframeService.loadReleasePlans(pid);
      final staffing = await ExecutionPhaseService.loadStaffingRows(projectId: pid);
      final deliveryModel = await AgileWireframeService.loadDeliveryModel(pid);
      if (!mounted) return;
      setState(() {
        _sprints = sprints;
        _storyCache = stories;
        _features = features;
        _storyCacheProjectId = pid;
        _sprintDays = ceremonySprintDays(
            deliveryModel['sprintLength']?.toString() ?? '');
        _ceremonies = _loadCeremonies(calendarData);
        _releases = releases;
        _staffing = staffing;
        _externalCosts = _loadExternalCosts(calendarData);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Ceremony cadence as saved, with defaults for anything not yet chosen.
  Map<AgileCeremony, AgileCeremonyEntry> _loadCeremonies(
      Map<String, dynamic> calendarData) {
    final ceremonies = _defaultCeremonies();
    final saved = calendarData['ceremonySchedule'];
    if (saved is Map) {
      for (final c in AgileCeremony.values) {
        final raw = saved[c.name];
        if (raw is Map) {
          ceremonies[c] =
              AgileCeremonyEntry.fromMap(Map<String, dynamic>.from(raw));
        }
      }
    }
    return ceremonies;
  }

  /// Starting cadence drawn from the agile delivery model: planning on the
  /// first day of the sprint, stand-ups every work day, grooming twice a week,
  /// and demo + retro on the last Friday. The blockers hub starts switched off.
  Map<AgileCeremony, AgileCeremonyEntry> _defaultCeremonies() => {
        AgileCeremony.sprintPlanning: const AgileCeremonyEntry(
            weekdays: {DateTime.monday}, durationMinutes: 120),
        AgileCeremony.dailyStandup: const AgileCeremonyEntry(
            weekdays: {1, 2, 3, 4, 5}, durationMinutes: 15),
        AgileCeremony.backlogGrooming: const AgileCeremonyEntry(
            weekdays: {DateTime.tuesday, DateTime.thursday},
            durationMinutes: 60),
        AgileCeremony.sprintDemo: const AgileCeremonyEntry(
            weekdays: {DateTime.friday}, durationMinutes: 60),
        AgileCeremony.retrospective: const AgileCeremonyEntry(
            weekdays: {DateTime.friday}, durationMinutes: 60),
        AgileCeremony.blockersHub: const AgileCeremonyEntry(
            weekdays: {1, 2, 3, 4, 5}, durationMinutes: 60, enabled: false),
      };

  Future<void> _saveCeremonies() async {
    final pid = _projectId;
    if (pid == null) return;
    await AgileWireframeService.saveSprintCalendar(
      projectId: pid,
      data: {
        'ceremonySchedule': {
          for (final entry in _ceremonies.entries)
            entry.key.name: entry.value.toMap(),
        },
        'sprintLengthDays': _sprintDays,
        'externalCosts': _externalCosts.map((c) => c.toMap()).toList(),
      },
    );
  }

  void _addSprint() {
    showDialog(
      context: context,
      builder: (ctx) => _SprintEditDialog(
        onSave: (sprint) {
          final pid = _projectId;
          if (pid == null) return;
          final updatedList = [..._sprints, sprint];
          RoadmapService.saveSprints(projectId: pid, sprints: updatedList);
          setState(() => _sprints = updatedList);
        },
      ),
    );
  }

  void _editSprint(int index) {
    final sprint = _sprints[index];
    showDialog(
      context: context,
      builder: (ctx) => _SprintEditDialog(
        existing: sprint,
        onSave: (updated) {
          final pid = _projectId;
          if (pid == null) return;
          final updatedList = [..._sprints];
          updatedList[index] = updated;
          RoadmapService.saveSprints(projectId: pid, sprints: updatedList);
          setState(() => _sprints = updatedList);
        },
      ),
    );
  }

  Future<void> _deleteSprint(int index) async {
    final confirmed = await launchConfirmDelete(context, itemName: 'sprint');
    if (!confirmed || !mounted) return;
    final pid = _projectId;
    if (pid == null) return;
    final updatedList = [..._sprints];
    updatedList.removeAt(index);
    await RoadmapService.saveSprints(projectId: pid, sprints: updatedList);
    if (!mounted) return;
    setState(() => _sprints = updatedList);
    showDeleteSuccessSnackBar(context, itemLabel: 'Sprint');
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = AppBreakpoints.isMobile(context);
    final double hp = isMobile ? 20 : 40;

    return Scaffold(
      floatingActionButton: const KazAiChatBubble(positioned: false),
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: const InitiationLikeSidebar(
                  activeItemLabel: 'Agile Delivery Model - Sprint Calendar'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: hp, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PlanningPhaseHeader(
                        title: 'Sprint Cadence & Calendar',
                        onBack: () => PlanningPhaseNavigation.goToPrevious(
                            context, 'agile_sprint_calendar'),
                        onForward: () => PlanningPhaseNavigation.goToNext(
                            context, 'agile_sprint_calendar'),
                        onExportPdf: _exportPdf),
                    const SizedBox(height: 32),
                    const Text(
                        'Define sprint duration, dates, and ceremony schedule.',
                        style: TextStyle(fontSize: 15, color: _kMuted)),
                    const SizedBox(height: 24),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      _buildCapacitySummary(),
                      const SizedBox(height: 16),
                      VoiceTextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search sprints...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                      const SizedBox(height: 16),
                      if (_filteredSprints.isEmpty)
                        _buildEmptyState(_searchQuery.isNotEmpty
                            ? 'No sprints match "$_searchQuery".'
                            : 'No sprints defined. Create your first sprint.')
                      else
                        Column(
                          children: _filteredSprints
                              .asMap()
                              .entries
                              .map((entry) => RepaintBoundary(
                                    child: _buildSprintCard(
                                        entry.key, entry.value),
                                  ))
                              .toList(growable: false),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _addSprint,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Sprint'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _kAccent,
                              side: const BorderSide(color: _kAccent),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _features.isEmpty
                                ? null
                                : _assignFeaturesToSprint,
                            icon:
                                const Icon(Icons.assignment_outlined, size: 18),
                            label: const Text('Assign Features'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF059669),
                              side: const BorderSide(color: Color(0xFF059669)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _buildCeremonySection(),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _exportCeremoniesIcs,
                          icon: const Icon(Icons.event_available_outlined,
                              size: 18),
                          label: const Text('Export calendar (.ics)'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildScheduleControls(),
                    ],
                    const SizedBox(height: 24),
                    LaunchPhaseNavigation(
                      backLabel: PlanningPhaseNavigation.backLabel(
                          'agile_sprint_calendar'),
                      nextLabel: PlanningPhaseNavigation.nextLabel(
                          'agile_sprint_calendar'),
                      onBack: () => PlanningPhaseNavigation.goToPrevious(
                          context, 'agile_sprint_calendar'),
                      onNext: () => PlanningPhaseNavigation.goToNext(
                          context, 'agile_sprint_calendar'),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<ExternalCostItem> _loadExternalCosts(Map<String, dynamic> calendarData) {
    final raw = calendarData['externalCosts'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((m) => ExternalCostItem.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  String _fmtDate(DateTime? d) =>
      d == null ? 'Not yet known' : _dateFormat.format(d);

  Future<void> _exportCalendar() async {
    // The account's configured timezone (Settings > Timezone).
    final timezoneName = await UserPreferencesService.timezone();
    if (!mounted) return;
    final ics = buildCeremonyIcs(
      sprints: _sprints,
      ceremonies: _ceremonies,
      stamp: DateTime.now(),
      calendarName: 'Agile ceremonies',
      timezoneName: timezoneName,
      releaseMilestones: [
        for (final r in _releases)
          if (r.releaseDate != null)
            MapEntry(
                r.releaseLabel.isNotEmpty ? r.releaseLabel : 'Release',
                r.releaseDate!),
      ],
    );
    try {
      downloadFile(utf8.encode(ics), 'agile_ceremonies.ics',
          mimeType: 'text/calendar');
    } on UnsupportedError {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Calendar export is available in the web app.')));
    }
  }

  Future<void> _addExternalCost() async {
    final nameCtrl = SpellCheckTextEditingController();
    final amountCtrl = TextEditingController();
    var category = 'Contract';
    final result = await showDialog<ExternalCostItem>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add external cost'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VoiceTextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButton<String>(
                  value: category,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'Contract', child: Text('Contract')),
                    DropdownMenuItem(value: 'Purchase', child: Text('Purchase')),
                    DropdownMenuItem(value: 'SSHER', child: Text('SSHER')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => category = v ?? category),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Amount', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = parseMoney(amountCtrl.text);
                if (nameCtrl.text.trim().isEmpty || amount <= 0) return;
                Navigator.pop(
                  ctx,
                  ExternalCostItem(
                    id: newId(),
                    name: nameCtrl.text.trim(),
                    category: category,
                    amount: amount,
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    amountCtrl.dispose();
    if (result == null || !mounted) return;
    setState(() => _externalCosts = [..._externalCosts, result]);
    _saveCeremonies();
  }

  void _removeExternalCost(int index) {
    setState(() {
      _externalCosts = [..._externalCosts]..removeAt(index);
    });
    _saveCeremonies();
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: _kHeadline)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _line(String text, {Color color = _kHeadline, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
    );
  }

  Widget _buildScheduleControls() {
    final now = DateTime.now();
    final forecast =
        buildVelocityForecast(stories: _storyCache, sprints: _sprints, today: now);
    final milestones = buildReleaseMilestones(
        releases: _releases, stories: _storyCache, sprints: _sprints);
    final flags = <RedFlag>[
      ...buildSprintCapacityFlags(stories: _storyCache, sprints: _sprints),
      for (final m in milestones) ...m.flags,
    ];
    final projectStart = _sprints
        .map((s) => s.startDate)
        .whereType<DateTime>()
        .fold<DateTime?>(
            null, (a, b) => a == null || b.isBefore(a) ? b : a);
    final cost = buildAgileCostSummary(
      staffing: _staffing,
      externalCosts: _externalCosts,
      projectStart: projectStart,
      idealFinish: forecast.idealCompletion,
      forecastFinish: forecast.forecastCompletion,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFlagBanner(flags),
        const SizedBox(height: 24),
        _buildMilestonesCard(milestones),
        const SizedBox(height: 24),
        _buildForecastCard(forecast),
        const SizedBox(height: 24),
        _buildCostCard(cost),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _exportCalendar,
          icon: const Icon(Icons.calendar_month, size: 18),
          label: const Text('Export ceremonies calendar (.ics)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _kAccent,
            side: const BorderSide(color: _kAccent),
          ),
        ),
      ],
    );
  }

  Widget _buildFlagBanner(List<RedFlag> flags) {
    if (flags.isEmpty) {
      return _sectionCard('Red flags', [
        _line('No red flags: milestones, sprint capacity and stories are on track.',
            color: const Color(0xFF166534)),
      ]);
    }
    return _sectionCard('Red flags', [
      for (final flag in flags)
        _line(
          flag.message,
          color: flag.severity == RedFlagSeverity.critical
              ? const Color(0xFFB91C1C)
              : const Color(0xFF9A3412),
          bold: flag.severity == RedFlagSeverity.critical,
        ),
    ]);
  }

  Widget _buildMilestonesCard(List<ReleaseMilestoneStatus> milestones) {
    if (milestones.isEmpty) {
      return _sectionCard('Release milestones', [
        _line('No releases yet. Add releases in the Agile Release Plan to see '
            'which epics and features each milestone needs.'),
      ]);
    }
    return _sectionCard('Release milestones', [
      for (final m in milestones) ...[
        _line(
            '${m.release.releaseLabel.isNotEmpty ? m.release.releaseLabel : 'Release'}'
            '  ·  release date ${_fmtDate(m.release.releaseDate)}',
            bold: true),
        _line('${m.stories.length} stories · ${m.totalPoints} pts · '
            '${m.epicIds.length} epics · ${m.featureIds.length} features'),
        _line('Features: ${_featureNames(m.featureIds)}'),
        _line('Plan completes: ${_fmtDate(m.plannedCompletion)}'),
        const SizedBox(height: 8),
      ],
    ]);
  }

  String _featureNames(List<String> ids) {
    final names = _features
        .where((f) => ids.contains(f.id))
        .map((f) => f.title.isNotEmpty ? f.title : '(untitled)')
        .toList();
    return names.isEmpty ? 'none yet' : names.join(', ');
  }

  Widget _buildForecastCard(VelocityForecast f) {
    final variance = f.varianceDays;
    final String varianceText;
    final Color varianceColor;
    if (variance == null) {
      varianceText = 'Variance: needs planned stories and a velocity.';
      varianceColor = _kMuted;
    } else if (variance > 0) {
      varianceText = 'Forecast is $variance day${variance == 1 ? '' : 's'} '
          'later than the ideal date.';
      varianceColor = const Color(0xFFB91C1C);
    } else if (variance < 0) {
      varianceText = 'Forecast is ${-variance} day'
          '${variance == -1 ? '' : 's'} ahead of the ideal date.';
      varianceColor = const Color(0xFF166534);
    } else {
      varianceText = 'Forecast is on the ideal date.';
      varianceColor = const Color(0xFF166534);
    }
    return _sectionCard('Schedule forecast', [
      _line('Velocity: ${f.velocity.toStringAsFixed(1)} pts per sprint '
          '(${f.velocityIsObserved ? 'observed' : 'planned capacity, no sprint finished yet'})'),
      _line('Remaining: ${f.remainingPoints} of ${f.totalPoints} pts'),
      _line('Ideal completion (plan): ${_fmtDate(f.idealCompletion)}'),
      _line('Forecast completion (at current velocity): '
          '${_fmtDate(f.forecastCompletion)}'),
      _line(varianceText, color: varianceColor, bold: true),
    ]);
  }

  Widget _buildCostCard(AgileCostSummary c) {
    return _sectionCard('Agile cost', [
      _line('Team burn: ${_moneyFormat.format(c.monthlyBurn)} per month'),
      _line('Labour (plan): ${_moneyFormat.format(c.plannedLabor)}'),
      _line('Labour (forecast schedule): ${_moneyFormat.format(c.forecastLabor)}'),
      _line(
        c.scheduleDeltaLabor > 0
            ? 'Schedule elongation adds ${_moneyFormat.format(c.scheduleDeltaLabor)} of labour.'
            : 'No labour change from the schedule.',
        color: c.scheduleDeltaLabor > 0 ? const Color(0xFFB91C1C) : _kMuted,
      ),
      const SizedBox(height: 8),
      const Text('External costs (contracts, purchases, SSHER)',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      for (var i = 0; i < _externalCosts.length; i++)
        Row(
          children: [
            Expanded(
              child: Text(
                '${_externalCosts[i].name} (${_externalCosts[i].category})',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Text(_moneyFormat.format(_externalCosts[i].amount),
                style: const TextStyle(fontSize: 13)),
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
              onPressed: () => _removeExternalCost(i),
            ),
          ],
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _addExternalCost,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add external cost'),
        ),
      ),
      const SizedBox(height: 4),
      _line('Total cost: ${_moneyFormat.format(c.totalCost)}', bold: true),
    ]);
  }

  void _updateCeremony(AgileCeremony ceremony, AgileCeremonyEntry entry) {
    setState(() => _ceremonies[ceremony] = entry);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _saveCeremonies);
  }

  static String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours h' : '$hours h $rest min';
  }

  /// Downloads the sprints, recurring ceremonies, and release dates as an
  /// iCalendar file, so the team's own calendar shows the cadence and milestones.
  void _exportCeremoniesIcs() {
    final milestones = [
      for (final release in _releases)
        if (release.releaseDate != null)
          MapEntry(
            release.releaseLabel.trim().isEmpty
                ? 'Release'
                : release.releaseLabel.trim(),
            release.releaseDate!,
          ),
    ];
    final ics = buildCeremonyIcs(
      sprints: _sprints,
      ceremonies: _ceremonies,
      stamp: DateTime.now(),
      releaseMilestones: milestones,
    );
    downloadFile(
      utf8.encode(ics),
      'agile_ceremonies.ics',
      mimeType: 'text/calendar',
    );
  }

  Widget _buildCeremonySection() {
    final plan =
        planCeremonySchedule(entries: _ceremonies, sprintDays: _sprintDays);
    final weeks = (_sprintDays / 7).round().clamp(1, 1000);
    final sprintHours = plan.totalSprintMinutes / 60;
    final weeklyHours = sprintHours / weeks;
    final groomingCoverage = _groomingCoverage();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ceremony Schedule',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: _kHeadline)),
          const SizedBox(height: 4),
          Text(
            'Pick the recurring days and session length for each ceremony. '
            'Limits follow the agile delivery model. Sprint length: $weeks week(s).',
            style: const TextStyle(fontSize: 13, color: _kMuted),
          ),
          const SizedBox(height: 12),
          for (final rule in AgileCeremonyRules.all)
            _buildCeremonyRow(rule, plan, grooming: groomingCoverage),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: plan.isValid
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: plan.isValid
                    ? const Color(0xFF86EFAC)
                    : const Color(0xFFF59E0B),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ceremony time: ${sprintHours.toStringAsFixed(1)} h per sprint · '
                  '${weeklyHours.toStringAsFixed(1)} h per week',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline),
                ),
                const SizedBox(height: 6),
                if (plan.isValid)
                  const Text(
                    'All ceremonies are within the agile delivery limits.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF166534)),
                  )
                else
                  ...plan.warnings.map((w) => Text(
                        '• $w',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9A3412)),
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCeremonyRow(
    AgileCeremonyRule rule,
    AgileCeremonyPlan plan, {
    GroomingCoverage? grooming,
  }) {
    final entry = _ceremonies[rule.ceremony] ?? const AgileCeremonyEntry();
    final maxMinutes = AgileCeremonyRules.maxMinutesFor(rule, _sprintDays);
    final options = <int>{
      for (var m = rule.minMinutes; m <= maxMinutes; m += 15) m,
      if (entry.durationMinutes > 0) entry.durationMinutes,
    }.toList()
      ..sort();
    final fixedDuration = rule.minMinutes == rule.maxMinutes;
    final sprintMinutes = plan.sprintMinutes[rule.ceremony] ?? 0;
    const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(rule.label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kHeadline)),
              ),
              if (rule.optional) ...[
                const Text('Include',
                    style: TextStyle(fontSize: 12, color: _kMuted)),
                Switch(
                  value: entry.enabled,
                  activeThumbColor: _kAccent,
                  onChanged: (v) =>
                      _updateCeremony(rule.ceremony, entry.copyWith(enabled: v)),
                ),
              ],
            ],
          ),
          Text(rule.purpose,
              style: const TextStyle(fontSize: 12, color: _kMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                FilterChip(
                  label: Text(weekdayLabels[day - 1]),
                  selected: entry.weekdays.contains(day),
                  selectedColor: const Color(0xFFFFC812),
                  onSelected: entry.enabled
                      ? (on) {
                          final days = {...entry.weekdays};
                          if (on) {
                            days.add(day);
                          } else {
                            days.remove(day);
                          }
                          _updateCeremony(
                              rule.ceremony, entry.copyWith(weekdays: days));
                        }
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Duration per session:',
                  style: TextStyle(fontSize: 12, color: _kHeadline)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                isDense: true,
                value: options.contains(entry.durationMinutes)
                    ? entry.durationMinutes
                    : null,
                items: [
                  for (final m in options)
                    DropdownMenuItem(
                      value: m,
                      child: Text(_formatMinutes(m),
                          style: const TextStyle(fontSize: 12)),
                    ),
                ],
                onChanged: entry.enabled && !fixedDuration
                    ? (v) {
                        if (v != null) {
                          _updateCeremony(rule.ceremony,
                              entry.copyWith(durationMinutes: v));
                        }
                      }
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.enabled
                      ? '≈ ${(sprintMinutes / 60).toStringAsFixed(1)} h per sprint'
                      : 'Not scheduled',
                  style: const TextStyle(fontSize: 12, color: _kMuted),
                ),
              ),
            ],
          ),
          if (rule.ceremony == AgileCeremony.backlogGrooming &&
              grooming != null &&
              entry.enabled) ...[
            const SizedBox(height: 8),
            _buildGroomingCoverage(grooming),
          ],
        ],
      ),
    );
  }

  /// Groomed-backlog depth from the stories on the page: the delivery model
  /// wants at least two sprints of stories at 'Ready for Sprint', about twice
  /// the team's velocity, and a third grooming day when the backlog is short.
  GroomingCoverage _groomingCoverage() {
    final groomedPoints = _storyCache
        .where((s) => s.readinessStatus == 'Ready for Sprint' &&
            s.status.trim().toLowerCase() != 'done')
        .fold<int>(0, (sum, s) => sum + s.storyPoints);
    final velocity = buildVelocityForecast(
      stories: _storyCache,
      sprints: _sprints,
      today: DateTime.now(),
    ).velocity;
    return GroomingCoverage(
      groomedPoints: groomedPoints,
      velocityPerSprint: velocity,
      groomingDaysPerWeek:
          _ceremonies[AgileCeremony.backlogGrooming]?.weekdays.length ?? 0,
    );
  }

  /// Two-sprint cover line plus the "groom 3 times a week" action the delivery
  /// model calls for when the groomed backlog is too shallow.
  Widget _buildGroomingCoverage(GroomingCoverage g) {
    final sprints = g.sprintsGroomed;
    if (sprints == null) {
      return const Text(
        'Sprints of cover: set sprint capacity (or finish a sprint) to compare '
        'the groomed backlog with two sprints of velocity.',
        style: TextStyle(fontSize: 12, color: _kMuted),
      );
    }
    final ok = g.coversTwoSprints;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ok
              ? 'Sprints of cover: ${sprints.toStringAsFixed(1)} of groomed work '
                  '(target 2).'
              : 'Sprints of cover: only ${sprints.toStringAsFixed(1)} — groom '
                  'toward 2 sprints (about twice velocity, ${g.targetPoints} pts).',
          style: TextStyle(
            fontSize: 12,
            color: ok ? const Color(0xFF166534) : const Color(0xFF9A3412),
          ),
        ),
        if (g.needsThirdDay)
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Groom 3 times a week until two sprints are covered.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9A3412)),
                ),
              ),
              TextButton(
                onPressed: _useThreeGroomingDays,
                child: const Text('Use 3 days a week'),
              ),
            ],
          ),
      ],
    );
  }

  /// Sets grooming to three weekdays (Mon/Wed/Fri) in one click.
  void _useThreeGroomingDays() {
    final entry = _ceremonies[AgileCeremony.backlogGrooming];
    if (entry == null) return;
    _updateCeremony(
      AgileCeremony.backlogGrooming,
      entry.copyWith(
        weekdays: {DateTime.monday, DateTime.wednesday, DateTime.friday},
      ),
    );
  }

  Widget _buildCapacitySummary() {
    final overloaded = _sprints.where((s) {
      final available = (s.capacityPoints * s.focusFactor).round();
      final planned = _plannedPointsForSprint(s.id);
      return available > 0 && planned > available;
    }).toList();
    final assignedStories =
        _storyCache.where((s) => s.plannedSprintId.isNotEmpty).length;
    final unassignedStories =
        _storyCache.where((s) => s.plannedSprintId.isEmpty).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: overloaded.isNotEmpty
            ? const Color(0xFFFFF7ED)
            : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: overloaded.isNotEmpty
              ? const Color(0xFFF59E0B)
              : const Color(0xFF86EFAC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            overloaded.isNotEmpty
                ? 'Capacity warning: ${overloaded.length} sprint(s) are over planned capacity.'
                : 'Sprint allocation looks healthy across configured capacity.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: overloaded.isNotEmpty
                  ? const Color(0xFF9A3412)
                  : const Color(0xFF166534),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Assigned stories: $assignedStories · Unassigned stories: $unassignedStories. Use this page to confirm capacity before importing agile stories into the schedule.',
            style: const TextStyle(fontSize: 12, color: _kMuted, height: 1.5),
          ),
        ],
      ),
    );
  }

  Future<void> _assignFeaturesToSprint() async {
    if (_sprints.isEmpty || _features.isEmpty) return;
    final pid = _projectId;
    if (pid == null) return;

    final sprint = _sprints.first;
    final assigned = _features.where((f) => f.sprintId == sprint.id).toList();
    final unassigned = _features.where((f) => f.sprintId != sprint.id).toList();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => _AssignFeaturesDialog(
        sprintName:
            sprint.name.isNotEmpty ? sprint.name : 'Sprint ${sprint.order}',
        unassigned: List<Feature>.from(unassigned),
        assigned: List<Feature>.from(assigned),
        onAssign: (feature) async {
          await EpicFeatureService.assignFeatureToSprint(
            projectId: pid,
            feature: feature,
            sprintId: sprint.id,
          );
          setState(() => feature.sprintId = sprint.id);
        },
        onUnassign: (feature) async {
          await EpicFeatureService.assignFeatureToSprint(
            projectId: pid,
            feature: feature,
            sprintId: null,
          );
          setState(() => feature.sprintId = null);
        },
      ),
    );
  }

  int _plannedPointsForSprint(String sprintId) {
    final pid = _projectId;
    if (pid == null || _storyCacheProjectId != pid) return 0;
    return _storyCache
        .where((story) => story.plannedSprintId == sprintId)
        .fold<int>(0, (sum, story) => sum + story.storyPoints);
  }

  Widget _buildSprintCard(int index, RoadmapSprint sprint) {
    final startStr = sprint.startDate != null
        ? _dateFormat.format(sprint.startDate!)
        : 'TBD';
    final endStr =
        sprint.endDate != null ? _dateFormat.format(sprint.endDate!) : 'TBD';
    final plannedPoints = _plannedPointsForSprint(sprint.id);
    final capacity = sprint.capacityPoints;
    final availableCapacity = (capacity * sprint.focusFactor).round();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: _kBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _kAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text('${sprint.order}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: _kAccent)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      sprint.name.isNotEmpty
                          ? sprint.name
                          : 'Sprint ${sprint.order}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('$startStr – $endStr',
                      style: const TextStyle(fontSize: 12, color: _kMuted)),
                  const SizedBox(height: 2),
                  Text(
                    'Capacity $availableCapacity pts · Planned $plannedPoints pts${sprint.squadName.isNotEmpty ? ' · ${sprint.squadName}' : ''}',
                    style: TextStyle(
                        fontSize: 12,
                        color: plannedPoints > availableCapacity &&
                                availableCapacity > 0
                            ? Colors.red[700]
                            : _kMuted),
                  ),
                  if (sprint.goal.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(sprint.goal,
                          style: const TextStyle(fontSize: 12, color: _kMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _editSprint(index);
                if (v == 'delete') _deleteSprint(index);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child:
            Text(message, style: const TextStyle(color: _kMuted, fontSize: 15)),
      ),
    );
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Agile Sprint Calendar',
      sections: [
        PdfSection.keyValue('Project Info', [
          {'Project Name': projectData.projectName},
          {'Solution Title': projectData.solutionTitle},
        ]),
        PdfSection.text(
            'Notes',
            projectData.planningNotes['planning_agile_sprint_calendar_notes'] ??
                'No data recorded.'),
      ],
    );
  }
}

class _AssignFeaturesDialog extends StatefulWidget {
  final String sprintName;
  final List<Feature> unassigned;
  final List<Feature> assigned;
  final ValueChanged<Feature> onAssign;
  final ValueChanged<Feature> onUnassign;

  const _AssignFeaturesDialog({
    required this.sprintName,
    required this.unassigned,
    required this.assigned,
    required this.onAssign,
    required this.onUnassign,
  });

  @override
  State<_AssignFeaturesDialog> createState() => _AssignFeaturesDialogState();
}

class _AssignFeaturesDialogState extends State<_AssignFeaturesDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Features for ${widget.sprintName}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.assigned.isNotEmpty) ...[
              const Text('Assigned to this sprint',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kHeadline)),
              const SizedBox(height: 8),
              ...widget.assigned
                  .map((feature) => _buildFeatureTile(feature, true)),
              const Divider(height: 24),
            ],
            if (widget.unassigned.isNotEmpty) ...[
              const Text('Unassigned features',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kHeadline)),
              const SizedBox(height: 8),
              ...widget.unassigned
                  .map((feature) => _buildFeatureTile(feature, false)),
            ],
            if (widget.unassigned.isEmpty && widget.assigned.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                    'No features found. Create features in Epics & Features first.'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildFeatureTile(Feature feature, bool isAssigned) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            isAssigned ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: isAssigned ? Colors.green : _kMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              feature.title.isNotEmpty ? feature.title : '(untitled)',
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${feature.storyPointEstimate.toStringAsFixed(0)} pts',
            style: const TextStyle(fontSize: 11, color: _kMuted),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 28,
            child: TextButton(
              onPressed: () {
                if (isAssigned) {
                  widget.onUnassign(feature);
                } else {
                  widget.onAssign(feature);
                }
                setState(() {});
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                isAssigned ? 'Remove' : 'Assign',
                style: TextStyle(
                  fontSize: 11,
                  color: isAssigned ? Colors.red : const Color(0xFF059669),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SprintEditDialog extends StatefulWidget {
  final RoadmapSprint? existing;
  final ValueChanged<RoadmapSprint> onSave;

  const _SprintEditDialog({this.existing, required this.onSave});

  @override
  State<_SprintEditDialog> createState() => _SprintEditDialogState();
}

class _SprintEditDialogState extends State<_SprintEditDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _goalCtrl;
  late TextEditingController _orderCtrl;
  late TextEditingController _capacityCtrl;
  late TextEditingController _focusCtrl;
  late TextEditingController _squadCtrl;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = SpellCheckTextEditingController(text: e?.name ?? '');
    _goalCtrl = SpellCheckTextEditingController(text: e?.goal ?? '');
    _orderCtrl =
        SpellCheckTextEditingController(text: (e?.order ?? _nextOrder()).toString());
    _capacityCtrl =
        SpellCheckTextEditingController(text: (e?.capacityPoints ?? 0).toString());
    _focusCtrl = SpellCheckTextEditingController(text: (e?.focusFactor ?? 1).toString());
    _squadCtrl = SpellCheckTextEditingController(text: e?.squadName ?? '');
    _startDate = e?.startDate;
    _endDate = e?.endDate;
  }

  int _nextOrder() {
    return (widget.existing?.order ?? 0) + 1;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _goalCtrl.dispose();
    _orderCtrl.dispose();
    _capacityCtrl.dispose();
    _focusCtrl.dispose();
    _squadCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat df = DateFormat('MMM dd, yyyy');
    return AlertDialog(
      title: Text(widget.existing != null ? 'Edit Sprint' : 'Add Sprint'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VoiceTextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Sprint Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            VoiceTextField(
              controller: _orderCtrl,
              decoration: const InputDecoration(
                  labelText: 'Sprint #', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _startDate = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Start Date', border: OutlineInputBorder()),
                child: Text(_startDate != null
                    ? df.format(_startDate!)
                    : 'Select date'),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _endDate = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'End Date', border: OutlineInputBorder()),
                child: Text(
                    _endDate != null ? df.format(_endDate!) : 'Select date'),
              ),
            ),
            const SizedBox(height: 12),
            VoiceTextField(
              controller: _goalCtrl,
              decoration: const InputDecoration(
                  labelText: 'Sprint Goal', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            VoiceTextField(
              controller: _capacityCtrl,
              decoration: const InputDecoration(
                  labelText: 'Capacity (story points)',
                  border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            VoiceTextField(
              controller: _focusCtrl,
              decoration: const InputDecoration(
                  labelText: 'Focus Factor (0-1)',
                  border: OutlineInputBorder()),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            VoiceTextField(
              controller: _squadCtrl,
              decoration: const InputDecoration(
                  labelText: 'Squad / Team Name', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final sprint = RoadmapSprint(
              id: widget.existing?.id,
              name: _nameCtrl.text,
              order: int.tryParse(_orderCtrl.text) ?? 0,
              startDate: _startDate,
              endDate: _endDate,
              goal: _goalCtrl.text,
              capacityPoints: int.tryParse(_capacityCtrl.text) ?? 0,
              focusFactor: double.tryParse(_focusCtrl.text) ?? 1,
              squadName: _squadCtrl.text,
            );
            widget.onSave(sprint);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
