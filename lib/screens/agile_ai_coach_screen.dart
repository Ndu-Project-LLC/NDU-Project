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
/// AGILE AI COACH — AI Capability Cards, Chat, Maturity Scorecard
/// ═══════════════════════════════════════════════════════════════════════════
class AgileAiCoachScreen extends StatefulWidget {
  const AgileAiCoachScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AgileAiCoachScreen()),
    );
  }

  @override
  State<AgileAiCoachScreen> createState() => _AgileAiCoachScreenState();
}

class _AgileAiCoachScreenState extends State<AgileAiCoachScreen> {
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
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  final List<_ChatMessage> _chat = [];

  // AI capability cards
  final List<_AiCapability> _capabilities = [
    _AiCapability(
        id: 'sprint_planning',
        title: 'Sprint Planning',
        description: 'AI recommends which stories to pull based on velocity, capacity, and dependencies.',
        icon: Icons.event_note_outlined,
        confidence: 0.92,
        lastRun: '2h ago',
        enabled: true),
    _AiCapability(
        id: 'story_writing',
        title: 'Story Writing',
        description: 'Generate user stories, acceptance criteria, and INVEST check from briefs.',
        icon: Icons.edit_note,
        confidence: 0.88,
        lastRun: '5h ago',
        enabled: true),
    _AiCapability(
        id: 'estimation',
        title: 'Estimation Assistant',
        description: 'Suggest story points using historical analogy and team velocity baseline.',
        icon: Icons.scale,
        confidence: 0.81,
        lastRun: '1d ago',
        enabled: true),
    _AiCapability(
        id: 'risk_id',
        title: 'Risk Identification',
        description: 'Scan sprint backlog for technical, schedule, and dependency risks.',
        icon: Icons.warning_amber_outlined,
        confidence: 0.86,
        lastRun: '6h ago',
        enabled: true),
    _AiCapability(
        id: 'retro_insights',
        title: 'Retrospective Insights',
        description: 'Detect recurring themes across retros and propose experiments.',
        icon: Icons.lightbulb_outline,
        confidence: 0.79,
        lastRun: '2d ago',
        enabled: true),
    _AiCapability(
        id: 'predictability',
        title: 'Predictability Forecast',
        description: 'Forecast sprint completion probability from daily burn rate.',
        icon: Icons.insights,
        confidence: 0.90,
        lastRun: '1h ago',
        enabled: true),
    _AiCapability(
        id: 'blocker_triage',
        title: 'Blocker Triage',
        description: 'Auto-categorize blockers and recommend owner and SLA.',
        icon: Icons.bug_report_outlined,
        confidence: 0.74,
        lastRun: '12h ago',
        enabled: false),
    _AiCapability(
        id: 'maturity_coach',
        title: 'Maturity Coach',
        description: 'Track agile maturity dimensions and recommend next practices.',
        icon: Icons.school_outlined,
        confidence: 0.83,
        lastRun: '3h ago',
        enabled: true),
  ];

  // Agile maturity scorecard
  final List<_MaturityDimension> _maturity = [
    _MaturityDimension('Backlog Management', 0.85, 'Performing'),
    _MaturityDimension('Sprint Cadence', 0.92, 'Optimizing'),
    _MaturityDimension('Definition of Ready', 0.65, 'Practicing'),
    _MaturityDimension('Definition of Done', 0.78, 'Performing'),
    _MaturityDimension('Stakeholder Engagement', 0.88, 'Performing'),
    _MaturityDimension('Continuous Improvement', 0.72, 'Practicing'),
    _MaturityDimension('Engineering Practices', 0.80, 'Performing'),
    _MaturityDimension('Flow & WIP Discipline', 0.55, 'Practicing'),
  ];

  // Best practice tips
  final List<_PracticeTip> _tips = [
    _PracticeTip(
        title: 'Right-size your stories',
        body: 'Keep stories under 5 points. Larger stories hide risk and inflate WIP.',
        icon: Icons.crop_square,
        tag: 'Backlog'),
    _PracticeTip(
        title: 'Refine mid-sprint',
        body: 'Run a 30-min refinement mid-sprint to keep the backlog ready.',
        icon: Icons.tune,
        tag: 'Ceremony'),
    _PracticeTip(
        title: 'Enforce WIP limits',
        body: 'Limit In Progress to 3 per developer to reduce context switching.',
        icon: Icons.layers_clear,
        tag: 'Flow'),
    _PracticeTip(
        title: 'Demo dry-runs',
        body: 'Hold a demo dry-run the day before review to catch integration issues.',
        icon: Icons.play_circle_outline,
        tag: 'Review'),
  ];

