import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// AGILE DAILY STANDUPS — Yesterday / Today / Blockers Screen
/// ═══════════════════════════════════════════════════════════════════════════
class AgileDailyStandupsScreen extends StatefulWidget {
  const AgileDailyStandupsScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AgileDailyStandupsScreen()),
    );
  }

  @override
  State<AgileDailyStandupsScreen> createState() =>
      _AgileDailyStandupsScreenState();
}

class _AgileDailyStandupsScreenState extends State<AgileDailyStandupsScreen> {
  static const Color _kAccent = Color(0xFFF59E0B);
  static const Color _kAccentLight = Color(0xFFFFC812);
  static const Color _kAccentBg = Color(0xFFFEF3C7);
  static const Color _kBackground = Color(0xFFF8FAFC);
  static const Color _kSurface = Colors.white;
  static const Color _kBorder = Color(0xFFE5E7EB);
  static const Color _kHeadline = Color(0xFF111827);
  static const Color _kMuted = Color(0xFF6B7280);

  bool _isLoading = true;
  bool _isSaving = false;
  DateTime _selectedDay = DateTime.now();

  List<_StandupEntry> _entries = [];
  List<_CalendarDay> _calendar = [];
  final List<_ActionItem> _actionItems = [];

  String? get _projectId => ProjectDataHelper.getData(context).projectId;

