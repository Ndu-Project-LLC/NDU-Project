import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ndu_project/utils/agile_project_context_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// AGILE SPRINT REVIEWS — Completed Stories, Demos, Stakeholder Feedback
/// ═══════════════════════════════════════════════════════════════════════════
class AgileSprintReviewsScreen extends StatefulWidget {
  const AgileSprintReviewsScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AgileSprintReviewsScreen()),
    );
  }

  @override
  State<AgileSprintReviewsScreen> createState() =>
      _AgileSprintReviewsScreenState();
}

class _AgileSprintReviewsScreenState extends State<AgileSprintReviewsScreen> {
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
  String _currentSprint = 'Sprint 24';

  List<_CompletedStory> _stories = [];
  List<_DemoItem> _demoItems = [];
  final List<_StakeholderFeedback> _feedback = [];
  final List<_ReviewAction> _actions = [];

  String? get _projectId => ProjectDataHelper.getData(context).projectId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final pid = _projectId;
    final projectData = ProjectDataHelper.getData(context);
    if (pid == null) {
      _seedProjectData(projectData);
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(pid)
          .collection('execution_phase_entries')
          .doc('agile_sprint_reviews')
          .get();
      final data = doc.data() ?? {};
      final stories = (data['stories'] as List?)
              ?.map((e) => _CompletedStory.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [];
      final demos = (data['demoItems'] as List?)
              ?.map((e) => _DemoItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [];
      final feedback = (data['feedback'] as List?)
              ?.map((e) => _StakeholderFeedback.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [];
      final actions = (data['actions'] as List?)
              ?.map((e) => _ReviewAction.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [];
      if (stories.isEmpty) _seedProjectData(projectData);
      if (mounted) {
        setState(() {
          if (stories.isNotEmpty) _stories = stories;
          if (demos.isNotEmpty) _demoItems = demos;
          if (feedback.isNotEmpty) {
            _feedback.clear();
            _feedback.addAll(feedback);
          }
          if (actions.isNotEmpty) {
            _actions.clear();
            _actions.addAll(actions);
          }
          _currentSprint = data['currentSprint'] as String? ?? _currentSprint;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Sprint reviews load error: $e');
      _seedProjectData(projectData);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _seedProjectData(dynamic projectData) {
    final workItems = AgileProjectContextHelper.workItems(projectData, limit: 8);
    final stakeholders =
        AgileProjectContextHelper.stakeholders(projectData, limit: 4);
    final issues = AgileProjectContextHelper.issues(projectData, limit: 4);
    final sprintLabel = AgileProjectContextHelper.activeSprintLabel(projectData);

    _currentSprint = sprintLabel;
    _stories = [
      for (final item in workItems)
        _CompletedStory(
          id: item.id,
          title: item.title,
          points: AgileProjectContextHelper.estimateStoryPoints(item.title),
          assignee: item.owner.isEmpty ? 'Project Team' : item.owner,
          status: item.status == 'Blocked' ? 'Rejected' : 'Accepted',
          value: item.priority,
        ),
    ];
    _demoItems = [
      for (final item in workItems.take(6))
        _DemoItem(
          id: 'D-${item.id}',
          title: item.title,
          owner: item.owner.isEmpty ? 'Project Team' : item.owner,
          status: item.status == 'Done' ? 'Demoed' : 'Ready',
          notes: item.description,
        ),
    ];
    _feedback
      ..clear()
      ..addAll([
        for (final stakeholder in stakeholders)
          _StakeholderFeedback(
            stakeholder: stakeholder.name,
            role: stakeholder.role,
            rating: stakeholder.sentiment == 'positive' ? 5 : 4,
            comment: stakeholder.notes.isEmpty
                ? 'This increment should stay aligned to the broader project objective and stakeholder expectations.'
                : stakeholder.notes,
            sentiment: stakeholder.sentiment,
          ),
      ]);
    _actions
      ..clear()
      ..addAll([
        for (final issue in issues)
          _ReviewAction(
            id: 'ACT-${issue.id}',
            description: issue.title,
            owner: issue.owner.isEmpty ? 'Project Team' : issue.owner,
            due: issue.due.isEmpty ? 'Next Sprint' : issue.due,
            status: issue.status == 'Done' ? 'Done' : 'Open',
            priority: issue.severity,
          ),
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
          .doc('agile_sprint_reviews')
          .set({
        'currentSprint': _currentSprint,
        'stories': _stories.map((s) => s.toMap()).toList(),
        'demoItems': _demoItems.map((d) => d.toMap()).toList(),
        'feedback': _feedback.map((f) => f.toMap()).toList(),
        'actions': _actions.map((a) => a.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Sprint review saved'),
            backgroundColor: _kAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Sprint reviews save error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toggleDemoItem(_DemoItem item) {
    setState(() {
      final idx = _demoItems.indexWhere((d) => d.id == item.id);
      if (idx >= 0) {
        final newStatus = item.status == 'Ready' ? 'Demoed' : 'Ready';
        _demoItems[idx] = _DemoItem(
          id: item.id,
          title: item.title,
          owner: item.owner,
          status: newStatus,
          notes: item.notes,
        );
      }
    });
  }

  void _toggleAction(_ReviewAction a) {
    setState(() {
      final idx = _actions.indexWhere((x) => x.id == a.id);
      if (idx >= 0) {
        final newStatus = a.status == 'Done' ? 'Open' : 'Done';
        _actions[idx] = _ReviewAction(
          id: a.id,
          description: a.description,
          owner: a.owner,
          due: a.due,
          status: newStatus,
          priority: a.priority,
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
                  activeItemLabel: 'Agile Sprint Reviews'),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                      activeItemLabel: 'Agile Sprint Reviews',
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
                          title: 'Sprint Reviews',
                          showNavigationButtons: false,
                          breadcrumbPhase: 'Execution',
                          breadcrumbTitle: 'Agile Hub › Sprint Reviews',
                        ),
                        const SizedBox(height: 24),
                        if (_isLoading)
                          const _LoadingStrip()
                        else ...[
                          _buildSummaryRow(),
                          const SizedBox(height: 24),
                          _buildCompletedStoriesTable(),
                          const SizedBox(height: 24),
                          if (!isMobile)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildDemoChecklist()),
                                const SizedBox(width: 24),
                                Expanded(child: _buildFeedbackSection()),
                              ],
                            )
                          else ...[
                            _buildDemoChecklist(),
                            const SizedBox(height: 24),
                            _buildFeedbackSection(),
                          ],
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
          child: Text('$_currentSprint REVIEW',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kAccent,
                  letterSpacing: 1.1)),
        ),
      ],
    );
  }

  Widget _buildSummaryRow() {
    final accepted =
        _stories.where((s) => s.status == 'Accepted').length;
    final rejected =
        _stories.where((s) => s.status == 'Rejected').length;
    final pointsDelivered = _stories
        .where((s) => s.status == 'Accepted')
        .fold<int>(0, (a, s) => a + s.points);
    final avgRating = _feedback.isEmpty
        ? 0.0
        : _feedback.map((f) => f.rating).reduce((a, b) => a + b) /
            _feedback.length;
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
              child:
                  _summaryCell('Accepted', '$accepted', Icons.check_circle)),
          Container(
              width: 1, height: 36, color: Colors.white.withOpacity(0.3)),
          Expanded(
              child: _summaryCell('Rejected', '$rejected', Icons.cancel)),
          Container(
              width: 1, height: 36, color: Colors.white.withOpacity(0.3)),
          Expanded(
              child: _summaryCell(
                  'Points', '$pointsDelivered', Icons.stars)),
          Container(
              width: 1, height: 36, color: Colors.white.withOpacity(0.3)),
          Expanded(
              child: _summaryCell(
                  'Stakeholder', avgRating.toStringAsFixed(1), Icons.star)),
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

  Widget _buildCompletedStoriesTable() {
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
              const Icon(Icons.task_alt, size: 20, color: _kAccent),
              const SizedBox(width: 8),
              Text('Completed Stories — $_currentSprint',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
            ],
          ),
          const SizedBox(height: 12),
          _buildStoriesHeader(),
          const Divider(height: 1, color: _kBorder),
          ..._stories.map((s) => _buildStoryRow(s)),
        ],
      ),
    );
  }

  Widget _buildStoriesHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: const [
          SizedBox(width: 80,
              child: Text('Story',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kMuted,
                      letterSpacing: 0.5))),
          Expanded(
              flex: 4,
              child: Text('Title',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kMuted,
                      letterSpacing: 0.5))),
          Expanded(
              flex: 1,
              child: Text('Pts',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kMuted,
                      letterSpacing: 0.5))),
          Expanded(
              flex: 2,
              child: Text('Assignee',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kMuted,
                      letterSpacing: 0.5))),
          Expanded(
              flex: 2,
              child: Text('Value',
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

  Widget _buildStoryRow(_CompletedStory s) {
    final accepted = s.status == 'Accepted';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(s.id,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kMuted)),
          ),
          Expanded(
            flex: 4,
            child: Text(s.title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kHeadline)),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _kAccentBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${s.points}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kAccent)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(s.assignee,
                style:
                    const TextStyle(fontSize: 12, color: _kHeadline)),
          ),
          Expanded(
            flex: 2,
            child: _valueChip(s.value),
          ),
          Expanded(
            flex: 2,
            child: _statusChip(accepted ? 'Accepted' : s.status,
                color: accepted ? Colors.green : Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _valueChip(String value) {
    final color = value == 'High'
        ? _kAccent
        : value == 'Medium'
            ? Colors.blue
            : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(value,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _statusChip(String status, {Color? color}) {
    final c = color ??
        (status == 'Done'
            ? Colors.green
            : status == 'In Progress'
                ? Colors.blue
                : _kAccent);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(status,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: c)),
    );
  }

  Widget _buildDemoChecklist() {
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
              const Icon(Icons.play_circle_outline,
                  size: 20, color: _kAccent),
              const SizedBox(width: 8),
              const Text('Demo Items Checklist',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              Text(
                  '${_demoItems.where((d) => d.status == 'Demoed').length}/${_demoItems.length}',
                  style: const TextStyle(
                      fontSize: 12, color: _kMuted)),
            ],
          ),
          const SizedBox(height: 12),
          ..._demoItems.map((d) => _buildDemoRow(d)),
        ],
      ),
    );
  }

