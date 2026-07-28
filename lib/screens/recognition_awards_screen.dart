import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// RECOGNITION & AWARDS
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Celebrate project achievements by recognizing individuals and teams for
/// outstanding contributions throughout the project lifecycle.
class RecognitionAwardsScreen extends StatefulWidget {
  const RecognitionAwardsScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RecognitionAwardsScreen()),
    );
  }

  @override
  State<RecognitionAwardsScreen> createState() => _RecognitionAwardsScreenState();
}

class _RecognitionAwardsScreenState extends State<RecognitionAwardsScreen> {
  bool _isLoading = true;
  bool _hasLoaded = false;
  List<_Recognition> _recognitions = [];

  String? get _projectId => ProjectDataHelper.getData(context).projectId;

  static const List<String> _awardCategories = [
    'Project Excellence',
    'Delivery Champion',
    'Collaboration Award',
    'Innovation Award',
    'Customer Impact Award',
    'Leadership Excellence',
    'Problem Solver Award',
    'Rising Star',
    'Quality Excellence',
    'Continuous Improvement Champion',
  ];

  static const List<String> _recognitionTypes = [
    'Milestone Achievement',
    'Innovation Award',
    'Collaboration Award',
    'Leadership Recognition',
    'Knowledge Sharing Award',
    'Customer Appreciation',
    'Team Success Award',
    'Project Completion Recognition',
  ];