  @override
  void initState() {
    super.initState();
    _calendar = _initCalendar();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  static List<_CalendarDay> _initCalendar() {
    final today = DateTime.now();
    return List.generate(10, (i) {
      final d = today.subtract(const Duration(days: 4)).add(Duration(days: i));
      final isToday = d.day == today.day &&
          d.month == today.month &&
          d.year == today.year;
      return _CalendarDay(
        date: d,
        isToday: isToday,
        hasStandup: !isToday || true,
        attendance: isToday
            ? 7
            : d.isBefore(today)
                ? (i % 3 == 0 ? 8 : 7)
                : 0,
      );
    });
  }

  Future<void> _loadData() async {
    final pid = _projectId;
    if (pid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(pid)
          .collection('execution_phase_entries')
          .doc('agile_daily_standups')
          .get();
      final data = doc.data() ?? {};
      final entries = (data['entries'] as List?)
              ?.map((e) => _StandupEntry.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [];
      final actions = (data['actionItems'] as List?)
              ?.map((e) => _ActionItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [];
      if (entries.isEmpty) _seedDemoData();
      if (mounted) {
        setState(() {
          if (entries.isNotEmpty) _entries = entries;
          if (actions.isNotEmpty) {
            _actionItems.clear();
            _actionItems.addAll(actions);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Standups load error: $e');
      _seedDemoData();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _seedDemoData() {
    _entries = [
      _StandupEntry(
        member: 'Sarah Chen',
        role: 'Tech Lead',
        avatar: 'SC',
        yesterday: 'Wrapped up login validation hardening (NDU-1042). Reviewed Marcus\'s PR for rate-limiting scaffolding.',
        today: 'Pair with Lena on reporting module data layer. Start NDU-1047 audit log stub.',
        blockers: 'Waiting on DevOps to provision staging Redis instance.',
        mood: 'positive',
        color: Colors.green,
      ),
      _StandupEntry(
        member: 'Marcus Reed',
        role: 'Backend Engineer',
        avatar: 'MR',
        yesterday: 'Moved NDU-1038 (rate limiting) to In Review. Pair-debugged Priya\'s KPI card.',
        today: 'Finalize rate-limiting review. Start NDU-1055 dashboard drag-drop.',
        blockers: '',
        mood: 'positive',
        color: Colors.blue,
      ),
      _StandupEntry(
        member: 'Priya Nair',
        role: 'Frontend Engineer',
        avatar: 'PN',
        yesterday: 'Completed KPI card component (NDU-1031) and pushed for review.',
        today: 'Wire KPI card into dashboard. Address review feedback on NDU-1031.',
        blockers: 'Figma tokens for dark mode not finalized — blocking NDU-1046.',
        mood: 'neutral',
        color: Colors.purple,
      ),
      _StandupEntry(
        member: 'James Okoro',
        role: 'Frontend Engineer',
        avatar: 'JO',
        yesterday: 'Started NDU-1046 (dark mode tokens). Pushed initial branch.',
        today: 'Continue dark mode tokens. Help Lena with onboarding tour.',
        blockers: '',
        mood: 'positive',
        color: Colors.orange,
      ),
      _StandupEntry(
        member: 'Lena Park',
        role: 'Frontend Engineer',
        avatar: 'LP',
        yesterday: 'Started reporting module data layer (NDU-1045). Drafted onboarding tour plan.',
        today: 'Finish reporting DTOs. Begin onboarding tour (NDU-1050).',
        blockers: '',
        mood: 'positive',
        color: Colors.teal,
      ),
      _StandupEntry(
        member: 'Kaz AI',
        role: 'AI Coach',
        avatar: 'AI',
        yesterday: 'Detected velocity drift of -8% on Sprint 24. Suggested scope negotiation.',
        today: 'Monitoring daily progress. Will flag if cycle time exceeds 3 days.',
        blockers: '',
        mood: 'info',
        color: _kAccent,
      ),
    ];
    _actionItems.clear();
    _actionItems.addAll([
      _ActionItem(
          id: 'AI-201',
          description: 'Provision staging Redis instance for Sarah',
          owner: 'DevOps Team',
          due: 'Today',
          status: 'Open',
          priority: 'High'),
      _ActionItem(
          id: 'AI-202',
          description: 'Finalize Figma dark mode tokens for Priya',
          owner: 'Design Team',
          due: 'Tomorrow',
          status: 'In Progress',
          priority: 'Medium'),
      _ActionItem(
          id: 'AI-203',
          description: 'Schedule NDU-1047 audit log kickoff',
          owner: 'Sarah Chen',
          due: 'Today',
          status: 'Open',
          priority: 'Medium'),
      _ActionItem(
          id: 'AI-204',
          description: 'Send stakeholder preview of reporting module',
          owner: 'Lena Park',
          due: 'Fri',
          status: 'Done',
          priority: 'Low'),
    ]);
  }

  Future<void> _saveData() async {
    final pid = _projectId;
    if (pid == null) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(pid)
          .collection('execution_phase_entries')
          .doc('agile_daily_standups')
          .set({
        'entries': _entries.map((e) => e.toMap()).toList(),
        'actionItems': _actionItems.map((a) => a.toMap()).toList(),
        'selectedDay': _selectedDay.toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Standup data saved'),
            backgroundColor: _kAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Standups save error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toggleActionItem(_ActionItem item) {
    setState(() {
      final idx = _actionItems.indexWhere((a) => a.id == item.id);
      if (idx >= 0) {
        final newStatus = item.status == 'Done' ? 'Open' : 'Done';
        _actionItems[idx] = _ActionItem(
          id: item.id,
          description: item.description,
          owner: item.owner,
          due: item.due,
          status: newStatus,
          priority: item.priority,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = AppBreakpoints.isMobile(context);
    final double hp = isMobile ? 16 : 32;

    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: const InitiationLikeSidebar(
                  activeItemLabel: 'Agile Daily Standups'),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                      activeItemLabel: 'Agile Daily Standups',
                    ),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                        horizontal: hp, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopBar(),
                        const SizedBox(height: 20),
                        PlanningPhaseHeader(
                          title: 'Daily Standups',
                          showNavigationButtons: false,
                          breadcrumbPhase: 'Execution',
                          breadcrumbTitle: 'Agile Hub › Daily Standups',
                        ),
                        const SizedBox(height: 24),
                        if (_isLoading)
                          const _LoadingStrip()
                        else ...[
                          _buildSummaryRow(),
                          const SizedBox(height: 20),
                          _buildCalendar(),
                          const SizedBox(height: 24),
                          _buildTeamSection(isMobile),
                          const SizedBox(height: 24),
                          _buildActionItemsTable(),
                          const SizedBox(height: 24),
                          _buildActionBar(),
                          const SizedBox(height: 64),
                        ],
                      ],
                    ),
                  ),
                  const Positioned(
                    right: 24,
                    bottom: 24,
                    child: KazAiChatBubble(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Image.asset('assets/images/Logo.png', height: 36),
        const SizedBox(width: 12),
        const Text('Ndu Project',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _kHeadline)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _kAccentBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kAccent.withOpacity(0.3)),
          ),
          child: const Text('DAILY 9:30 AM',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kAccent,
                  letterSpacing: 1.1)),
        ),
      ],
    );
  }

  Widget _buildSummaryRow() {
    final blockers =
        _entries.where((e) => e.blockers.isNotEmpty).length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kAccent, _kAccentLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryCell('Attendance', '${_entries.length}/8',
                Icons.groups),
          ),
          Container(
              width: 1,
              height: 36,
              color: Colors.white.withOpacity(0.3)),
          Expanded(
            child:
                _summaryCell('Blockers', '$blockers', Icons.warning_amber),
          ),
          Container(
              width: 1,
              height: 36,
              color: Colors.white.withOpacity(0.3)),
          Expanded(
            child: _summaryCell('Action Items', '${_actionItems.length}',
                Icons.assignment_outlined),
          ),
          Container(
              width: 1,
              height: 36,
              color: Colors.white.withOpacity(0.3)),
          Expanded(
            child: _summaryCell(
                'Duration', '14 min', Icons.timer_outlined),
          ),
        ],
      ),
    );
  }

  Widget _summaryCell(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.85),
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildCalendar() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 18, color: _kAccent),
              const SizedBox(width: 8),
              const Text('Standup Calendar',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Schedule'),
                style: TextButton.styleFrom(foregroundColor: _kAccent),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _calendar.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final d = _calendar[i];
                final selected = d.date.day == _selectedDay.day &&
                    d.date.month == _selectedDay.month;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDay = d.date),
                  child: Container(
                    width: 64,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? _kAccent
                          : d.isToday
                              ? _kAccentBg
                              : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? _kAccent
                            : d.isToday
                                ? _kAccent.withOpacity(0.3)
                                : _kBorder,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.date.weekday - 1],
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white.withOpacity(0.85)
                                  : _kMuted),
                        ),
                        const SizedBox(height: 4),
                        Text('${d.date.day}',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: selected
                                    ? Colors.white
                                    : _kHeadline)),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              d.attendance > 0
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 10,
                              color: selected
                                  ? Colors.white
                                  : d.attendance > 0
                                      ? Colors.green
                                      : _kMuted,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              d.attendance > 0 ? '${d.attendance}' : '-',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: selected
                                      ? Colors.white
                                      : _kMuted,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamSection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.groups_outlined, size: 20, color: _kAccent),
            const SizedBox(width: 8),
            const Text('Team Standup Updates',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _kHeadline)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kAccentBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kAccent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: _entries
              .map((e) => ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: isMobile
                            ? double.infinity
                            : (MediaQuery.of(context).size.width - 480) / 2),
                    child: _buildStandupCard(e),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildStandupCard(_StandupEntry e) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: e.color.withOpacity(0.15),
                child: Text(e.avatar,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: e.color)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(e.member,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _kHeadline)),
                        const SizedBox(width: 6),
                        _moodChip(e.mood),
                      ],
                    ),
                    Text(e.role,
                        style: const TextStyle(
                            fontSize: 11, color: _kMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _standupSection('Yesterday', e.yesterday, Icons.history,
              const Color(0xFF3B82F6)),
          const SizedBox(height: 8),
          _standupSection('Today', e.today, Icons.today, _kAccent),
          const SizedBox(height: 8),
          _standupSection(
              'Blockers',
              e.blockers.isEmpty ? 'No blockers' : e.blockers,
              Icons.block,
              e.blockers.isEmpty ? Colors.green : Colors.red,
              empty: e.blockers.isEmpty),
        ],
      ),
    );
  }

  Widget _moodChip(String mood) {
    final map = {
      'positive': (Colors.green, Icons.sentiment_satisfied, 'Good'),
      'neutral': (Colors.amber, Icons.sentiment_neutral, 'Neutral'),
      'negative': (Colors.red, Icons.sentiment_dissatisfied, 'Stressed'),
      'info': (_kAccent, Icons.auto_awesome, 'AI'),
    };
    final entry = map[mood] ?? map['neutral']!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: entry.$1.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(entry.$2, size: 10, color: entry.$1),
          const SizedBox(width: 2),
          Text(entry.$3,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: entry.$1)),
        ],
      ),
    );
  }

  Widget _standupSection(
      String label, String content, IconData icon, Color color,
      {bool empty = false}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: color, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                      letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: 4),
          Text(content,
              style: TextStyle(
                  fontSize: 12,
                  color: empty ? _kMuted : _kHeadline,
                  height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildActionItemsTable() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_outlined,
                  size: 20, color: _kAccent),
              const SizedBox(width: 8),
              const Text('Action Items',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              _actionItems.isEmpty
                  ? const SizedBox()
                  : Text(
                      '${_actionItems.where((a) => a.status == 'Done').length}/${_actionItems.length} done',
                      style: const TextStyle(
                          fontSize: 12, color: _kMuted)),
            ],
          ),
          const SizedBox(height: 12),
          _buildTableHeader(),
          const Divider(height: 1, color: _kBorder),
          ..._actionItems.map((a) => _buildActionRow(a)),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: const [
          SizedBox(width: 30),
          Expanded(
              flex: 4,
              child: Text('Action Item',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kMuted,
                      letterSpacing: 0.5))),
          Expanded(
              flex: 2,
              child: Text('Owner',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kMuted,
                      letterSpacing: 0.5))),
          Expanded(
              flex: 1,
              child: Text('Due',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kMuted,
                      letterSpacing: 0.5))),
          Expanded(
              flex: 2,
              child: Text('Status',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kMuted,
                      letterSpacing: 0.5))),
        ],
      ),
    );
  }

  Widget _buildActionRow(_ActionItem a) {
    final done = a.status == 'Done';
    return InkWell(
      onTap: () => _toggleActionItem(a),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _kBorder, width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: done ? Colors.green : _kMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.description,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: done ? _kMuted : _kHeadline,
                          decoration:
                              done ? TextDecoration.lineThrough : null)),
                  Text(a.id,
                      style: const TextStyle(
                          fontSize: 10, color: _kMuted)),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(a.owner,
                  style: const TextStyle(
                      fontSize: 12, color: _kHeadline)),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(a.due,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _kAccent)),
              ),
            ),
            Expanded(
              flex: 2,
              child: _statusChip(a.status),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = status == 'Done'
        ? Colors.green
        : status == 'In Progress'
            ? Colors.blue
            : _kAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(status,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }

  Widget _buildActionBar() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveData,
          icon: _isSaving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_outlined, size: 16),
          label: Text(_isSaving ? 'Saving…' : 'Save Standup'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Refresh'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _kAccent,
            side: const BorderSide(color: _kAccent),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Helper models
// ═══════════════════════════════════════════════════════════════════════════
class _CalendarDay {
  final DateTime date;
  final bool isToday;
  final bool hasStandup;
  final int attendance;
  const _CalendarDay({
    required this.date,
    required this.isToday,
    required this.hasStandup,
    required this.attendance,
  });
}

class _StandupEntry {
  final String member;
  final String role;
  final String avatar;
  final String yesterday;
  final String today;
  final String blockers;
  final String mood;
  final Color color;

  const _StandupEntry({
    required this.member,
    required this.role,
    required this.avatar,
    required this.yesterday,
    required this.today,
    required this.blockers,
    required this.mood,
    required this.color,
  });

  Map<String, dynamic> toMap() => {
        'member': member,
        'role': role,
        'avatar': avatar,
        'yesterday': yesterday,
        'today': today,
        'blockers': blockers,
        'mood': mood,
        'color': color.toARGB32(),
      };

  factory _StandupEntry.fromMap(Map<String, dynamic> m) => _StandupEntry(
        member: m['member'] as String? ?? '',
        role: m['role'] as String? ?? '',
        avatar: m['avatar'] as String? ?? '',
        yesterday: m['yesterday'] as String? ?? '',
        today: m['today'] as String? ?? '',
        blockers: m['blockers'] as String? ?? '',
        mood: m['mood'] as String? ?? 'neutral',
        color: Color(m['color'] as int? ?? 0xFF6B7280),
      );
}

class _ActionItem {
  final String id;
  final String description;
  final String owner;
  final String due;
  final String status;
  final String priority;

  const _ActionItem({
    required this.id,
    required this.description,
    required this.owner,
    required this.due,
    required this.status,
    required this.priority,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'description': description,
        'owner': owner,
        'due': due,
        'status': status,
        'priority': priority,
      };

  factory _ActionItem.fromMap(Map<String, dynamic> m) => _ActionItem(
        id: m['id'] as String? ?? '',
        description: m['description'] as String? ?? '',
        owner: m['owner'] as String? ?? '',
        due: m['due'] as String? ?? '',
        status: m['status'] as String? ?? 'Open',
        priority: m['priority'] as String? ?? 'Medium',
      );
}

class _LoadingStrip extends StatelessWidget {
  const _LoadingStrip();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFF59E0B)),
            SizedBox(height: 16),
            Text('Loading daily standups…',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
