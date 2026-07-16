import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// AGILE RETROSPECTIVES — Continuous Improvement with Multiple Templates
/// ═══════════════════════════════════════════════════════════════════════════
class AgileRetrospectivesScreen extends StatefulWidget {
  const AgileRetrospectivesScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AgileRetrospectivesScreen()),
    );
  }

  @override
  State<AgileRetrospectivesScreen> createState() =>
      _AgileRetrospectivesScreenState();
}

class _AgileRetrospectivesScreenState extends State<AgileRetrospectivesScreen> {
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
  int _activeTemplate = 0; // 0 = Start/Stop/Continue, 1 = Mad/Sad/Glad, 2 = 4Ls

  final List<_RetrospectiveTemplate> _templates = [
    _RetrospectiveTemplate(
      name: 'Start / Stop / Continue',
      icon: Icons.play_arrow,
      columns: [
        _RetroColumn(id: 'start', title: 'Start', color: Colors.green, prompt: 'What should we start doing?'),
        _RetroColumn(id: 'stop', title: 'Stop', color: Colors.red, prompt: 'What should we stop doing?'),
        _RetroColumn(id: 'continue', title: 'Continue', color: _kAccent, prompt: 'What is working well?'),
      ],
    ),
    _RetrospectiveTemplate(
      name: 'Mad / Sad / Glad',
      icon: Icons.sentiment_satisfied,
      columns: [
        _RetroColumn(id: 'mad', title: 'Mad', color: Colors.red, prompt: 'What made you mad?'),
        _RetroColumn(id: 'sad', title: 'Sad', color: Colors.blue, prompt: 'What disappointed you?'),
        _RetroColumn(id: 'glad', title: 'Glad', color: Colors.green, prompt: 'What made you happy?'),
      ],
    ),
    _RetrospectiveTemplate(
      name: '4Ls — Liked / Learned / Lacked / Longed For',
      icon: Icons.school,
      columns: [
        _RetroColumn(id: 'liked', title: 'Liked', color: Colors.green, prompt: 'What did you like?'),
        _RetroColumn(id: 'learned', title: 'Learned', color: _kAccent, prompt: 'What did you learn?'),
        _RetroColumn(id: 'lacked', title: 'Lacked', color: Colors.red, prompt: 'What was lacking?'),
        _RetroColumn(id: 'longed', title: 'Longed For', color: Colors.purple, prompt: 'What did you long for?'),
      ],
    ),
  ];

  Map<String, List<_RetroCard>> _cardsByColumn = {};
  final List<_TeamFeedback> _feedback = [];
  final List<_RetroAction> _actions = [];

