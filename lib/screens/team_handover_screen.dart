import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:go_router/go_router.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TEAM HANDOVER CHECKLIST
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Checklist for team handover when a team member is demobilizing from the
/// project. Ensures all responsibilities, knowledge, and project work are
/// successfully transferred before a team member leaves.
class TeamHandoverScreen extends StatefulWidget {
  const TeamHandoverScreen({super.key});

  static void open(BuildContext context) {
    context.push('/team-handover');
  }

  @override
  State<TeamHandoverScreen> createState() => _TeamHandoverScreenState();
}

class _TeamHandoverScreenState extends State<TeamHandoverScreen> {
  bool _isLoading = true;
  bool _hasLoaded = false;

  // Checklist items: category -> list of items (each item: {text, checked})
  final Map<String, List<_ChecklistItem>> _checklist = {};
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _teamMemberController = TextEditingController();
  final TextEditingController _receivingMemberController =
      TextEditingController();
  final TextEditingController _projectManagerController =
      TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  String? get _projectId => ProjectDataHelper.getData(context).projectId;

  static const Map<String, List<String>> _defaultChecklist = {
    '1. Work & Deliverables': [
      'Current responsibilities documented',
      'Assigned work packages / epics / tasks transferred',
      'Deliverables status updated',
      'Outstanding work identified',
      'Priorities communicated',
    ],
    '2. Documentation & Knowledge Transfer': [
      'Project documentation updated',
      'Key processes explained',
      'Critical contacts shared',
      'Knowledge transfer session completed',
      'Questions answered',
    ],
    '3. Risks & Open Items': [
      'Open risks reviewed',
      'Open issues discussed',
      'Pending decisions documented',
      'Action items reassigned',
      'Dependencies communicated',
    ],
    '4. Systems & Stakeholder Transition': [
      'Project files organized',
      'Required system access transferred or removed',
      'Stakeholders notified',
      'Replacement/team member introduced',
      'Final handover meeting completed',
    ],
  };