  Widget _buildDemoRow(_DemoItem d) {
    final ready = d.status == 'Ready' || d.status == 'Demoed';
    final demoed = d.status == 'Demoed';
    final blocked = d.status == 'Blocked';
    final color = demoed
        ? Colors.green
        : blocked
            ? Colors.red
            : ready
                ? _kAccent
                : _kMuted;
    return InkWell(
      onTap: () => _toggleDemoItem(d),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _kBorder, width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(
              demoed
                  ? Icons.check_circle
                  : blocked
                      ? Icons.block
                      : ready
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${d.id} · ${d.title}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kHeadline)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 11, color: _kMuted),
                      const SizedBox(width: 4),
                      Text(d.owner,
                          style: const TextStyle(
                              fontSize: 11, color: _kMuted)),
                      if (d.notes.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.notes, size: 11, color: _kMuted),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text(d.notes,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: _kMuted,
                                    fontStyle: FontStyle.italic))),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _statusChip(d.status, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackSection() {
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
              const Icon(Icons.feedback_outlined,
                  size: 20, color: _kAccent),
              const SizedBox(width: 8),
              const Text('Stakeholder Feedback',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
            ],
          ),
          const SizedBox(height: 12),
          ..._feedback.map((f) => _buildFeedbackCard(f)),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(_StakeholderFeedback f) {
    final sentimentColor = f.sentiment == 'positive'
        ? Colors.green
        : f.sentiment == 'mixed'
            ? _kAccent
            : Colors.red;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: sentimentColor, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: sentimentColor.withOpacity(0.15),
                child: Text(
                    f.stakeholder.split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join(),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: sentimentColor)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.stakeholder,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _kHeadline)),
                    Text(f.role,
                        style: const TextStyle(
                            fontSize: 11, color: _kMuted)),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                    5,
                    (i) => Icon(
                          i < f.rating ? Icons.star : Icons.star_border,
                          size: 14,
                          color: _kAccent,
                        )),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(f.comment,
              style: const TextStyle(
                  fontSize: 12, color: _kHeadline, height: 1.4)),
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
              Text(
                  '${_actions.where((a) => a.status == 'Done').length}/${_actions.length} done',
                  style: const TextStyle(
                      fontSize: 12, color: _kMuted)),
            ],
          ),
          const SizedBox(height: 12),
          _buildActionsHeader(),
          const Divider(height: 1, color: _kBorder),
          ..._actions.map((a) => _buildActionRow(a)),
        ],
      ),
    );
  }

  Widget _buildActionsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: const [
          SizedBox(width: 30),
          Expanded(
              flex: 5,
              child: Text('Action',
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
              flex: 2,
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

  Widget _buildActionRow(_ReviewAction a) {
    final done = a.status == 'Done';
    return InkWell(
      onTap: () => _toggleAction(a),
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
              flex: 5,
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
              flex: 2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _kAccentBg,
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
              child: _statusChip(a.status,
                  color: done
                      ? Colors.green
                      : a.status == 'In Progress'
                          ? Colors.blue
                          : _kAccent),
            ),
          ],
        ),
      ),
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
          label: Text(_isSaving ? 'Saving…' : 'Save Review'),
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
class _CompletedStory {
  final String id;
  final String title;
  final int points;
  final String assignee;
  final String status;
  final String value;
  const _CompletedStory({
    required this.id,
    required this.title,
    required this.points,
    required this.assignee,
    required this.status,
    required this.value,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'points': points,
        'assignee': assignee,
        'status': status,
        'value': value,
      };

  factory _CompletedStory.fromMap(Map<String, dynamic> m) => _CompletedStory(
        id: m['id'] as String? ?? '',
        title: m['title'] as String? ?? '',
        points: (m['points'] as num?)?.toInt() ?? 0,
        assignee: m['assignee'] as String? ?? '',
        status: m['status'] as String? ?? 'Accepted',
        value: m['value'] as String? ?? 'Medium',
      );
}

class _DemoItem {
  final String id;
  final String title;
  final String owner;
  final String status;
  final String notes;
  const _DemoItem({
    required this.id,
    required this.title,
    required this.owner,
    required this.status,
    required this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'owner': owner,
        'status': status,
        'notes': notes,
      };

  factory _DemoItem.fromMap(Map<String, dynamic> m) => _DemoItem(
        id: m['id'] as String? ?? '',
        title: m['title'] as String? ?? '',
        owner: m['owner'] as String? ?? '',
        status: m['status'] as String? ?? 'Pending',
        notes: m['notes'] as String? ?? '',
      );
}

class _StakeholderFeedback {
  final String stakeholder;
  final String role;
  final int rating;
  final String comment;
  final String sentiment;
  const _StakeholderFeedback({
    required this.stakeholder,
    required this.role,
    required this.rating,
    required this.comment,
    required this.sentiment,
  });

  Map<String, dynamic> toMap() => {
        'stakeholder': stakeholder,
        'role': role,
        'rating': rating,
        'comment': comment,
        'sentiment': sentiment,
      };

  factory _StakeholderFeedback.fromMap(Map<String, dynamic> m) =>
      _StakeholderFeedback(
        stakeholder: m['stakeholder'] as String? ?? '',
        role: m['role'] as String? ?? '',
        rating: (m['rating'] as num?)?.toInt() ?? 3,
        comment: m['comment'] as String? ?? '',
        sentiment: m['sentiment'] as String? ?? 'positive',
      );
}

class _ReviewAction {
  final String id;
  final String description;
  final String owner;
  final String due;
  final String status;
  final String priority;
  const _ReviewAction({
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

  factory _ReviewAction.fromMap(Map<String, dynamic> m) => _ReviewAction(
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
            Text('Loading sprint review…',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