  String? get _projectId => ProjectDataHelper.getData(context).projectId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
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
          .doc('agile_retrospectives')
          .get();
      final data = doc.data() ?? {};
      final cards = data['cards'] as Map<String, dynamic>? ?? {};
      final feedback = (data['feedback'] as List?)
              ?.map((e) => _TeamFeedback.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [];
      final actions = (data['actions'] as List?)
              ?.map((e) => _RetroAction.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [];
      _currentSprint = data['currentSprint'] as String? ?? _currentSprint;
      if (cards.isEmpty) {
        _seedDemoData();
      } else {
        _cardsByColumn = cards.map((k, v) => MapEntry(
            k,
            (v as List)
                .map((e) => _RetroCard.fromMap(e as Map<String, dynamic>))
                .toList()));
      }
      if (mounted) {
        setState(() {
          if (feedback.isNotEmpty) {
            _feedback.clear();
            _feedback.addAll(feedback);
          }
          if (actions.isNotEmpty) {
            _actions.clear();
            _actions.addAll(actions);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Retrospectives load error: $e');
      _seedDemoData();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _seedDemoData() {
    _cardsByColumn = {
      // Start / Stop / Continue
      'start': [
        _RetroCard(id: 'r1', text: 'Pair programming on hard tickets', author: 'Sarah C.', votes: 5),
        _RetroCard(id: 'r2', text: 'Demo dry-runs the day before review', author: 'Marcus R.', votes: 3),
        _RetroCard(id: 'r3', text: 'Async standup notes in Slack', author: 'Priya N.', votes: 4),
      ],
      'stop': [
        _RetroCard(id: 'r4', text: 'Skipping story refinement mid-sprint', author: 'James O.', votes: 6),
        _RetroCard(id: 'r5', text: 'Ad-hoc scope changes without triage', author: 'Lena P.', votes: 4),
      ],
      'continue': [
        _RetroCard(id: 'r6', text: 'Rotating facilitator for standups', author: 'Sarah C.', votes: 7),
        _RetroCard(id: 'r7', text: 'Kaz AI pattern insights each retro', author: 'Marcus R.', votes: 5),
        _RetroCard(id: 'r8', text: 'End-of-sprint stakeholder preview', author: 'Priya N.', votes: 4),
      ],
      // Mad / Sad / Glad
      'mad': [
        _RetroCard(id: 'm1', text: 'Production incident during sprint kickoff', author: 'James O.', votes: 4),
      ],
      'sad': [
        _RetroCard(id: 'm2', text: 'Story NDU-1015 rejected at review', author: 'James O.', votes: 3),
        _RetroCard(id: 'm3', text: 'Velocity dropped 8% — felt rushed', author: 'Lena P.', votes: 2),
      ],
      'glad': [
        _RetroCard(id: 'm4', text: 'SSO shipped and signed off by security', author: 'Sarah C.', votes: 8),
        _RetroCard(id: 'm5', text: 'Team collaborated really well on rate-limiting', author: 'Marcus R.', votes: 5),
      ],
      // 4Ls
      'liked': [
        _RetroCard(id: 'l1', text: 'Daily KPI visibility from Kaz AI', author: 'Sarah C.', votes: 6),
      ],
      'learned': [
        _RetroCard(id: 'l2', text: 'Redis token bucket pattern for rate limiting', author: 'Marcus R.', votes: 5),
        _RetroCard(id: 'l3', text: 'Importance of DoR checklist', author: 'Priya N.', votes: 4),
      ],
      'lacked': [
        _RetroCard(id: 'l4', text: 'Cross-team dependency visibility', author: 'Lena P.', votes: 5),
      ],
      'longed': [
        _RetroCard(id: 'l5', text: 'Dedicated refinement sessions mid-sprint', author: 'James O.', votes: 6),
        _RetroCard(id: 'l6', text: 'Better dark-mode design tokens', author: 'Priya N.', votes: 4),
      ],
    };
    _feedback.clear();
    _feedback.addAll([
      _TeamFeedback(member: 'Sarah Chen', role: 'Tech Lead', avatar: 'SC', color: Colors.green,
          sentiment: 'positive', comment: 'Best sprint yet — SSO shipping was a huge win. Loved the rotating facilitator experiment.'),
      _TeamFeedback(member: 'Marcus Reed', role: 'Backend Engineer', avatar: 'MR', color: Colors.blue,
          sentiment: 'positive', comment: 'Pairing on rate limiting paid off. Would love more mid-sprint refinement time.'),
      _TeamFeedback(member: 'Priya Nair', role: 'Frontend Engineer', avatar: 'PN', color: Colors.purple,
          sentiment: 'mixed', comment: 'Felt rushed toward the end. Story rejection hurt morale — let\'s tighten DoR.'),
      _TeamFeedback(member: 'James Okoro', role: 'Frontend Engineer', avatar: 'JO', color: Colors.orange,
          sentiment: 'mixed', comment: 'Audit log rejection was frustrating but the feedback was fair. Need clearer acceptance criteria.'),
      _TeamFeedback(member: 'Lena Park', role: 'Frontend Engineer', avatar: 'LP', color: Colors.teal,
          sentiment: 'positive', comment: 'Onboarding tour planning went smoothly. Team coordination was excellent.'),
    ]);
    _actions.clear();
    _actions.addAll([
      _RetroAction(id: 'RA-301', description: 'Schedule 30-min mid-sprint refinement slot',
          owner: 'Sarah Chen', due: 'Next Sprint', status: 'Open', priority: 'High'),
      _RetroAction(id: 'RA-302', description: 'Add DoR checklist to story template',
          owner: 'Marcus Reed', due: 'This week', status: 'In Progress', priority: 'High'),
      _RetroAction(id: 'RA-303', description: 'Cross-team dependency board setup',
          owner: 'Lena Park', due: '2 sprints', status: 'Open', priority: 'Medium'),
      _RetroAction(id: 'RA-304', description: 'Dark-mode design tokens workshop with Design',
          owner: 'Priya Nair', due: 'Next week', status: 'Open', priority: 'Medium'),
      _RetroAction(id: 'RA-305', description: 'Rotate standup facilitator (continue experiment)',
          owner: 'All', due: 'Ongoing', status: 'Done', priority: 'Low'),
    ]);
  }

  Future<void> _saveData() async {
    final pid = _projectId;
    if (pid == null) return;
    setState(() => _isSaving = true);
    try {
      final cardsMap = _cardsByColumn.map((k, v) =>
          MapEntry(k, v.map((c) => c.toMap()).toList()));
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(pid)
          .collection('execution_phase_entries')
          .doc('agile_retrospectives')
          .set({
        'currentSprint': _currentSprint,
        'cards': cardsMap,
        'feedback': _feedback.map((f) => f.toMap()).toList(),
        'actions': _actions.map((a) => a.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Retrospective saved'),
            backgroundColor: _kAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Retrospectives save error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _upvoteCard(String columnId, String cardId) {
    setState(() {
      final list = _cardsByColumn[columnId];
      if (list == null) return;
      final idx = list.indexWhere((c) => c.id == cardId);
      if (idx >= 0) {
        list[idx] = _RetroCard(
          id: list[idx].id,
          text: list[idx].text,
          author: list[idx].author,
          votes: list[idx].votes + 1,
        );
      }
    });
  }

  void _toggleAction(_RetroAction a) {
    setState(() {
      final idx = _actions.indexWhere((x) => x.id == a.id);
      if (idx >= 0) {
        final newStatus = a.status == 'Done' ? 'Open' : 'Done';
        _actions[idx] = _RetroAction(
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
    final activeTemplate = _templates[_activeTemplate];

    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: const InitiationLikeSidebar(
                  activeItemLabel: 'Agile Retrospectives'),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                      activeItemLabel: 'Agile Retrospectives',
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
                          title: 'Sprint Retrospectives',
                          showNavigationButtons: false,
                          breadcrumbPhase: 'Execution',
                          breadcrumbTitle: 'Agile Hub › Retrospectives',
                        ),
                        const SizedBox(height: 24),
                        if (_isLoading)
                          const _LoadingStrip()
                        else ...[
                          _buildSummaryRow(),
                          const SizedBox(height: 24),
                          _buildTemplateSelector(),
                          const SizedBox(height: 20),
                          _buildTemplateBoard(activeTemplate, isMobile),
                          const SizedBox(height: 24),
                          _buildTeamFeedback(),
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
          child: Text('$_currentSprint RETRO',
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
    final totalCards =
        _cardsByColumn.values.fold<int>(0, (a, b) => a + b.length);
    final totalVotes = _cardsByColumn.values
        .fold<int>(0, (a, list) => a + list.fold<int>(0, (b, c) => b + c.votes));
    final positive = _feedback.where((f) => f.sentiment == 'positive').length;
    final actionsDone =
        _actions.where((a) => a.status == 'Done').length;
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
              child: _summaryCell('Insights', '$totalCards', Icons.lightbulb_outline)),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.3)),
          Expanded(
              child: _summaryCell('Votes', '$totalVotes', Icons.thumb_up_outlined)),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.3)),
          Expanded(
              child: _summaryCell('Positive', '$positive/${_feedback.length}',
                  Icons.sentiment_satisfied)),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.3)),
          Expanded(
              child: _summaryCell('Actions', '$actionsDone/${_actions.length}',
                  Icons.assignment_turned_in)),
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

  Widget _buildTemplateSelector() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: _templates.asMap().entries.map((e) {
          final i = e.key;
          final t = e.value;
          final selected = i == _activeTemplate;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTemplate = i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 10),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: selected ? _kAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(t.icon,
                        size: 14,
                        color: selected ? Colors.white : _kMuted),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(t.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : _kHeadline)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTemplateBoard(_RetrospectiveTemplate t, bool isMobile) {
    final cols = t.columns;
    if (isMobile) {
      return Column(
        children: cols
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildRetroColumn(c, t),
                ))
            .toList(),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: cols
          .map((c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildRetroColumn(c, t),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildRetroColumn(_RetroColumn col, _RetrospectiveTemplate t) {
    final cards = _cardsByColumn[col.id] ?? [];
    return Container(
      padding: const EdgeInsets.all(12),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: col.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.label, size: 14, color: col.color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(col.title,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _kHeadline)),
                    Text(col.prompt,
                        style: const TextStyle(
                            fontSize: 10, color: _kMuted)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: col.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${cards.length}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: col.color)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...cards.map((c) => _buildRetroCard(c, col)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _addCard(col),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(
                    color: col.color.withOpacity(0.3),
                    style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 14, color: col.color),
                  const SizedBox(width: 4),
                  Text('Add card',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: col.color)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetroCard(_RetroCard c, _RetroColumn col) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: col.color, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.text,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _kHeadline,
                  height: 1.4)),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 9,
                backgroundColor: col.color.withOpacity(0.15),
                child: Text(
                    c.author.split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join(),
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: col.color)),
              ),
              const SizedBox(width: 6),
              Text(c.author,
                  style: const TextStyle(
                      fontSize: 10, color: _kMuted)),
              const Spacer(),
              InkWell(
                onTap: () => _upvoteCard(col.id, c.id),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: col.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.thumb_up, size: 10, color: col.color),
                      const SizedBox(width: 3),
                      Text('${c.votes}',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: col.color)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addCard(_RetroColumn col) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Add to "${col.title}"',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(
            hintText: col.prompt,
            border: const OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: _kAccent, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: _kMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              setState(() {
                _cardsByColumn.putIfAbsent(col.id, () => []);
                _cardsByColumn[col.id]!.add(_RetroCard(
                  id: 'r${DateTime.now().millisecondsSinceEpoch}',
                  text: ctrl.text.trim(),
                  author: 'You',
                  votes: 0,
                ));
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent, foregroundColor: Colors.white),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamFeedback() {
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
              const Icon(Icons.forum_outlined, size: 20, color: _kAccent),
              const SizedBox(width: 8),
              const Text('Team Feedback',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: _feedback
                .map((f) => ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth:
                              (MediaQuery.of(context).size.width - 480) / 2),
                      child: _buildFeedbackCard(f),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(_TeamFeedback f) {
    final sentimentColor = f.sentiment == 'positive'
        ? Colors.green
        : f.sentiment == 'mixed'
            ? _kAccent
            : Colors.red;
    return Container(
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
                backgroundColor: f.color.withOpacity(0.15),
                child: Text(f.avatar,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: f.color)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.member,
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
              Icon(
                f.sentiment == 'positive'
                    ? Icons.sentiment_satisfied
                    : f.sentiment == 'mixed'
                        ? Icons.sentiment_neutral
                        : Icons.sentiment_dissatisfied,
                size: 18,
                color: sentimentColor,
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
              const Icon(Icons.assignment_turned_in_outlined,
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

  Widget _buildActionRow(_RetroAction a) {
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

  Widget _statusChip(String status, {Color? color}) {
    final c = color ?? _kAccent;
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
          label: Text(_isSaving ? 'Saving…' : 'Save Retrospective'),
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
class _RetrospectiveTemplate {
  final String name;
  final IconData icon;
  final List<_RetroColumn> columns;
  const _RetrospectiveTemplate({
    required this.name,
    required this.icon,
    required this.columns,
  });
}

class _RetroColumn {
  final String id;
  final String title;
  final Color color;
  final String prompt;
  const _RetroColumn({
    required this.id,
    required this.title,
    required this.color,
    required this.prompt,
  });
}

class _RetroCard {
  final String id;
  final String text;
  final String author;
  final int votes;
  const _RetroCard({
    required this.id,
    required this.text,
    required this.author,
    required this.votes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'author': author,
        'votes': votes,
      };

  factory _RetroCard.fromMap(Map<String, dynamic> m) => _RetroCard(
        id: m['id'] as String? ?? '',
        text: m['text'] as String? ?? '',
        author: m['author'] as String? ?? 'Anonymous',
        votes: (m['votes'] as num?)?.toInt() ?? 0,
      );
}

class _TeamFeedback {
  final String member;
  final String role;
  final String avatar;
  final Color color;
  final String sentiment;
  final String comment;
  const _TeamFeedback({
    required this.member,
    required this.role,
    required this.avatar,
    required this.color,
    required this.sentiment,
    required this.comment,
  });

  Map<String, dynamic> toMap() => {
        'member': member,
        'role': role,
        'avatar': avatar,
        'color': color.toARGB32(),
        'sentiment': sentiment,
        'comment': comment,
      };

  factory _TeamFeedback.fromMap(Map<String, dynamic> m) => _TeamFeedback(
        member: m['member'] as String? ?? '',
        role: m['role'] as String? ?? '',
        avatar: m['avatar'] as String? ?? '',
        color: Color(m['color'] as int? ?? 0xFF6B7280),
        sentiment: m['sentiment'] as String? ?? 'neutral',
        comment: m['comment'] as String? ?? '',
      );
}

class _RetroAction {
  final String id;
  final String description;
  final String owner;
  final String due;
  final String status;
  final String priority;
  const _RetroAction({
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

  factory _RetroAction.fromMap(Map<String, dynamic> m) => _RetroAction(
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
            Text('Loading retrospective…',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
