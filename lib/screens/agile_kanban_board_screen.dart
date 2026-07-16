import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// AGILE KANBAN BOARD — Visual Work Management Screen
/// ═══════════════════════════════════════════════════════════════════════════
class AgileKanbanBoardScreen extends StatefulWidget {
  const AgileKanbanBoardScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AgileKanbanBoardScreen()),
    );
  }

  @override
  State<AgileKanbanBoardScreen> createState() => _AgileKanbanBoardScreenState();
}

class _AgileKanbanBoardScreenState extends State<AgileKanbanBoardScreen> {
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

  // Column definitions with WIP limits
  final List<_KanbanColumn> _columns = [
    _KanbanColumn(id: 'backlog', title: 'Backlog', accent: Color(0xFF6B7280), wipLimit: 999),
    _KanbanColumn(id: 'ready', title: 'Ready', accent: Color(0xFF3B82F6), wipLimit: 8),
    _KanbanColumn(id: 'in_progress', title: 'In Progress', accent: _kAccent, wipLimit: 5),
    _KanbanColumn(id: 'in_review', title: 'In Review', accent: Color(0xFF8B5CF6), wipLimit: 3),
    _KanbanColumn(id: 'done', title: 'Done', accent: Color(0xFF10B981), wipLimit: 999),
  ];

  late final Map<String, List<_KanbanCard>> _cardsByColumn;

  String? get _projectId => ProjectDataHelper.getData(context).projectId;