  String? get _projectId => ProjectDataHelper.getData(context).projectId;

  @override
  void initState() {
    super.initState();
    _seedChat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  void _seedChat() {
    final projectData = ProjectDataHelper.getData(context);
    final sprintLabel = AgileProjectContextHelper.activeSprintLabel(projectData);
    final workItems = AgileProjectContextHelper.workItems(projectData, limit: 3);
    final risks = AgileProjectContextHelper.risks(projectData, limit: 2);
    final topItem = workItems.isEmpty ? 'the current project backlog' : workItems.first.title;
    final topRisk = risks.isEmpty ? 'delivery dependencies from the project record' : risks.first.title;
    _chat.addAll([
      _ChatMessage(
          from: 'ai',
          text: 'Hi! I\'m Kaz, your Agile AI Coach. I\'m using project-wide backlog, schedule, and risk context for $sprintLabel. Want me to prioritize the next best work item?',
          time: '2:14 PM'),
      _ChatMessage(
          from: 'user',
          text: 'What should the team focus on first?',
          time: '2:15 PM'),
      _ChatMessage(
          from: 'ai',
          text: 'Based on current project context, I would focus on "$topItem" first and keep an eye on "$topRisk" as the main delivery constraint.',
          time: '2:15 PM'),
    ]);
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
          .doc('agile_ai_coach')
          .get();
      final data = doc.data() ?? {};
      // Restore capability enable states
      final caps = data['capabilities'] as Map<String, dynamic>?;
      if (caps != null) {
        for (final c in _capabilities) {
          final v = caps[c.id];
          if (v is bool) {
            final idx = _capabilities.indexOf(c);
            _capabilities[idx] = _AiCapability(
              id: c.id,
              title: c.title,
              description: c.description,
              icon: c.icon,
              confidence: c.confidence,
              lastRun: c.lastRun,
              enabled: v,
            );
          }
        }
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('AI coach load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
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
          .doc('agile_ai_coach')
          .set({
        'capabilities': {
          for (final c in _capabilities) c.id: c.enabled,
        },
        'chat': _chat.map((m) => m.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('AI coach preferences saved'),
            backgroundColor: _kAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('AI coach save error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toggleCapability(_AiCapability cap) {
    setState(() {
      final idx = _capabilities.indexOf(cap);
      _capabilities[idx] = _AiCapability(
        id: cap.id,
        title: cap.title,
        description: cap.description,
        icon: cap.icon,
        confidence: cap.confidence,
        lastRun: cap.lastRun,
        enabled: !cap.enabled,
      );
    });
  }

  void _sendMessage() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    final now = DateTime.now();
    final timeStr =
        '${now.hour > 12 ? now.hour - 12 : now.hour}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
    setState(() {
      _chat.add(_ChatMessage(from: 'user', text: text, time: timeStr));
    });
    _chatCtrl.clear();
    _scrollToBottom();
    // Simulate AI response
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final aiNow = DateTime.now();
      final aiTime =
          '${aiNow.hour > 12 ? aiNow.hour - 12 : aiNow.hour}:${aiNow.minute.toString().padLeft(2, '0')} ${aiNow.hour >= 12 ? 'PM' : 'AM'}';
      setState(() {
        _chat.add(_ChatMessage(
            from: 'ai',
            text: _generateAiReply(text),
            time: aiTime));
      });
      _scrollToBottom();
    });
  }

  String _generateAiReply(String input) {
    final projectData = ProjectDataHelper.getData(context);
    final sprintLabel = AgileProjectContextHelper.activeSprintLabel(projectData);
    final workItems = AgileProjectContextHelper.workItems(projectData, limit: 8);
    final risks = AgileProjectContextHelper.risks(projectData, limit: 6);
    final issues = AgileProjectContextHelper.issues(projectData, limit: 6);
    final people = AgileProjectContextHelper.people(projectData, limit: 6);
    final totalPoints = workItems.fold<int>(
      0,
      (sum, item) => sum + AgileProjectContextHelper.estimateStoryPoints(item.title),
    );
    final completedPoints = workItems
        .where((item) => item.status == 'Done' || item.status == 'In Review')
        .fold<int>(
          0,
          (sum, item) => sum + AgileProjectContextHelper.estimateStoryPoints(item.title),
        );
    final lower = input.toLowerCase();
    if (lower.contains('velocity')) {
      return '$sprintLabel is currently carrying about $totalPoints story points from project-linked backlog items, with roughly $completedPoints points already progressed.';
    } else if (lower.contains('risk')) {
      final risk = risks.isEmpty ? null : risks.first;
      return risk == null
          ? 'I do not see a populated agile risk entry yet, so I would start by reviewing issue log items and execution risks for blockers.'
          : 'The highest-priority project risk I can see is "${risk.title}" owned by ${risk.owner.isEmpty ? 'the project team' : risk.owner}.';
    } else if (lower.contains('estimat')) {
      final item = workItems.isEmpty ? null : workItems.first;
      return item == null
          ? 'I need backlog detail before estimating, but once requirements are added I can score them from project context.'
          : 'For "${item.title}", I would start at ${AgileProjectContextHelper.estimateStoryPoints(item.title)} points based on the current scope wording and linked project detail.';
    } else if (lower.contains('retro')) {
      return 'From the current project record, the strongest retro themes are scope readiness, open dependencies, and follow-through on issue resolution. I would test one recurring mid-sprint refinement slot.';
    } else if (lower.contains('sprint')) {
      return '$sprintLabel should center on ${workItems.isEmpty ? 'the top backlog items' : workItems.first.title}. Team coverage currently reflects ${people.length} mapped contributors and ${issues.length} active issue entries.';
    } else {
      return 'I can help with sprint planning, story writing, estimation, risk ID, retro insights, predictability forecasting, blocker triage, and agile maturity coaching. Which area would you like to explore?';
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
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
                  activeItemLabel: 'AI Agile Coach'),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                      activeItemLabel: 'AI Agile Coach',
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
                          title: 'AI Agile Coach',
                          showNavigationButtons: false,
                          breadcrumbPhase: 'Execution',
                          breadcrumbTitle: 'Agile Hub › AI Coach',
                        ),
                        const SizedBox(height: 24),
                        if (_isLoading)
                          const _LoadingStrip()
                        else ...[
                          _buildCoachHero(),
                          const SizedBox(height: 24),
                          _buildCapabilitiesGrid(isMobile),
                          const SizedBox(height: 24),
                          if (!isMobile)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildChatPanel()),
                                const SizedBox(width: 24),
                                Expanded(child: _buildMaturityScorecard()),
                              ],
                            )
                          else ...[
                            _buildChatPanel(),
                            const SizedBox(height: 24),
                            _buildMaturityScorecard(),
                          ],
                          const SizedBox(height: 24),
                          _buildBestPractices(isMobile),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.auto_awesome, size: 14, color: _kAccent),
              SizedBox(width: 6),
              Text('KAZ AI ACTIVE',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kAccent,
                      letterSpacing: 1.1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCoachHero() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kAccent.withOpacity(0.4)),
            ),
            child: const Icon(Icons.auto_awesome,
                size: 32, color: _kAccentLight),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kaz AI — Your Agile Coach',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 6),
                const Text(
                    'Embedded AI guidance across sprint planning, story writing, estimation, risk detection, and continuous improvement. Proactive recommendations tuned to your delivery patterns.',
                    style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFC7D2FE),
                        height: 1.5)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _heroBadge('8 Capabilities'),
                    _heroBadge('${_capabilities.where((c) => c.enabled).length} Active'),
                    _heroBadge('Avg 85% confidence'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildCapabilitiesGrid(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.extension_outlined, size: 20, color: _kAccent),
            const SizedBox(width: 8),
            const Text('AI Capabilities',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _kHeadline)),
            const Spacer(),
            Text('${_capabilities.where((c) => c.enabled).length}/${_capabilities.length} active',
                style: const TextStyle(
                    fontSize: 12, color: _kMuted)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: _capabilities
              .map((c) => ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: isMobile
                            ? double.infinity
                            : (MediaQuery.of(context).size.width - 480) / 3),
                    child: _buildCapabilityCard(c),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildCapabilityCard(_AiCapability c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: c.enabled ? _kAccent.withOpacity(0.3) : _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: c.enabled
                      ? _kAccent.withOpacity(0.12)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(c.icon,
                    size: 18,
                    color: c.enabled ? _kAccent : _kMuted),
              ),
              const Spacer(),
              Switch(
                value: c.enabled,
                onChanged: (_) => _toggleCapability(c),
                activeColor: _kAccent,
                activeTrackColor: _kAccentBg,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(c.title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kHeadline)),
          const SizedBox(height: 4),
          Text(c.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, color: _kMuted, height: 1.4)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: c.confidence,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF3F4F6),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(_kAccent),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(c.confidence * 100).toInt()}%',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kAccent)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.access_time, size: 10, color: _kMuted),
              const SizedBox(width: 4),
              Text('Last run ${c.lastRun}',
                  style: const TextStyle(
                      fontSize: 10, color: _kMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatPanel() {
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.smart_toy_outlined,
                    size: 16, color: _kAccent),
              ),
              const SizedBox(width: 8),
              const Text('Chat with Kaz AI',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: Colors.green, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              const Text('Online',
                  style: TextStyle(
                      fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600)),
            ],
          ),
          const Divider(height: 18),
          SizedBox(
            height: 280,
            child: ListView.builder(
              controller: _chatScroll,
              itemCount: _chat.length,
              itemBuilder: (ctx, i) {
                final m = _chat[i];
                final isUser = m.from == 'user';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: isUser
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser) ...[
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: _kAccent.withOpacity(0.15),
                          child: const Icon(Icons.auto_awesome,
                              size: 12, color: _kAccent),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isUser
                                ? _kAccent
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(12),
                              topRight: const Radius.circular(12),
                              bottomLeft: Radius.circular(isUser ? 12 : 0),
                              bottomRight: Radius.circular(isUser ? 0 : 12),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.text,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isUser
                                          ? Colors.white
                                          : _kHeadline,
                                      height: 1.4)),
                              const SizedBox(height: 4),
                              Text(m.time,
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: isUser
                                          ? Colors.white.withOpacity(0.7)
                                          : _kMuted)),
                            ],
                          ),
                        ),
                      ),
                      if (isUser) const SizedBox(width: 8),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatCtrl,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Ask Kaz about velocity, risks, estimates…',
                    hintStyle: const TextStyle(fontSize: 12, color: _kMuted),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _kBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: _kAccent, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: _kAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaturityScorecard() {
    final avg = _maturity.map((m) => m.value).reduce((a, b) => a + b) /
        _maturity.length;
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
              const Icon(Icons.scoreboard_outlined,
                  size: 20, color: _kAccent),
              const SizedBox(width: 8),
              const Text('Agile Maturity Scorecard',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAccentBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${(avg * 100).toInt()}%',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _kAccent)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._maturity.map((m) => _buildMaturityRow(m)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kAccentBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up,
                    size: 16, color: _kAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Overall maturity trend: +6% vs last sprint. Strongest gain in Stakeholder Engagement; biggest gap in Flow & WIP Discipline.',
                    style: TextStyle(
                        fontSize: 11, color: Colors.brown[800], height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaturityRow(_MaturityDimension m) {
    final color = m.value >= 0.85
        ? Colors.green
        : m.value >= 0.7
            ? _kAccent
            : Colors.red;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(m.name,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kHeadline)),
              const Spacer(),
              Text(m.stage,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color)),
              const SizedBox(width: 6),
              Text('${(m.value * 100).toInt()}%',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: m.value,
              minHeight: 6,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBestPractices(bool isMobile) {
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
              const Icon(Icons.tips_and_updates_outlined,
                  size: 20, color: _kAccent),
              const SizedBox(width: 8),
              const Text('Best Practice Tips',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: _tips
                .map((t) => ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: isMobile
                              ? double.infinity
                              : (MediaQuery.of(context).size.width - 480) / 2),
                      child: _buildTipCard(t),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(_PracticeTip t) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: const BorderSide(color: _kAccent, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(t.icon, size: 16, color: _kAccent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(t.title,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _kHeadline)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: _kAccentBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(t.tag,
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _kAccent)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(t.body,
                    style: const TextStyle(
                        fontSize: 12, color: _kMuted, height: 1.4)),
              ],
            ),
          ),
        ],
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
          label: Text(_isSaving ? 'Saving…' : 'Save Preferences'),
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
class _AiCapability {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final double confidence;
  final String lastRun;
  final bool enabled;
  const _AiCapability({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.confidence,
    required this.lastRun,
    required this.enabled,
  });
}

class _MaturityDimension {
  final String name;
  final double value;
  final String stage;
  const _MaturityDimension(this.name, this.value, this.stage);
}

class _PracticeTip {
  final String title;
  final String body;
  final IconData icon;
  final String tag;
  const _PracticeTip({
    required this.title,
    required this.body,
    required this.icon,
    required this.tag,
  });
}

class _ChatMessage {
  final String from; // 'ai' or 'user'
  final String text;
  final String time;
  const _ChatMessage({required this.from, required this.text, required this.time});

  Map<String, dynamic> toMap() => {'from': from, 'text': text, 'time': time};
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
            Text('Loading AI coach…',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
