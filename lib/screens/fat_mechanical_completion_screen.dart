import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:ndu_project/screens/contract_close_out_screen.dart';
import 'package:ndu_project/screens/transition_to_prod_team_screen.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_notes_section.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';

/// Section 3 — FAT, Mechanical Completion & Commission Solution
///
/// Engineering, Construction, Manufacturing & Installation projects.
/// Supports the complete turnover from construction to operational ownership.
///
/// Subsections:
///   1. Mechanical Completion
///   2. FAT / SAT / Commissioning
///   3. Final Turnover
class FatMechanicalCompletionScreen extends StatefulWidget {
  const FatMechanicalCompletionScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FatMechanicalCompletionScreen()),
    );
  }

  @override
  State<FatMechanicalCompletionScreen> createState() =>
      _FatMechanicalCompletionScreenState();
}

class _FatMechanicalCompletionScreenState
    extends State<FatMechanicalCompletionScreen> {
  final TextEditingController _notesController = TextEditingController();

  // Subsection 1 — Mechanical Completion
  final List<_CompletionItem> _mechanicalCompletionItems = [];
  // Subsection 2 — FAT / SAT / Commissioning
  final List<_CompletionItem> _fatSatCommissioningItems = [];
  // Subsection 3 — Final Turnover
  final List<_CompletionItem> _finalTurnoverItems = [];

  bool _isLoading = true;
  bool _hasLoaded = false;
  bool _suspendSave = false;

  @override
  void initState() {
    super.initState();
    _notesController.addListener(_scheduleSave);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String? get _projectId => ProjectDataHelper.getData(context).projectId;

  void _scheduleSave() {
    if (_suspendSave || !_hasLoaded) return;
    Future.microtask(() {
      if (mounted) _persistData();
    });
  }

  Future<void> _loadData() async {
    if (_hasLoaded || _projectId == null) return;
    _suspendSave = true;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(_projectId!)
          .collection('execution_phase_sections')
          .doc('fat_mechanical_completion')
          .get();
      final data = doc.data() ?? {};

      final mech = _CompletionItem.fromList(data['mechanicalCompletion']);
      final fatSat = _CompletionItem.fromList(data['fatSatCommissioning']);
      final turnover = _CompletionItem.fromList(data['finalTurnover']);
      final notes = data['notes']?.toString() ?? '';

      if (!mounted) return;
      setState(() {
        _mechanicalCompletionItems
          ..clear()
          ..addAll(mech.isEmpty ? _defaultMechanicalCompletion() : mech);
        _fatSatCommissioningItems
          ..clear()
          ..addAll(fatSat.isEmpty ? _defaultFatSat() : fatSat);
        _finalTurnoverItems
          ..clear()
          ..addAll(turnover.isEmpty ? _defaultFinalTurnover() : turnover);
        _notesController.text = notes;
        _isLoading = false;
        _hasLoaded = true;
      });
    } catch (e) {
      debugPrint('FAT Mechanical Completion load error: $e');
      if (mounted) {
        setState(() {
          _mechanicalCompletionItems
              .addAll(_defaultMechanicalCompletion());
          _fatSatCommissioningItems.addAll(_defaultFatSat());
          _finalTurnoverItems.addAll(_defaultFinalTurnover());
          _isLoading = false;
          _hasLoaded = true;
        });
      }
    }
    _suspendSave = false;
  }

  Future<void> _persistData() async {
    if (_projectId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(_projectId!)
          .collection('execution_phase_sections')
          .doc('fat_mechanical_completion')
          .set({
        'mechanicalCompletion':
            _mechanicalCompletionItems.map((e) => e.toMap()).toList(),
        'fatSatCommissioning':
            _fatSatCommissioningItems.map((e) => e.toMap()).toList(),
        'finalTurnover': _finalTurnoverItems.map((e) => e.toMap()).toList(),
        'notes': _notesController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FAT Mechanical Completion save error: $e');
    }
  }

  // ── Default seed rows ────────────────────────────────────────────

  List<_CompletionItem> _defaultMechanicalCompletion() => const [
        _CompletionItem(label: 'Mechanical Completion Packages', status: 'Pending'),
        _CompletionItem(label: 'Turnover Packages', status: 'Pending'),
        _CompletionItem(label: 'Equipment Status', status: 'Pending'),
        _CompletionItem(label: 'System Completion', status: 'Pending'),
        _CompletionItem(label: 'Construction Walkdowns', status: 'Pending'),
        _CompletionItem(label: 'Construction Work Package References', status: 'Pending'),
        _CompletionItem(label: 'Execution Work Package References', status: 'Pending'),
      ];

  List<_CompletionItem> _defaultFatSat() => const [
        _CompletionItem(label: 'Factory Acceptance Tests (FAT)', status: 'Pending'),
        _CompletionItem(label: 'Site Acceptance Tests (SAT)', status: 'Pending'),
        _CompletionItem(label: 'Commissioning Activities', status: 'Pending'),
        _CompletionItem(label: 'Functional Testing', status: 'Pending'),
        _CompletionItem(label: 'Integrated System Testing', status: 'Pending'),
        _CompletionItem(label: 'Performance Verification', status: 'Pending'),
        _CompletionItem(label: 'Operational Readiness', status: 'Pending'),
      ];

  List<_CompletionItem> _defaultFinalTurnover() => const [
        _CompletionItem(label: 'Punch List Closeout', status: 'Pending'),
        _CompletionItem(label: 'As-Built Drawings', status: 'Pending'),
        _CompletionItem(label: 'Operating Manuals', status: 'Pending'),
        _CompletionItem(label: 'Equipment Handover', status: 'Pending'),
        _CompletionItem(label: 'Asset Registration', status: 'Pending'),
        _CompletionItem(label: 'Owner Acceptance', status: 'Pending'),
        _CompletionItem(label: 'Final Certificates', status: 'Pending'),
      ];

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.sizeOf(context).width < 980;

    return ResponsiveScaffold(
      activeItemLabel: '3. FAT, Mechanical Completion & Commission Solution',
      backgroundColor: Colors.white,
      floatingActionButton: const KazAiChatBubble(positioned: false),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 32,
          vertical: isMobile ? 16 : 28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading) const LinearProgressIndicator(minHeight: 2),
            const PlanningPhaseHeader(
              title: 'FAT, Mechanical Completion & Commission Solution',
              showNavigationButtons: false,
              showActivityLogAction: false,
            ),
            const SizedBox(height: 12),
            _buildIntroPanel(),
            const SizedBox(height: 16),
            _buildSubsectionPanel(
              title: 'Mechanical Completion',
              description:
                  'Track mechanical completion packages, turnover packages, equipment status, system completion, walkdowns, and work package references.',
              items: _mechanicalCompletionItems,
              onStatusChanged: (index, status) {
                setState(() {
                  _mechanicalCompletionItems[index] =
                      _mechanicalCompletionItems[index].copyWith(status: status);
                });
                _scheduleSave();
              },
            ),
            const SizedBox(height: 16),
            _buildSubsectionPanel(
              title: 'FAT / SAT / Commissioning',
              description:
                  'Factory Acceptance Tests, Site Acceptance Tests, commissioning activities, functional testing, integrated system testing, performance verification, and operational readiness.',
              items: _fatSatCommissioningItems,
              onStatusChanged: (index, status) {
                setState(() {
                  _fatSatCommissioningItems[index] =
                      _fatSatCommissioningItems[index].copyWith(status: status);
                });
                _scheduleSave();
              },
            ),
            const SizedBox(height: 16),
            _buildSubsectionPanel(
              title: 'Final Turnover',
              description:
                  'Punch list closeout, as-built drawings, operating manuals, equipment handover, asset registration, owner acceptance, and final certificates.',
              items: _finalTurnoverItems,
              onStatusChanged: (index, status) {
                setState(() {
                  _finalTurnoverItems[index] =
                      _finalTurnoverItems[index].copyWith(status: status);
                });
                _scheduleSave();
              },
            ),
            const SizedBox(height: 16),
            LaunchNotesSection(
              controller: _notesController,
              onChanged: (v) {},
            ),
            const SizedBox(height: 24),
            LaunchPhaseNavigation(
              backLabel: 'Back: Deployment Transfer, Certification & Release',
              nextLabel: 'Next: Vendor & Contract Closeout',
              onBack: () => TransitionToProdTeamScreen.open(context),
              onNext: () => ContractCloseOutScreen.open(context),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.engineering, color: Color(0xFFD97706), size: 22),
              SizedBox(width: 10),
              Text(
                'Engineering, Construction, Manufacturing & Installation Projects',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'This section supports the complete turnover from construction to operational ownership. '
            'It tracks mechanical completion, FAT/SAT commissioning, and final turnover to formally hand over the asset to operations.',
            style: TextStyle(fontSize: 13, color: Color(0xFF78350F), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSubsectionPanel({
    required String title,
    required String description,
    required List<_CompletionItem> items,
    required void Function(int index, String status) onStatusChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
          ),
          const SizedBox(height: 14),
          ...items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      item.label,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _StatusDropdown(
                      value: item.status,
                      onChanged: (v) => onStatusChanged(i, v),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Simple status dropdown used by the FAT screen.
class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({required this.value, required this.onChanged});

  final String value;
  final void Function(String) onChanged;

  static const _statuses = [
    'Pending',
    'In Progress',
    'Complete',
    'Not Applicable',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, size: 18, color: Color(0xFF6B7280)),
          style: const TextStyle(fontSize: 12, color: Color(0xFF1F2937)),
          items: _statuses
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

/// Lightweight model used by the FAT screen for tracking item statuses.
class _CompletionItem {
  final String label;
  final String status;

  const _CompletionItem({required this.label, required this.status});

  _CompletionItem copyWith({String? label, String? status}) => _CompletionItem(
        label: label ?? this.label,
        status: status ?? this.status,
      );

  Map<String, dynamic> toMap() => {'label': label, 'status': status};

  static List<_CompletionItem> fromList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) {
          if (e is Map) {
            return _CompletionItem(
              label: e['label']?.toString() ?? '',
              status: e['status']?.toString() ?? 'Pending',
            );
          }
          return null;
        })
        .whereType<_CompletionItem>()
        .toList(growable: true);
  }
}