  @override
  void initState() {
    super.initState();
    _cardsByColumn = {
      for (final c in _columns) c.id: <_KanbanCard>[],
    };
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
          .doc('agile_kanban_board')
          .get();
      final data = doc.data() ?? {};
      final cards = data['cards'] as List? ?? [];
      if (cards.isEmpty) {
        _seedDemoCards();
      } else {
        for (final c in _columns) {
          _cardsByColumn[c.id] = [];
        }
        for (final raw in cards) {
          final m = raw as Map<String, dynamic>;
          final card = _KanbanCard(
            id: m['id'] as String? ?? '',
            title: m['title'] as String? ?? 'Untitled',
            description: m['description'] as String? ?? '',
            points: (m['points'] as num?)?.toInt() ?? 0,
            assignee: m['assignee'] as String? ?? 'Unassigned',
            priority: m['priority'] as String? ?? 'Medium',
            columnId: m['columnId'] as String? ?? 'backlog',
            tags: (m['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
          );
          if (_cardsByColumn.containsKey(card.columnId)) {
            _cardsByColumn[card.columnId]!.add(card);
          }
        }
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Kanban load error: $e');
      _seedDemoCards();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _seedDemoCards() {
    _cardsByColumn['backlog'] = [
      _KanbanCard(id: 'NDU-1051', title: 'Reporting module: export to PDF',
          description: 'Allow users to export dashboard as PDF report.',
          points: 5, assignee: 'Lena Park', priority: 'Medium', columnId: 'backlog',
          tags: ['frontend', 'reporting']),
      _KanbanCard(id: 'NDU-1052', title: 'Notification preferences UI',
          description: 'Build a settings page for notification preferences.',
          points: 3, assignee: 'James Okoro', priority: 'Low', columnId: 'backlog',
          tags: ['frontend']),
      _KanbanCard(id: 'NDU-1053', title: 'Audit log retention policy',
          description: 'Define and implement retention rules for audit log.',
          points: 8, assignee: 'Priya Nair', priority: 'High', columnId: 'backlog',
          tags: ['backend', 'security']),
      _KanbanCard(id: 'NDU-1054', title: 'Localization: French strings',
          description: 'Add FR translations for all user-facing copy.',
          points: 5, assignee: 'Sarah Chen', priority: 'Medium', columnId: 'backlog',
          tags: ['i18n']),
      _KanbanCard(id: 'NDU-1055', title: 'Dashboard widget drag-drop',
          description: 'Reorderable widget grid with persistence.',
          points: 8, assignee: 'Marcus Reed', priority: 'High', columnId: 'backlog',
          tags: ['frontend', 'ux']),
    ];
    _cardsByColumn['ready'] = [
      _KanbanCard(id: 'NDU-1049', title: 'API rate limiting middleware',
          description: 'Per-tenant rate limit using Redis token bucket.',
          points: 5, assignee: 'Marcus Reed', priority: 'High', columnId: 'ready',
          tags: ['backend', 'infra']),
      _KanbanCard(id: 'NDU-1050', title: 'User onboarding tour',
          description: 'Guided first-run tour using coach marks.',
          points: 3, assignee: 'Lena Park', priority: 'Medium', columnId: 'ready',
          tags: ['frontend', 'ux']),
    ];
    _cardsByColumn['in_progress'] = [
      _KanbanCard(id: 'NDU-1042', title: 'Login validation hardening',
          description: 'Add server-side validation and rate checks.',
          points: 3, assignee: 'Sarah Chen', priority: 'High', columnId: 'in_progress',
          tags: ['backend', 'security']),
      _KanbanCard(id: 'NDU-1045', title: 'Reporting module: data layer',
          description: 'Repository and DTOs for report aggregation.',
          points: 5, assignee: 'Lena Park', priority: 'Medium', columnId: 'in_progress',
          tags: ['backend']),
      _KanbanCard(id: 'NDU-1046', title: 'Dark mode theme tokens',
          description: 'Centralize dark theme tokens and propagate.',
          points: 2, assignee: 'James Okoro', priority: 'Low', columnId: 'in_progress',
          tags: ['frontend', 'theme']),
    ];
    _cardsByColumn['in_review'] = [
      _KanbanCard(id: 'NDU-1038', title: 'API rate limiting scaffolding',
          description: 'Wire middleware skeleton for review.',
          points: 2, assignee: 'Marcus Reed', priority: 'Medium', columnId: 'in_review',
          tags: ['backend']),
      _KanbanCard(id: 'NDU-1031', title: 'Dashboard widgets: KPI card',
          description: 'Reusable KPI card component with sparkline.',
          points: 3, assignee: 'Priya Nair', priority: 'Medium', columnId: 'in_review',
          tags: ['frontend']),
    ];
    _cardsByColumn['done'] = [
      _KanbanCard(id: 'NDU-1029', title: 'SSO integration: SAML',
          description: 'Enterprise SAML SSO sign-in flow.',
          points: 8, assignee: 'Sarah Chen', priority: 'High', columnId: 'done',
          tags: ['security', 'auth']),
      _KanbanCard(id: 'NDU-1027', title: 'Kanban board UI shell',
          description: '5-column layout with drag-drop placeholder.',
          points: 5, assignee: 'James Okoro', priority: 'Medium', columnId: 'done',
          tags: ['frontend']),
      _KanbanCard(id: 'NDU-1024', title: 'Auth: refresh tokens',
          description: 'Rotating refresh tokens with revocation.',
          points: 3, assignee: 'Marcus Reed', priority: 'High', columnId: 'done',
          tags: ['security', 'auth']),
      _KanbanCard(id: 'NDU-1020', title: 'Notification service v1',
          description: 'In-app + email notification pipeline.',
          points: 8, assignee: 'Priya Nair', priority: 'Medium', columnId: 'done',
          tags: ['backend']),
    ];
  }

  Future<void> _saveData() async {
    final pid = _projectId;
    if (pid == null) return;
    setState(() => _isSaving = true);
    try {
      final allCards = <Map<String, dynamic>>[];
      for (final entry in _cardsByColumn.entries) {
        for (final c in entry.value) {
          allCards.add({
            'id': c.id,
            'title': c.title,
            'description': c.description,
            'points': c.points,
            'assignee': c.assignee,
            'priority': c.priority,
            'columnId': entry.key,
            'tags': c.tags,
          });
        }
      }
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(pid)
          .collection('execution_phase_entries')
          .doc('agile_kanban_board')
          .set({
        'cards': allCards,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kanban board saved'),
            backgroundColor: _kAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Kanban save error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _moveCard(_KanbanCard card, String fromColumn, String toColumn) {
    if (fromColumn == toColumn) return;
    setState(() {
      _cardsByColumn[fromColumn]?.removeWhere((c) => c.id == card.id);
      _cardsByColumn[toColumn]?.add(card.copyWith(columnId: toColumn));
    });
  }

  void _showMoveSheet(_KanbanCard card) {
    final currentCol = _columns.firstWhere((c) => c.id == card.columnId);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Move story',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const SizedBox(height: 4),
              Text(card.title,
                  style: const TextStyle(fontSize: 13, color: _kMuted)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _columns
                    .map((c) => ChoiceChip(
                          label: Text('${c.title}'),
                          selected: c.id == currentCol.id,
                          selectedColor: c.accent.withOpacity(0.2),
                          onSelected: (_) {
                            Navigator.pop(ctx);
                            _moveCard(card, currentCol.id, c.id);
                          },
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCardDetail(_KanbanCard card) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            _priorityDot(card.priority),
            const SizedBox(width: 8),
            Text(card.id,
                style: const TextStyle(
                    fontSize: 14, color: _kMuted, fontWeight: FontWeight.w600)),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(card.title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const SizedBox(height: 12),
              Text(card.description,
                  style: const TextStyle(
                      fontSize: 13, color: _kMuted, height: 1.5)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _metaChip(Icons.bolt, '${card.points} pts', _kAccent),
                  _metaChip(Icons.person_outline, card.assignee, Colors.blue),
                  ...card.tags.map((t) =>
                      _metaChip(Icons.label_outline, t, Colors.purple)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close',
                style: TextStyle(color: _kMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showMoveSheet(card);
            },
            icon: const Icon(Icons.swap_horiz, size: 16),
            label: const Text('Move'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }

  Color _priorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'critical':
        return const Color(0xFFDC2626);
      case 'high':
        return const Color(0xFFF59E0B);
      case 'medium':
        return const Color(0xFF3B82F6);
      case 'low':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Widget _priorityDot(String p) {
    final c = _priorityColor(p);
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: c.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 1)),
        ],
      ),
    );
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
                  activeItemLabel: 'Agile Kanban Board'),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                      activeItemLabel: 'Agile Kanban Board',
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
                          title: 'Kanban Board',
                          showNavigationButtons: false,
                          breadcrumbPhase: 'Execution',
                          breadcrumbTitle: 'Agile Hub › Kanban Board',
                        ),
                        const SizedBox(height: 24),
                        if (_isLoading)
                          const _LoadingStrip()
                        else ...[
                          _buildSummaryBar(),
                          const SizedBox(height: 20),
                          _buildBoard(isMobile),
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
          child: const Text('SPRINT 24',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kAccent,
                  letterSpacing: 1.1)),
        ),
      ],
    );
  }

  Widget _buildSummaryBar() {
    final total = _cardsByColumn.values
        .fold<int>(0, (a, b) => a + b.length);
    final inProgress = _cardsByColumn['in_progress']?.length ?? 0;
    final done = _cardsByColumn['done']?.length ?? 0;
    final pointsDone = (_cardsByColumn['done'] ?? [])
        .fold<int>(0, (a, c) => a + c.points);
    final pointsTotal = _cardsByColumn.values
        .fold<int>(0, (a, list) => a + list.fold<int>(0, (b, c) => b + c.points));
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
            child: _summaryCell('Total Stories', '$total', Icons.layers),
          ),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.3)),
          Expanded(
            child: _summaryCell('In Progress', '$inProgress', Icons.flash_on),
          ),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.3)),
          Expanded(
            child: _summaryCell('Points Done', '$pointsDone / $pointsTotal',
                Icons.stars),
          ),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.3)),
          Expanded(
            child: _summaryCell('Done', '$done', Icons.check_circle_outline),
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

  Widget _buildBoard(bool isMobile) {
    if (isMobile) {
      return Column(
        children: _columns
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildColumn(c),
                ))
            .toList(),
      );
    }
    return Container(
      height: 640,
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: _columns
            .map((c) => Expanded(child: _buildColumn(c, inner: true)))
            .toList(),
      ),
    );
  }

  Widget _buildColumn(_KanbanColumn col, {bool inner = false}) {
    final cards = _cardsByColumn[col.id] ?? [];
    final wipExceeded = cards.length > col.wipLimit && col.wipLimit < 999;
    return Container(
      decoration: inner
          ? BoxDecoration(
              border: Border(
                right: col.id != 'done'
                    ? const BorderSide(color: _kBorder, width: 1)
                    : BorderSide.none,
              ),
            )
          : BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              color: col.accent.withOpacity(0.08),
              borderRadius: inner
                  ? null
                  : const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: col.accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(col.title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kHeadline)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: col.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${cards.length}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: col.accent)),
                ),
                const Spacer(),
                if (col.wipLimit < 999)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        wipExceeded ? Icons.warning_amber_rounded : Icons.check,
                        size: 12,
                        color: wipExceeded
                            ? Colors.red
                            : Colors.green,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'WIP ${col.wipLimit}',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: wipExceeded ? Colors.red : _kMuted),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (wipExceeded)
            Container(
              margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'WIP limit exceeded — pull blocked',
                style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w600),
              ),
            ),
          Expanded(
            child: DragTarget<_KanbanCard>(
              onAcceptWithDetails: (details) {
                _moveCard(details.data, details.data.columnId, col.id);
              },
              builder: (ctx, candidate, rejected) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  child: ListView(
                    children: [
                      if (candidate.isNotEmpty)
                        Container(
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: col.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ...cards.map((c) => Draggable<_KanbanCard>(
                            data: c,
                            feedback: SizedBox(
                              width: 220,
                              child: Material(
                                elevation: 8,
                                borderRadius: BorderRadius.circular(10),
                                child: _buildCard(c, col),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.4,
                              child: _buildCard(c, col),
                            ),
                            child: _buildCard(c, col),
                          )),
                      if (cards.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 24, horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: _kBorder,
                                style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text('Drop stories here',
                                style: TextStyle(
                                    fontSize: 12, color: _kMuted)),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(_KanbanCard card, _KanbanColumn col) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showCardDetail(card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _priorityDot(card.priority),
                const SizedBox(width: 6),
                Text(card.id,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _kMuted)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: _kAccentBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${card.points}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _kAccent)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(card.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _kHeadline,
                    height: 1.3)),
            const SizedBox(height: 8),
            if (card.tags.isNotEmpty) ...[
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: card.tags
                    .take(2)
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(t,
                              style: const TextStyle(
                                  fontSize: 10, color: _kMuted)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: col.accent.withOpacity(0.2),
                  child: Text(
                    card.assignee.isNotEmpty
                        ? card.assignee.split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join()
                        : '?',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: col.accent),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(card.assignee,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: _kMuted)),
                ),
                Icon(Icons.drag_indicator, size: 14, color: _kMuted),
              ],
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
          label: Text(_isSaving ? 'Saving…' : 'Save Board'),
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
          label: const Text('Reload'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _kAccent,
            side: const BorderSide(color: _kAccent),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const Spacer(),
        Text('Drag cards between columns to update workflow',
            style: TextStyle(fontSize: 12, color: _kMuted, fontStyle: FontStyle.italic)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Helper models
// ═══════════════════════════════════════════════════════════════════════════
class _KanbanColumn {
  final String id;
  final String title;
  final Color accent;
  final int wipLimit;
  const _KanbanColumn({
    required this.id,
    required this.title,
    required this.accent,
    required this.wipLimit,
  });
}

class _KanbanCard {
  final String id;
  final String title;
  final String description;
  final int points;
  final String assignee;
  final String priority;
  final String columnId;
  final List<String> tags;
  const _KanbanCard({
    required this.id,
    required this.title,
    required this.description,
    required this.points,
    required this.assignee,
    required this.priority,
    required this.columnId,
    required this.tags,
  });

  _KanbanCard copyWith({
    String? columnId,
    String? title,
    String? description,
    int? points,
    String? assignee,
    String? priority,
    List<String>? tags,
  }) =>
      _KanbanCard(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        points: points ?? this.points,
        assignee: assignee ?? this.assignee,
        priority: priority ?? this.priority,
        columnId: columnId ?? this.columnId,
        tags: tags ?? this.tags,
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
            Text('Loading kanban board…',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