  @override
  void initState() {
    super.initState();
    _initChecklist();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _initChecklist() {
    _checklist.clear();
    _defaultChecklist.forEach((category, items) {
      _checklist[category] = items
          .map((text) => _ChecklistItem(text: text, checked: false))
          .toList();
    });
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _teamMemberController.dispose();
    _receivingMemberController.dispose();
    _projectManagerController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_hasLoaded || _projectId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(_projectId!)
          .collection('execution_phase_entries')
          .doc('team_handover')
          .get();
      final data = doc.data() ?? {};

      if (data.isNotEmpty) {
        final savedChecklist = data['checklist'] as Map<String, dynamic>?;
        if (savedChecklist != null) {
          _checklist.clear();
          savedChecklist.forEach((category, items) {
            if (items is List) {
              _checklist[category] = items
                  .map((item) => _ChecklistItem(
                        text: (item as Map<String, dynamic>)['text'] ?? '',
                        checked: (item['checked'] ?? false) as bool,
                      ))
                  .toList();
            }
          });
        }
        _summaryController.text = data['summary']?.toString() ?? '';
        _teamMemberController.text = data['teamMember']?.toString() ?? '';
        _receivingMemberController.text =
            data['receivingMember']?.toString() ?? '';
        _projectManagerController.text =
            data['projectManager']?.toString() ?? '';
        _dateController.text = data['date']?.toString() ?? '';
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Team Handover load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveData() async {
    if (_projectId == null) return;
    try {
      final checklistJson = <String, dynamic>{};
      _checklist.forEach((category, items) {
        checklistJson[category] = items
            .map((item) => {'text': item.text, 'checked': item.checked})
            .toList();
      });

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(_projectId!)
          .collection('execution_phase_entries')
          .doc('team_handover')
          .set({
        'checklist': checklistJson,
        'summary': _summaryController.text.trim(),
        'teamMember': _teamMemberController.text.trim(),
        'receivingMember': _receivingMemberController.text.trim(),
        'projectManager': _projectManagerController.text.trim(),
        'date': _dateController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Team Handover save error: $e');
    }
  }

  void _toggleItem(String category, int index) {
    setState(() {
      _checklist[category]![index].checked =
          !_checklist[category]![index].checked;
    });
    _saveData();
  }

  int _getCompletedCount() {
    int count = 0;
    _checklist.forEach((_, items) {
      for (final item in items) {
        if (item.checked) count++;
      }
    });
    return count;
  }

  int _getTotalCount() {
    int count = 0;
    _checklist.forEach((_, items) {
      count += items.length;
    });
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = AppBreakpoints.isMobile(context);
    final double horizontalPadding = isMobile ? 18 : 32;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: const InitiationLikeSidebar(
                  activeItemLabel: 'Project Team Activities - Team Handover'),
            ),
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding, vertical: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isLoading)
                          const LinearProgressIndicator(minHeight: 2),
                        if (_isLoading) const SizedBox(height: 16),
                        const PlanningPhaseHeader(
                          title: 'Team Handover Checklist',
                          showNavigationButtons: false,
                          showActivityLogAction: false,
                        ),
                        const SizedBox(height: 20),
                        _buildIntroCard(),
                        const SizedBox(height: 24),
                        _buildProgressCard(),
                        const SizedBox(height: 24),
                        ..._checklist.entries.map((entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: _buildCategoryCard(entry.key, entry.value),
                            )),
                        const SizedBox(height: 24),
                        _buildSummaryCard(),
                        const SizedBox(height: 24),
                        _buildSignOffCard(),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                  const MobileSidebarHamburger(
                    sidebar: InitiationLikeSidebar(
                      activeItemLabel:
                          'Project Team Activities - Team Handover',
                    ),
                  ),
                  const KazAiChatBubble(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.swap_horiz,
                    color: Color(0xFFD97706), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Team Member Handover Checklist',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Purpose: Ensure all responsibilities, knowledge, and project work are '
            'successfully transferred before a team member leaves the project.\n\n'
            'This streamlined version is methodology-neutral, making it suitable for '
            'Agile, Waterfall, and Hybrid projects by referring generically to '
            '"work packages, epics, or tasks" rather than prescribing a specific delivery approach.',
            style:
                TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final completed = _getCompletedCount();
    final total = _getTotalCount();
    final percent = total > 0 ? (completed / total * 100).round() : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Handover Progress',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827)),
              ),
              const Spacer(),
              Text(
                '$completed / $total items',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total > 0 ? completed / total : 0,
              minHeight: 12,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(
                percent == 100
                    ? const Color(0xFF10B981)
                    : const Color(0xFFD97706),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$percent% complete',
            style: TextStyle(
              fontSize: 12,
              color: percent == 100
                  ? const Color(0xFF10B981)
                  : const Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String category, List<_ChecklistItem> items) {
    final completed = items.where((i) => i.checked).length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                category,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: completed == items.length
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$completed/${items.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: completed == items.length
                        ? const Color(0xFF059669)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _toggleItem(category, index),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: item.checked
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.checked
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color: item.checked
                            ? const Color(0xFF10B981)
                            : const Color(0xFF9CA3AF),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.text,
                          style: TextStyle(
                            fontSize: 14,
                            color: item.checked
                                ? const Color(0xFF065F46)
                                : const Color(0xFF374151),
                            decoration: item.checked
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Handover Summary',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _summaryController,
            maxLines: 5,
            onChanged: (_) => _saveData(),
            decoration: const InputDecoration(
              hintText:
                  'Summarize the handover — key items transferred, outstanding items, special notes...',
              hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: Color(0xFFD97706)),
              ),
              contentPadding: EdgeInsets.all(12),
            ),
            style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOffCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFFCD34D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sign-Off',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827)),
          ),
          const SizedBox(height: 16),
          _signOffField('Team Member', _teamMemberController),
          const SizedBox(height: 12),
          _signOffField('Receiving Team Member', _receivingMemberController),
          const SizedBox(height: 12),
          _signOffField('Project Manager', _projectManagerController),
          const SizedBox(height: 12),
          _signOffField('Date', _dateController),
        ],
      ),
    );
  }

  Widget _signOffField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: (_) => _saveData(),
          decoration: InputDecoration(
            hintText: label == 'Date' ? 'YYYY-MM-DD' : 'Enter full name',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFF59E0B), width: 1.6),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
        ),
      ],
    );
  }
}

class _ChecklistItem {
  final String text;
  bool checked;

  _ChecklistItem({required this.text, required this.checked});
}