  static const List<String> _statuses = [
    'Nominated',
    'Approved',
    'Rejected',
    'Awarded',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
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
          .doc('recognition_awards')
          .get();
      final data = doc.data() ?? {};
      final list = data['recognitions'] as List? ?? [];
      _recognitions = list
          .map((e) => _Recognition.fromMap(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Recognition Awards load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveData() async {
    if (_projectId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(_projectId!)
          .collection('execution_phase_entries')
          .doc('recognition_awards')
          .set({
        'recognitions': _recognitions.map((r) => r.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Recognition Awards save error: $e');
    }
  }

  void _addRecognition() {
    _showRecognitionDialog();
  }

  void _editRecognition(int index) {
    _showRecognitionDialog(editIndex: index, existing: _recognitions[index]);
  }

  void _deleteRecognition(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recognition'),
        content: const Text('Are you sure you want to delete this recognition?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() => _recognitions.removeAt(index));
              _saveData();
              Navigator.of(ctx).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showRecognitionDialog({int? editIndex, _Recognition? existing}) {
    final categoryCtrl =
        TextEditingController(text: existing?.category ?? _awardCategories.first);
    final recipientCtrl = TextEditingController(text: existing?.recipient ?? '');
    final teamCtrl = TextEditingController(text: existing?.team ?? '');
    final nominatedByCtrl =
        TextEditingController(text: existing?.nominatedBy ?? '');
    final dateCtrl = TextEditingController(text: existing?.date ?? '');
    final evidenceCtrl = TextEditingController(text: existing?.evidence ?? '');
    final commentsCtrl = TextEditingController(text: existing?.comments ?? '');
    final linkedMilestoneCtrl =
        TextEditingController(text: existing?.linkedMilestone ?? '');
    String status = existing?.status ?? 'Nominated';
    String type = existing?.type ?? _recognitionTypes.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(editIndex != null ? 'Edit Recognition' : 'New Recognition'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogDropdown('Award Category', categoryCtrl, _awardCategories),
                  const SizedBox(height: 12),
                  _dialogDropdown('Recognition Type', null, _recognitionTypes,
                      value: type, onChanged: (v) => setDialogState(() => type = v!)),
                  const SizedBox(height: 12),
                  _dialogField('Recipient Name', recipientCtrl),
                  const SizedBox(height: 12),
                  _dialogField('Team', teamCtrl),
                  const SizedBox(height: 12),
                  _dialogField('Nominated By', nominatedByCtrl),
                  const SizedBox(height: 12),
                  _dialogField('Date', dateCtrl),
                  const SizedBox(height: 12),
                  _dialogField('Linked Milestone/Deliverable', linkedMilestoneCtrl),
                  const SizedBox(height: 12),
                  _dialogDropdown('Status', null, _statuses,
                      value: status, onChanged: (v) => setDialogState(() => status = v!)),
                  const SizedBox(height: 12),
                  _dialogField('Evidence', evidenceCtrl, maxLines: 2),
                  const SizedBox(height: 12),
                  _dialogField('Comments', commentsCtrl, maxLines: 3),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final recognition = _Recognition(
                  category: categoryCtrl.text,
                  type: type,
                  recipient: recipientCtrl.text,
                  team: teamCtrl.text,
                  nominatedBy: nominatedByCtrl.text,
                  date: dateCtrl.text,
                  evidence: evidenceCtrl.text,
                  comments: commentsCtrl.text,
                  linkedMilestone: linkedMilestoneCtrl.text,
                  status: status,
                );
                setState(() {
                  if (editIndex != null) {
                    _recognitions[editIndex] = recognition;
                  } else {
                    _recognitions.add(recognition);
                  }
                });
                _saveData();
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B)),
              child: const Text('Save',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: Color(0xFFD1D5DB)),
            ),
            contentPadding: const EdgeInsets.all(10),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  Widget _dialogDropdown(String label, TextEditingController? controller,
      List<String> items,
      {String? value, ValueChanged<String?>? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value ?? (controller != null ? controller.text : null),
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged ??
              (v) {
                if (v != null && controller != null) controller.text = v;
              },
          decoration: const InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: Color(0xFFD1D5DB)),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = AppBreakpoints.isMobile(context);
    final double horizontalPadding = isMobile ? 18 : 32;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: const InitiationLikeSidebar(
                  activeItemLabel: 'Project Team Activities - Recognition & Awards'),
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
                          title: 'Recognition & Awards',
                          showNavigationButtons: false,
                          showActivityLogAction: false,
                        ),
                        const SizedBox(height: 20),
                        _buildIntroCard(),
                        const SizedBox(height: 24),
                        _buildStatsRow(),
                        const SizedBox(height: 24),
                        _buildCategoriesChips(),
                        const SizedBox(height: 24),
                        _buildRecognitionsList(),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                      activeItemLabel:
                          'Project Team Activities - Recognition & Awards',
                    ),
                  ),
                  const KazAiChatBubble(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRecognition,
        backgroundColor: const Color(0xFFF59E0B),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Recognition'),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emoji_events,
                    color: Color(0xFFD97706), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Celebrate Project Achievements',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Recognize individuals and teams for outstanding contributions throughout the project lifecycle. '
            'Reinforces positive behaviors, improves engagement, and fosters a culture of accountability, '
            'collaboration, and continuous improvement.',
            style: TextStyle(fontSize: 13, color: Color(0xFF78350F), height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final awarded = _recognitions.where((r) => r.status == 'Awarded').length;
    final nominated = _recognitions.where((r) => r.status == 'Nominated').length;
    final approved = _recognitions.where((r) => r.status == 'Approved').length;

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 900;
      final stats = [
        _StatCard('Total Recognitions', '${_recognitions.length}',
            Icons.emoji_events, const Color(0xFFF59E0B)),
        _StatCard('Awarded', '$awarded', Icons.verified,
            const Color(0xFF10B981)),
        _StatCard('Approved', '$approved', Icons.check_circle,
            const Color(0xFFFBBF24)),
        _StatCard('Nominated', '$nominated', Icons.star,
            const Color(0xFF8B5CF6)),
      ];
      if (isWide) {
        return Row(
          children: [
            for (int i = 0; i < stats.length; i++) ...[
              Expanded(child: stats[i]),
              if (i < stats.length - 1) const SizedBox(width: 16),
            ],
          ],
        );
      }
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: stats
            .map((s) => SizedBox(
                  width: (constraints.maxWidth - 16) / 2,
                  child: s,
                ))
            .toList(),
      );
    });
  }

  Widget _buildCategoriesChips() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sample Award Categories',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827))),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _awardCategories.map((cat) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(cat,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecognitionsList() {
    if (_recognitions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Icon(Icons.emoji_events_outlined,
                size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No recognitions yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280))),
            const SizedBox(height: 8),
            const Text('Click "New Recognition" to nominate someone',
                style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recognition History',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827))),
        const SizedBox(height: 16),
        ..._recognitions.asMap().entries.map((entry) {
          final index = entry.key;
          final r = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildRecognitionCard(index, r),
          );
        }),
      ],
    );
  }

  Widget _buildRecognitionCard(int index, _Recognition r) {
    final statusColor = r.status == 'Awarded'
        ? const Color(0xFF10B981)
        : r.status == 'Approved'
            ? const Color(0xFFFBBF24)
            : r.status == 'Rejected'
                ? const Color(0xFFEF4444)
                : const Color(0xFF8B5CF6);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.emoji_events,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.category,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827))),
                    const SizedBox(height: 2),
                    Text('${r.recipient}${r.team.isNotEmpty ? ' • ${r.team}' : ''}',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(r.status,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor)),
              ),
            ],
          ),
          if (r.comments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(r.comments,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF4B5563), height: 1.5)),
            ),
          ],
          if (r.nominatedBy.isNotEmpty || r.date.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${r.nominatedBy.isNotEmpty ? 'Nominated by ${r.nominatedBy}' : ''}'
              '${r.nominatedBy.isNotEmpty && r.date.isNotEmpty ? ' • ' : ''}'
              '${r.date.isNotEmpty ? r.date : ''}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () => _editRecognition(index),
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.redAccent),
                onPressed: () => _deleteRecognition(index),
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827))),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Recognition {
  final String category;
  final String type;
  final String recipient;
  final String team;
  final String nominatedBy;
  final String date;
  final String evidence;
  final String comments;
  final String linkedMilestone;
  final String status;

  _Recognition({
    required this.category,
    required this.type,
    required this.recipient,
    required this.team,
    required this.nominatedBy,
    required this.date,
    required this.evidence,
    required this.comments,
    required this.linkedMilestone,
    required this.status,
  });

  Map<String, dynamic> toMap() => {
        'category': category,
        'type': type,
        'recipient': recipient,
        'team': team,
        'nominatedBy': nominatedBy,
        'date': date,
        'evidence': evidence,
        'comments': comments,
        'linkedMilestone': linkedMilestone,
        'status': status,
      };

  factory _Recognition.fromMap(Map<String, dynamic> m) => _Recognition(
        category: m['category'] ?? '',
        type: m['type'] ?? '',
        recipient: m['recipient'] ?? '',
        team: m['team'] ?? '',
        nominatedBy: m['nominatedBy'] ?? '',
        date: m['date'] ?? '',
        evidence: m['evidence'] ?? '',
        comments: m['comments'] ?? '',
        linkedMilestone: m['linkedMilestone'] ?? '',
        status: m['status'] ?? 'Nominated',
      );
}
