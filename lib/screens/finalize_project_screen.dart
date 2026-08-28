import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/widgets/csv_import_dialog.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/widgets/wrapped_table_primitives.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/widgets/delete_success_snackbar.dart';
class FinalizeProjectScreen extends StatefulWidget {
  const FinalizeProjectScreen({super.key});

  static void open(BuildContext context) {
    context.push('/finalize-project');
  }

  @override
  State<FinalizeProjectScreen> createState() => _FinalizeProjectScreenState();
}

class _FinalizeProjectScreenState extends State<FinalizeProjectScreen> {
  final TextEditingController _summaryTitleController = TextEditingController();
  final TextEditingController _summaryDescriptionController =
      TextEditingController();
  final TextEditingController _readinessPercentController =
      TextEditingController();
  final TextEditingController _closeoutWindowController =
      TextEditingController();
  final TextEditingController _finalNotesController = TextEditingController();
  final TextEditingController _nextStepsController = TextEditingController();

  final List<_HeroStatItem> _heroStats = [];
  final List<_SnapshotMetric> _snapshotMetrics = [];
  bool _isEditingSnapshot = false;
  final List<_ChecklistItem> _checklist = [];
  final List<_SignOffItem> _signOffs = [];
  final List<_InsightItem> _insights = [];

  String _finalizationStatus = 'In progress';
  bool _isLoading = false;
  bool _suspendSave = false;

  final _Debouncer _saveDebouncer = _Debouncer();

  static const List<String> _finalizationStatuses = [
    'Not started',
    'In progress',
    'At risk',
    'Ready to finalize'
  ];
  static const List<String> _checklistStatuses = [
    'Not started',
    'In progress',
    'Blocked',
    'Done'
  ];
  static const List<String> _signOffStatuses = [
    'Pending',
    'Approved',
    'Rejected',
    'Deferred'
  ];

  @override
  void initState() {
    super.initState();
    _registerListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFromFirestore());
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Finalize Project',
      sections: [
        PdfSection.keyValue('Project Info', [
          {'Project Name': projectData.projectName ?? 'N/A'},
        ]),
        PdfSection.text(
            'Notes',
            projectData.planningNotes['finalize_project_screen'] ??
                'No data recorded.'),
      ],
    );
  }

  @override
  void dispose() {
    _summaryTitleController.dispose();
    _summaryDescriptionController.dispose();
    _readinessPercentController.dispose();
    _closeoutWindowController.dispose();
    _finalNotesController.dispose();
    _nextStepsController.dispose();
    _saveDebouncer.dispose();
    super.dispose();
  }

  String? _projectId() => ProjectDataHelper.getData(context).projectId;

  void _registerListeners() {
    final controllers = [
      _summaryTitleController,
      _summaryDescriptionController,
      _readinessPercentController,
      _closeoutWindowController,
      _finalNotesController,
      _nextStepsController,
    ];
    for (final controller in controllers) {
      controller.addListener(_scheduleSave);
    }
  }

  void _scheduleSave() {
    if (_suspendSave) return;
    _saveDebouncer.run(_saveToFirestore);
  }

  Future<void> _loadFromFirestore() async {
    final projectId = _projectId();
    if (projectId == null || projectId.isEmpty) return;
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_sections')
          .doc('finalize_project')
          .get();
      final data = doc.data() ?? {};
      final summary = Map<String, dynamic>.from(data['summary'] ?? {});
      final actions = Map<String, dynamic>.from(data['actions'] ?? {});

      _suspendSave = true;
      _summaryTitleController.text = summary['title']?.toString() ?? '';
      _summaryDescriptionController.text =
          summary['description']?.toString() ?? '';
      _readinessPercentController.text =
          summary['readinessPercent']?.toString() ?? '';
      _closeoutWindowController.text =
          summary['closeoutWindow']?.toString() ?? '';
      _finalizationStatus = _normalizeStatus(
          summary['status']?.toString(), _finalizationStatuses);
      _finalNotesController.text = actions['finalNotes']?.toString() ?? '';
      _nextStepsController.text = actions['nextSteps']?.toString() ?? '';
      _suspendSave = false;

      final heroStats = _HeroStatItem.fromList(data['heroStats']);
      final snapshotMetrics = _SnapshotMetric.fromList(data['snapshotMetrics']);
      final checklist = _ChecklistItem.fromList(data['checklist']);
      final signOffs = _SignOffItem.fromList(data['signOffs']);
      final insights = _InsightItem.fromList(data['insights']);

      if (!mounted) return;
      setState(() {
        _heroStats
          ..clear()
          ..addAll(heroStats.isEmpty ? _defaultHeroStats() : heroStats);
        _snapshotMetrics
          ..clear()
          ..addAll(snapshotMetrics.isEmpty
              ? _defaultSnapshotMetrics()
              : snapshotMetrics);
        _checklist
          ..clear()
          ..addAll(checklist);
        _signOffs
          ..clear()
          ..addAll(signOffs);
        _insights
          ..clear()
          ..addAll(insights);
      });
    } catch (error) {
      debugPrint('Finalize Project load error: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveToFirestore() async {
    final projectId = _projectId();
    if (projectId == null || projectId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_sections')
          .doc('finalize_project')
          .set({
        'summary': {
          'title': _summaryTitleController.text.trim(),
          'description': _summaryDescriptionController.text.trim(),
          'readinessPercent': _readinessPercentController.text.trim(),
          'closeoutWindow': _closeoutWindowController.text.trim(),
          'status': _finalizationStatus,
        },
        'heroStats': _heroStats.map((e) => e.toMap()).toList(),
        'snapshotMetrics': _snapshotMetrics.map((e) => e.toMap()).toList(),
        'checklist': _checklist.map((e) => e.toMap()).toList(),
        'signOffs': _signOffs.map((e) => e.toMap()).toList(),
        'insights': _insights.map((e) => e.toMap()).toList(),
        'actions': {
          'finalNotes': _finalNotesController.text.trim(),
          'nextSteps': _nextStepsController.text.trim(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('Finalize Project save error: $error');
    }
  }

  List<_HeroStatItem> _defaultHeroStats() {
    return [
      _HeroStatItem(id: _newId(), label: 'Open approvals', value: ''),
      _HeroStatItem(id: _newId(), label: 'Final docs', value: ''),
      _HeroStatItem(id: _newId(), label: 'Risks to watch', value: ''),
      _HeroStatItem(id: _newId(), label: 'Ops readiness', value: ''),
    ];
  }

  List<_SnapshotMetric> _defaultSnapshotMetrics() {
    return [
      _SnapshotMetric(
        id: _newId(),
        title: 'Delivery Package',
        subtitle: 'Final artifacts and deployment notes',
        value: '',
        accent: const Color(0xFF16A34A),
      ),
      _SnapshotMetric(
        id: _newId(),
        title: 'Stakeholder Sign-off',
        subtitle: 'Pending approvals',
        value: '',
        accent: const Color(0xFFFFC812),
      ),
      _SnapshotMetric(
        id: _newId(),
        title: 'Budget Closure',
        subtitle: 'Variance vs. forecast',
        value: '',
        accent: const Color(0xFFF59E0B),
      ),
      _SnapshotMetric(
        id: _newId(),
        title: 'Ops Readiness',
        subtitle: 'Handover confidence',
        value: '',
        accent: const Color(0xFFB8860B),
      ),
    ];
  }

  String _normalizeStatus(String? value, List<String> options) {
    if (value == null || value.isEmpty) return options.first;
    for (final option in options) {
      if (option.toLowerCase() == value.toLowerCase()) return option;
    }
    return options.first;
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  @override
  Widget build(BuildContext context) {
    final double horizontalPadding = AppBreakpoints.isMobile(context) ? 20 : 40;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: const InitiationLikeSidebar(
                  activeItemLabel: 'Finalize Project'),
            ),
            Expanded(
              child: Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              PlanningPhaseHeader(
                                  title: 'Finalize Project',
                                  onExportPdf: _exportPdf),
                              const SizedBox(height: 16),
                              _buildOverviewCards(),
                              const SizedBox(height: 24),
                              if (_isLoading)
                                const Center(
                                    child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: CircularProgressIndicator(),
                                ))
                              else ...[
                                _buildSnapshotSection(context),
                                const SizedBox(height: 24),
                                _buildFinalizeChecklist(),
                                const SizedBox(height: 24),
                                _buildSignOffPanel(),
                                const SizedBox(height: 24),
                                _buildClosureInsights(context),
                                const SizedBox(height: 24),
                                _buildPremiumActionBar(context),
                              ],
                              const SizedBox(height: 48),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const MobileSidebarHamburger(
                    sidebar: InitiationLikeSidebar(
                      activeItemLabel: 'Finalize Project',
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

  Widget _buildOverviewCards() {
    return Row(
      children: [
        Expanded(
          child: _buildOverviewCard(
            title: 'Finalization Status',
            value: _finalizationStatus,
            icon: Icons.check_circle_outline,
            color: const Color(0xFF16A34A),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildOverviewCard(
            title: 'Snapshot Metrics',
            value: '${_snapshotMetrics.length}',
            icon: Icons.dashboard_outlined,
            color: const Color(0xFFFFC812),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildOverviewCard(
            title: 'Pending Checklists',
            value: '${_checklist.where((c) => c.status != 'Done').length}',
            icon: Icons.task_outlined,
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildOverviewCard(
            title: 'Sign-offs',
            value:
                '${_signOffs.where((s) => s.status == 'Approved').length}/${_signOffs.length}',
            icon: Icons.verified_outlined,
            color: const Color(0xFFB8860B),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildSnapshotSection(BuildContext context) {
 return _SectionCard(
 title: 'Finalization Snapshot',
 subtitle: 'Summarize readiness signals for leadership review.',
 icon: Icons.dashboard_outlined,
 trailing: OutlinedButton.icon(
 onPressed: () => setState(() => _isEditingSnapshot = !_isEditingSnapshot),
 icon: Icon(_isEditingSnapshot ? Icons.check : Icons.edit_outlined, size: 16),
 label: Text(_isEditingSnapshot ? 'Done' : 'Edit'),
 style: OutlinedButton.styleFrom(
 foregroundColor: _isEditingSnapshot ? const Color(0xFF10B981) : const Color(0xFF475569),
 side: BorderSide(color: _isEditingSnapshot ? const Color(0xFF10B981) : const Color(0xFFCBD5E1)),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (_isEditingSnapshot) ...[
 Row(
 children: [
 OutlinedButton.icon(
 onPressed: () async {
 final rows = await showCsvImportDialog(context, tableTitle: 'Snapshot', columns: [
 const CsvColumnSpec(key: 'title', label: 'Metric', sampleValue: 'Delivery Package'),
 const CsvColumnSpec(key: 'subtitle', label: 'Description', sampleValue: 'Final artifacts and deployment notes'),
 const CsvColumnSpec(key: 'value', label: 'Status', sampleValue: 'Ready'),
 ]);
 if (rows == null || !mounted) return;
 setState(() {
 _snapshotMetrics.clear();
 for (final r in rows) {
 _snapshotMetrics.add(_SnapshotMetric(
 id: _newId(),
 title: r['title'] ?? '',
 subtitle: r['subtitle'] ?? '',
 value: r['value'] ?? '',
 accent: const Color(0xFFFFC812),
 ));
 }
 });
 _scheduleSave();
 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${rows.length} metrics imported from CSV'), backgroundColor: Colors.green));
 },
 icon: const Icon(Icons.upload_file_outlined, size: 16),
 label: const Text('Import CSV'),
 style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), foregroundColor: const Color(0xFFFFC812), side: const BorderSide(color: Color(0xFFFFC812))),
 ),
 const SizedBox(width: 8),
 FilledButton.icon(
 onPressed: _addSnapshotMetric,
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add metric'),
 style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
 ),
 ],
 ),
 const SizedBox(height: 16),
 ],
 _snapshotMetrics.isEmpty
 ? const _InlineEmptyState(
 title: 'No snapshot metrics',
 message: 'Add the metrics that summarize project closeout.',
 )
 : FullScreenTableWrapper(
 title: 'Finalization Snapshot Metrics',
 child: LayoutBuilder(builder: (context, constraints) {
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: ConstrainedBox(
 constraints: BoxConstraints(minWidth: constraints.maxWidth),
 child: _buildSnapshotMetricsDataTable(),
 ),
 );
 }),
 tableBuilder: (fsContext) => _buildSnapshotMetricsDataTable(),
 ),
 ],
 ),
 );
 }

 Widget _buildSnapshotMetricsDataTable() {
 return DataTable(
 headingRowColor: WidgetStateProperty.all(const Color(0xFF0F172A)),
 headingRowHeight: 48,
 dataRowMinHeight: 64,
 dataRowMaxHeight: 96,
 columnSpacing: 24,
 horizontalMargin: 16,
 headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
 dataTextStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
 columns: const [
 DataColumn(label: Text('Metric')),
 DataColumn(label: Text('Description')),
 DataColumn(label: Text('Status')),
 DataColumn(label: Text('Readiness')),
 DataColumn(label: Text('Action')),
 ],
 rows: _snapshotMetrics.asMap().entries.map((entry) {
 final idx = entry.key;
 final metric = entry.value;
 final hasData = metric.title.isNotEmpty || metric.value.isNotEmpty;
 return DataRow(
 color: WidgetStateProperty.all(idx.isEven ? Colors.white : const Color(0xFFFAFBFC)),
 cells: [
 // Metric — read-only value preview (accent bar + title)
 DataCell(Row(children: [
 Container(width: 4, height: 32, decoration: BoxDecoration(color: metric.accent.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(2))),
 const SizedBox(width: 12),
 Expanded(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 220), child: _FinalizeCellView(label: 'Metric', value: metric.title.isEmpty ? 'Untitled' : metric.title))),
 ])),
 // Description — read-only value preview
 DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 320), child: _FinalizeCellView(label: 'Description', value: metric.subtitle, multiline: true))),
 // Status — read-only chip preview
 DataCell(_FinalizeCellView(
 label: 'Status',
 value: metric.value,
 child: metric.value.isEmpty
 ? const Text('Not set', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w400, fontFamily: 'Inter'))
 : Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: const Color(0xFF22C55E).withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
 ),
 child: Row(mainAxisSize: MainAxisSize.min, children: [
 const Icon(Icons.check_circle, size: 12, color: Color(0xFF22C55E)),
 const SizedBox(width: 4),
 Text(metric.value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF22C55E))),
 ]),
 ),
 )),
 // Readiness — read-only chip preview
 DataCell(_FinalizeCellView(
 label: 'Readiness',
 value: hasData ? 'Saved' : 'Empty',
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: (hasData ? const Color(0xFF22C55E) : const Color(0xFF9CA3AF)).withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: (hasData ? const Color(0xFF22C55E) : const Color(0xFF9CA3AF)).withValues(alpha: 0.3)),
 ),
 child: Row(mainAxisSize: MainAxisSize.min, children: [
 Icon(hasData ? Icons.lock : Icons.lock_outline, size: 12, color: hasData ? const Color(0xFF22C55E) : const Color(0xFF9CA3AF)),
 const SizedBox(width: 4),
 Text(hasData ? 'Saved' : 'Empty', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: hasData ? const Color(0xFF22C55E) : const Color(0xFF9CA3AF))),
 ]),
 ),
 )),
 // Action — Edit button (opens modal) + Delete button
 DataCell(Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 _FinalizeRowEditButton(onPressed: () => _openSnapshotMetricEditDialog(metric), tooltip: 'Edit metric'),
 const SizedBox(width: 8),
 IconButton(
 icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
 tooltip: 'Delete',
 onPressed: () => _deleteSnapshotMetric(metric.id),
 ),
 ],
 )),
 ],
 );
 }).toList(),
 );
 }

 Future<void> _openSnapshotMetricEditDialog(_SnapshotMetric metric) async {
 final result = await _showFinalizeRowEditDialog(
 context,
 title: metric.title.isEmpty ? 'Edit metric' : 'Edit: ${metric.title}',
 fields: [
 _FinalizeEditFieldSpec(label: 'Metric', initialValue: metric.title, hintText: 'Metric'),
 _FinalizeEditFieldSpec(label: 'Description', initialValue: metric.subtitle, multiline: true, hintText: 'Description'),
 _FinalizeEditFieldSpec(label: 'Status', initialValue: metric.value, hintText: 'Status'),
 ],
 );
 if (result == null) return;
 setState(() {
 _updateSnapshotMetric(metric.copyWith(
 title: result[0] ?? metric.title,
 subtitle: result[1] ?? metric.subtitle,
 value: result[2] ?? metric.value,
 ));
 });
 }

  Widget _buildSnapshotReadOnlyRow(_SnapshotMetric metric) {
    final valueColor = _getValueColor(metric.value);
    final valueIcon = _getValueIcon(metric.value);
    final hasData = metric.title.isNotEmpty ||
        metric.subtitle.isNotEmpty ||
        metric.value.isNotEmpty;

    // Safely get the accent color with fallback for invalid colors
    Color getSafeAccent() {
      try {
        return metric.accent;
      } catch (e) {
        return const Color(0xFFFFC812);
      }
    }

    if (!hasData) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: const Icon(
                Icons.info_outline,
                size: 18,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No data entered',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Click Edit to add this metric',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFEFEF),
                borderRadius: const BorderRadius.all(Radius.circular(20)),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Empty',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final safeAccent = getSafeAccent();

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: safeAccent.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        metric.title.isEmpty ? 'Untitled Metric' : metric.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    _buildStatusBadge(metric.value, valueColor, valueIcon),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.signal_cellular_alt,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          metric.subtitle.isEmpty
                              ? 'No signal'
                              : metric.subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF16A34A).withValues(alpha: 0.2),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_rounded,
                  size: 11,
                  color: Color(0xFF16A34A),
                ),
                SizedBox(width: 4),
                Text(
                  'Saved',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF16A34A),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            value.isEmpty ? 'Not set' : value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getValueIcon(String value) {
    switch (value.toLowerCase()) {
      case 'complete':
        return Icons.check_circle_rounded;
      case 'on track':
        return Icons.trending_up_rounded;
      case 'at risk':
        return Icons.warning_rounded;
      case 'blocked':
        return Icons.block_rounded;
      case 'in progress':
        return Icons.autorenew_rounded;
      case 'not started':
        return Icons.radio_button_unchecked_rounded;
      case 'under review':
        return Icons.visibility_rounded;
      case 'pending sign-off':
        return Icons.pending_rounded;
      default:
        return Icons.circle_rounded;
    }
  }

  Color _getValueColor(String value) {
    switch (value.toLowerCase()) {
      case 'complete':
        return const Color(0xFF16A34A);
      case 'on track':
        return const Color(0xFFFFC812);
      case 'at risk':
        return const Color(0xFFF59E0B);
      case 'blocked':
        return const Color(0xFFEF4444);
      case 'in progress':
        return const Color(0xFFB8860B);
      case 'under review':
        return const Color(0xFFD97706);
      case 'pending sign-off':
        return const Color(0xFFF97316);
      case 'not started':
        return const Color(0xFF94A3B8);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Widget _buildFinalizeChecklist() {
    return _SectionCard(
      title: 'Finalization Checklist',
      subtitle: 'Lock down every last dependency before sign-off.',
      icon: Icons.check_circle_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final rows = await showCsvImportDialog(context,
                      tableTitle: 'Checklist',
                      columns: [
                        const CsvColumnSpec(
                            key: 'title',
                            label: 'Checklist Item',
                            sampleValue: 'Final deployment review'),
                        const CsvColumnSpec(
                            key: 'owner',
                            label: 'Owner',
                            sampleValue: 'Project Manager'),
                        const CsvColumnSpec(
                            key: 'dueDate',
                            label: 'Due Date',
                            sampleValue: '2026-07-15'),
                        const CsvColumnSpec(
                            key: 'status',
                            label: 'Status',
                            sampleValue: 'Pending',
                            allowedValues: ['Pending', 'In Progress', 'Done']),
                      ]);
                  if (rows == null || !mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          '${rows.length} checklist items imported from CSV'),
                      backgroundColor: Colors.green));
                },
                icon: const Icon(Icons.upload_file_outlined, size: 16),
                label: const Text('Import CSV'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    foregroundColor: const Color(0xFFFFC812),
                    side: const BorderSide(color: Color(0xFFFFC812))),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _addChecklistItem,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add checklist item'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTableHeader(
            const ['Checklist item', 'Owner', 'Due date', 'Status', 'Action'],
            columnWidths: const [4, 2, 2, 2, 2],
          ),
          const SizedBox(height: 12),
          if (_checklist.isEmpty)
            const _InlineEmptyState(
              title: 'No checklist items',
              message: 'Add the remaining actions required to close out.',
            )
          else
            ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _checklist.length,
              itemBuilder: (context, idx) => RepaintBoundary(
                key: ValueKey('checklist_row_$idx'),
                child: _buildChecklistRow(_checklist[idx]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChecklistRow(_ChecklistItem item) {
    final statusColor = _checklistStatusColor(item.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: _FinalizeCellView(label: 'Checklist item', value: item.title, multiline: true),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _FinalizeCellView(label: 'Owner', value: item.owner),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _FinalizeCellView(label: 'Due date', value: item.dueDate.isEmpty ? '—' : item.dueDate),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _FinalizeCellView(
              label: 'Status',
              value: item.status,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_checklistStatusIcon(item.status), size: 12, color: statusColor),
                  const SizedBox(width: 4),
                  Text(item.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _FinalizeRowEditButton(onPressed: () => _openChecklistEditDialog(item), tooltip: 'Edit checklist item'),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                  tooltip: 'Delete',
                  onPressed: () => _deleteChecklistItem(item.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openChecklistEditDialog(_ChecklistItem item) async {
    final result = await _showFinalizeRowEditDialog(
      context,
      title: item.title.isEmpty ? 'Edit checklist item' : 'Edit: ${item.title}',
      fields: [
        _FinalizeEditFieldSpec(label: 'Checklist item', initialValue: item.title, multiline: true, hintText: 'Checklist item'),
        _FinalizeEditFieldSpec(label: 'Owner', initialValue: item.owner, hintText: 'Owner'),
        _FinalizeEditFieldSpec(label: 'Due date', initialValue: item.dueDate, hintText: 'Due date (YYYY-MM-DD)'),
        _FinalizeEditFieldSpec(label: 'Status', initialValue: item.status, hintText: 'Status'),
      ],
    );
    if (result == null) return;
    setState(() {
      _updateChecklistItem(item.copyWith(
        title: result[0] ?? item.title,
        owner: result[1] ?? item.owner,
        dueDate: result[2] ?? item.dueDate,
        status: result[3] ?? item.status,
      ), notify: true);
    });
  }

  Color _checklistStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'done':
        return const Color(0xFF22C55E);
      case 'in progress':
        return const Color(0xFFF59E0B);
      case 'blocked':
        return const Color(0xFFEF4444);
      case 'not started':
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  IconData _checklistStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'done':
        return Icons.check_circle;
      case 'in progress':
        return Icons.timelapse;
      case 'blocked':
        return Icons.error_outline;
      case 'not started':
      default:
        return Icons.radio_button_unchecked;
    }
  }

  Widget _buildSignOffPanel() {
    return _SectionCard(
      title: 'Executive Sign-off',
      subtitle: 'Confirm ownership and approval before closing.',
      icon: Icons.verified_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTableHeader(
            const ['Stakeholder', 'Role', 'Status', 'Decision date', 'Actions'],
            columnWidths: const [3, 3, 2, 2, 2],
          ),
          const SizedBox(height: 12),
          if (_signOffs.isEmpty)
            const _InlineEmptyState(
              title: 'No sign-offs yet',
              message: 'Track each required stakeholder approval here.',
            )
          else
            ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _signOffs.length,
              itemBuilder: (context, idx) => RepaintBoundary(
                key: ValueKey('signoff_row_$idx'),
                child: _buildSignOffRow(_signOffs[idx]),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _addSignOffItem,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add sign-off'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOffRow(_SignOffItem item) {
    final statusColor = _signOffStatusColor(item.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _FinalizeCellView(label: 'Stakeholder', value: item.name),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: _FinalizeCellView(label: 'Role', value: item.role.isEmpty ? '—' : item.role),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _FinalizeCellView(
              label: 'Status',
              value: item.status,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_signOffStatusIcon(item.status), size: 12, color: statusColor),
                  const SizedBox(width: 4),
                  Text(item.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _FinalizeCellView(label: 'Decision date', value: item.decisionDate.isEmpty ? '—' : item.decisionDate),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _FinalizeRowEditButton(onPressed: () => _openSignOffEditDialog(item), tooltip: 'Edit sign-off'),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFFEF4444)),
                  tooltip: 'Delete',
                  onPressed: () => _deleteSignOffItem(item.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSignOffEditDialog(_SignOffItem item) async {
    final result = await _showFinalizeRowEditDialog(
      context,
      title: item.name.isEmpty ? 'Edit sign-off' : 'Edit: ${item.name}',
      fields: [
        _FinalizeEditFieldSpec(label: 'Stakeholder', initialValue: item.name, hintText: 'Stakeholder name'),
        _FinalizeEditFieldSpec(label: 'Role', initialValue: item.role, hintText: 'Role'),
        _FinalizeEditFieldSpec(label: 'Status', initialValue: item.status, hintText: 'Status'),
        _FinalizeEditFieldSpec(label: 'Decision date', initialValue: item.decisionDate, hintText: 'Decision date (YYYY-MM-DD)'),
      ],
    );
    if (result == null) return;
    setState(() {
      _updateSignOffItem(item.copyWith(
        name: result[0] ?? item.name,
        role: result[1] ?? item.role,
        status: result[2] ?? item.status,
        decisionDate: result[3] ?? item.decisionDate,
      ), notify: true);
    });
  }

  Color _signOffStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF22C55E);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'deferred':
        return const Color(0xFFF59E0B);
      case 'pending':
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  IconData _signOffStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'deferred':
        return Icons.schedule;
      case 'pending':
      default:
        return Icons.hourglass_top;
    }
  }

  Widget _buildClosureInsights(BuildContext context) {
    return _SectionCard(
      title: 'Closure Insights',
      subtitle: 'Capture final risks, coverage, and warranty commitments.',
      icon: Icons.lightbulb_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_insights.isEmpty)
            const _InlineEmptyState(
              title: 'No closure insights yet',
              message: 'Add risks, coverage, and warranty notes to close out.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: _buildInsightsDataTable(),
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _addInsight,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add insight'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsDataTable() {
    return DataTable(
      headingRowColor: WidgetStateProperty.all(const Color(0xFF0F172A)),
      headingRowHeight: 48,
      dataRowMinHeight: 64,
      dataRowMaxHeight: 96,
      columnSpacing: 24,
      horizontalMargin: 16,
      headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
      dataTextStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
      columns: const [
        DataColumn(label: Text('Insight')),
        DataColumn(label: Text('Detail')),
        DataColumn(label: Text('Action')),
      ],
      rows: _insights.asMap().entries.map((entry) {
        final idx = entry.key;
        final item = entry.value;
        return DataRow(
          color: WidgetStateProperty.all(idx.isEven ? Colors.white : const Color(0xFFFAFBFC)),
          cells: [
            // Insight title — read-only value preview
            DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 300), child: _FinalizeCellView(label: 'Insight title', value: item.title, multiline: true))),
            // Detail — read-only value preview
            DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: _FinalizeCellView(label: 'Detail — risk, coverage, or warranty commitment', value: item.detail, multiline: true))),
            // Action — Edit button (opens modal) + Delete button
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FinalizeRowEditButton(onPressed: () => _openInsightEditDialog(item), tooltip: 'Edit insight'),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                  tooltip: 'Delete',
                  onPressed: () => _deleteInsight(item.id),
                ),
              ],
            )),
          ],
        );
      }).toList(),
    );
  }

  Future<void> _openInsightEditDialog(_InsightItem item) async {
    final result = await _showFinalizeRowEditDialog(
      context,
      title: item.title.isEmpty ? 'Edit insight' : 'Edit: ${item.title}',
      fields: [
        _FinalizeEditFieldSpec(label: 'Insight title', initialValue: item.title, hintText: 'Insight title'),
        _FinalizeEditFieldSpec(label: 'Detail', initialValue: item.detail, multiline: true, hintText: 'Risk, coverage, or warranty commitment'),
      ],
    );
    if (result == null) return;
    setState(() {
      _updateInsight(item.copyWith(
        title: result[0] ?? item.title,
        detail: result[1] ?? item.detail,
      ));
    });
  }

  Widget _buildPremiumActionBar(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header with edit indicator ──
          Container(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFFE5E7EB).withValues(alpha: 0.7),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFF8E1),
                        Color(0xFFE8F0FE),
                      ],
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: const Icon(
                    Icons.fact_check_outlined,
                    size: 18,
                    color: Color(0xFF4338CA),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Finalize Decision Log',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Capture the final decision summary and next-step actions.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Editable badge ──
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFD1FAE5).withValues(alpha: 0.7),
                        const Color(0xFFECFDF5).withValues(alpha: 0.5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF6EE7B7).withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 12,
                        color: Color(0xFF059669),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Editable \u00B7 Auto-saves',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF059669),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Editable fields ──
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Finalization notes ──
                _buildEditableField(
                  label: 'Finalization notes',
                  hintText:
                      'Summarize final checks, approvals, and open items…',
                  icon: Icons.description_outlined,
                  controller: _finalNotesController,
                  maxLines: 4,
                ),
                const SizedBox(height: 24),
                // ── Next steps ──
                _buildEditableField(
                  label: 'Next steps after closeout',
                  hintText: 'List post-launch actions and support transitions…',
                  icon: Icons.trending_flat_rounded,
                  controller: _nextStepsController,
                  maxLines: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Input decoration shared by checklist and sign-off rows.
  InputDecoration _inputDecoration(String hintText, {bool dense = false}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontSize: 13,
        color: Color(0xFF9CA3AF),
        fontWeight: FontWeight.w500,
      ),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFF4338CA), width: 1.5),
      ),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      isDense: dense,
      contentPadding: dense
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  /// World-class editable text field used in the decision log.
  Widget _buildEditableField({
    required String label,
    required String hintText,
    required IconData icon,
    required TextEditingController controller,
    int maxLines = 4,
  }) {
    final hasContent = controller.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Label row ──
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: Icon(icon, size: 14, color: const Color(0xFF6B7280)),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 8),
            // ── Content status badge ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: hasContent
                    ? const Color(0xFFD1FAE5).withValues(alpha: 0.5)
                    : const Color(0xFFFEF3C7).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasContent
                      ? const Color(0xFFA7F3D0).withValues(alpha: 0.6)
                      : const Color(0xFFFDE68A).withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasContent
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 10,
                    color: hasContent
                        ? const Color(0xFF059669)
                        : const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    hasContent ? 'Filled' : 'Empty',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: hasContent
                          ? const Color(0xFF059669)
                          : const Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // ── Editable text area ──
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: VoiceTextField(
            controller: controller,
            maxLines: maxLines,
            style: TextStyle(
              fontSize: 14,
              color: hasContent
                  ? const Color(0xFF111827)
                  : const Color(0xFF9CA3AF),
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 14,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        // ── Character counter ──
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${controller.text.length} characters',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(List<String> labels, {List<int>? columnWidths}) {
    final widths =
        columnWidths ?? List<int>.filled(labels.length, 1, growable: false);
    return Row(
      children: List.generate(labels.length, (index) {
        return Expanded(
          flex: widths[index],
          child: Text(
            labels[index],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        );
      }),
    );
  }

  void _addSnapshotMetric() {
    setState(() {
      _snapshotMetrics.add(_SnapshotMetric(
        id: _newId(),
        title: '',
        subtitle: '',
        value: '',
        accent: const Color(0xFFFFC812),
      ));
    });
    _scheduleSave();
  }

  void _updateSnapshotMetric(_SnapshotMetric item) {
    final index = _snapshotMetrics.indexWhere((e) => e.id == item.id);
    if (index == -1) return;
    _snapshotMetrics[index] = item;
    _scheduleSave();
  }

  void _deleteSnapshotMetric(String id) {
    setState(() => _snapshotMetrics.removeWhere((e) => e.id == id));
    _scheduleSave();
      showDeleteSuccessSnackBar(context, itemLabel: 'Snapshot Metric');
  }

  void _addChecklistItem() {
    setState(() {
      _checklist.add(_ChecklistItem(
        id: _newId(),
        title: '',
        owner: '',
        dueDate: '',
        status: _checklistStatuses.first,
      ));
    });
    _scheduleSave();
  }

  void _updateChecklistItem(_ChecklistItem item, {bool notify = false}) {
    final index = _checklist.indexWhere((entry) => entry.id == item.id);
    if (index == -1) return;
    _checklist[index] = item;
    if (notify && mounted) {
      setState(() {});
    }
    _scheduleSave();
  }

  void _deleteChecklistItem(String id) {
    setState(() => _checklist.removeWhere((entry) => entry.id == id));
    _scheduleSave();
      showDeleteSuccessSnackBar(context, itemLabel: 'Checklist Item');
  }

  void _addSignOffItem() {
    setState(() {
      _signOffs.add(_SignOffItem(
        id: _newId(),
        name: '',
        role: '',
        status: _signOffStatuses.first,
        decisionDate: '',
      ));
    });
    _scheduleSave();
  }

  void _updateSignOffItem(_SignOffItem item, {bool notify = false}) {
    final index = _signOffs.indexWhere((entry) => entry.id == item.id);
    if (index == -1) return;
    _signOffs[index] = item;
    if (notify && mounted) {
      setState(() {});
    }
    _scheduleSave();
  }

  void _deleteSignOffItem(String id) {
    setState(() => _signOffs.removeWhere((entry) => entry.id == id));
    _scheduleSave();
      showDeleteSuccessSnackBar(context, itemLabel: 'Sign Off Item');
  }

  void _addInsight() {
    setState(() {
      _insights.add(_InsightItem(id: _newId(), title: '', detail: ''));
    });
    _scheduleSave();
  }

  void _updateInsight(_InsightItem item) {
    final index = _insights.indexWhere((entry) => entry.id == item.id);
    if (index == -1) return;
    _insights[index] = item;
    _scheduleSave();
  }

  void _deleteInsight(String id) {
    setState(() => _insights.removeWhere((entry) => entry.id == id));
    _scheduleSave();
      showDeleteSuccessSnackBar(context, itemLabel: 'Insight');
  }
}

class _CurrentUserProfileChip extends StatelessWidget {
  const _CurrentUserProfileChip();

  String _initials(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'U';
    final parts = trimmed.split(RegExp(r"\s+")).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return trimmed[0].toUpperCase();
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName =
        FirebaseAuthService.displayNameOrEmail(fallback: 'User');
    final photoUrl = user?.photoURL;
    final email = user?.email ?? '';

    return RepaintBoundary(
      child: StreamBuilder<bool>(
        stream: UserService.watchAdminStatus(),
        builder: (context, snapshot) {
          final isAdmin = snapshot.data ?? UserService.isAdminEmail(email);
          final role = isAdmin ? 'Admin' : 'Member';

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(999)),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFE5E7EB),
                  backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                      ? NetworkImage(photoUrl)
                      : null,
                  child: (photoUrl == null || photoUrl.isEmpty)
                      ? Text(
                          _initials(displayName),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4B5563)),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827)),
                    ),
                    Text(
                      role,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: const Color(0xFF059669)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                              letterSpacing: -0.3)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFF9CA3AF)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827))),
                const SizedBox(height: 2),
                Text(message,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatItem {
  _HeroStatItem({required this.id, required this.label, required this.value});

  final String id;
  final String label;
  final String value;

  _HeroStatItem copyWith({String? label, String? value}) {
    return _HeroStatItem(
      id: id,
      label: label ?? this.label,
      value: value ?? this.value,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'value': value,
      };

  static List<_HeroStatItem> fromList(dynamic data) {
    if (data is! List) return [];
    return data.map((item) {
      final map = Map<String, dynamic>.from(item as Map? ?? {});
      return _HeroStatItem(
        id: map['id']?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        label: map['label']?.toString() ?? '',
        value: map['value']?.toString() ?? '',
      );
    }).toList();
  }
}

class _SnapshotMetric {
  _SnapshotMetric({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.accent,
  });

  final String id;
  final String title;
  final String subtitle;
  final String value;
  final Color accent;

  _SnapshotMetric copyWith({
    String? title,
    String? subtitle,
    String? value,
    Color? accent,
  }) {
    return _SnapshotMetric(
      id: id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      value: value ?? this.value,
      accent: accent ?? this.accent,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'value': value,
        'accent': accent.toARGB32(),
      };

  static List<_SnapshotMetric> fromList(dynamic data) {
    if (data is! List) return [];
    return data.map((item) {
      final map = Map<String, dynamic>.from(item as Map? ?? {});

      // Safely deserialize accent color with validation
      Color safeAccent(int defaultArgb) {
        if (map['accent'] is int && map['accent'] != null) {
          try {
            return Color(map['accent'] as int);
          } catch (e) {
            // Invalid color value, use default
          }
        }
        return Color(defaultArgb);
      }

      return _SnapshotMetric(
        id: map['id']?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: map['title']?.toString() ?? '',
        subtitle: map['subtitle']?.toString() ?? '',
        value: map['value']?.toString() ?? '',
        accent: safeAccent(0xFFFFC812),
      );
    }).toList();
  }
}

class _ChecklistItem {
  _ChecklistItem({
    required this.id,
    required this.title,
    required this.owner,
    required this.dueDate,
    required this.status,
  });

  final String id;
  final String title;
  final String owner;
  final String dueDate;
  final String status;

  _ChecklistItem copyWith({
    String? title,
    String? owner,
    String? dueDate,
    String? status,
  }) {
    return _ChecklistItem(
      id: id,
      title: title ?? this.title,
      owner: owner ?? this.owner,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'owner': owner,
        'dueDate': dueDate,
        'status': status,
      };

  static List<_ChecklistItem> fromList(dynamic data) {
    if (data is! List) return [];
    return data.map((item) {
      final map = Map<String, dynamic>.from(item as Map? ?? {});
      return _ChecklistItem(
        id: map['id']?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: map['title']?.toString() ?? '',
        owner: map['owner']?.toString() ?? '',
        dueDate: map['dueDate']?.toString() ?? '',
        status: map['status']?.toString() ?? 'Not started',
      );
    }).toList();
  }
}

class _SignOffItem {
  _SignOffItem({
    required this.id,
    required this.name,
    required this.role,
    required this.status,
    required this.decisionDate,
  });

  final String id;
  final String name;
  final String role;
  final String status;
  final String decisionDate;

  _SignOffItem copyWith({
    String? name,
    String? role,
    String? status,
    String? decisionDate,
  }) {
    return _SignOffItem(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      status: status ?? this.status,
      decisionDate: decisionDate ?? this.decisionDate,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'role': role,
        'status': status,
        'decisionDate': decisionDate,
      };

  static List<_SignOffItem> fromList(dynamic data) {
    if (data is! List) return [];
    return data.map((item) {
      final map = Map<String, dynamic>.from(item as Map? ?? {});
      return _SignOffItem(
        id: map['id']?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: map['name']?.toString() ?? '',
        role: map['role']?.toString() ?? '',
        status: map['status']?.toString() ?? 'Pending',
        decisionDate: map['decisionDate']?.toString() ?? '',
      );
    }).toList();
  }
}

class _InsightItem {
  _InsightItem({
    required this.id,
    required this.title,
    required this.detail,
  });

  final String id;
  final String title;
  final String detail;

  _InsightItem copyWith({String? title, String? detail}) {
    return _InsightItem(
      id: id,
      title: title ?? this.title,
      detail: detail ?? this.detail,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'detail': detail,
      };

  static List<_InsightItem> fromList(dynamic data) {
    if (data is! List) return [];
    return data.map((item) {
      final map = Map<String, dynamic>.from(item as Map? ?? {});
      return _InsightItem(
        id: map['id']?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: map['title']?.toString() ?? '',
        detail: map['detail']?.toString() ?? '',
      );
    }).toList();
  }
}

class _Debouncer {
  _Debouncer({Duration? delay})
      : delay = delay ?? const Duration(milliseconds: 600);

  final Duration delay;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}


/// Read-only value-preview cell rendered inside finalize tables.
///
/// Shows the row's stored value (dark, w500) or a grey placeholder using
/// [label] when the cell is empty. It deliberately contains NO
/// [OpenEditorButton] and NO inline editing affordance — the only way to
/// edit a row is via the gold [_FinalizeRowEditButton] in the Action
/// column, which opens [_showFinalizeRowEditDialog]. That dialog hosts the
/// [VoiceTextFormField]s which embed the OpenEditorButton, so the
/// "Open Editor" affordance exists exclusively inside the popup modal.
class _FinalizeCellView extends StatelessWidget {
  const _FinalizeCellView({
    required this.label,
    required this.value,
    this.multiline = false,
    this.child,
  });

  final String label;
  final String value;
  final bool multiline;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final hasValue = value.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: multiline ? 64 : 40),
      padding: EdgeInsets.symmetric(
        horizontal: 10,
        vertical: multiline ? 10 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child ??
          Text(
            hasValue ? value : label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400,
              color: hasValue ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
              fontFamily: 'Inter',
              height: 1.35,
            ),
          ),
    );
  }
}

/// Compact gold "Edit" button that lives in the Action column of each
/// finalize table row. Tapping it triggers the row-level edit popup
/// (built by [_showFinalizeRowEditDialog]) so the user can edit every
/// field of the row at once.
///
/// Visual identity follows the project's OpenEditorButton gradient
/// (`#FFB800 → #F59E0B`) so the button is immediately recognisable as
/// the project's "open editor" affordance, now consolidated into the
/// Action column.
class _FinalizeRowEditButton extends StatelessWidget {
  const _FinalizeRowEditButton({required this.onPressed, this.tooltip = 'Edit row'});
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFB800), Color(0xFFF59E0B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPressed,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined, size: 14, color: Color(0xFF111827)),
                  SizedBox(width: 4),
                  Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Specification for a single field inside the row-level edit dialog
/// opened by [_showFinalizeRowEditDialog]. Each spec becomes a labelled
/// [VoiceTextFormField] (which embeds the OpenEditorButton) inside
/// the popup, so the user can edit every column of the row at once.
class _FinalizeEditFieldSpec {
  const _FinalizeEditFieldSpec({
    required this.label,
    required this.initialValue,
    this.multiline = false,
    this.hintText,
  });
  final String label;
  final String initialValue;
  final bool multiline;
  final String? hintText;
}

/// Opens a modal edit dialog for an entire finalize table row.
///
/// [title] is shown at the top of the dialog. [fields] is the ordered
/// list of fields to edit — one [VoiceTextFormField] per field, labelled
/// with the spec's [label]. The dialog returns a `Map<int, String>`
/// mapping field index → trimmed text. Returns `null` if the user
/// cancels. The caller maps the indices back to the appropriate fields
/// on the row's data model.
Future<Map<int, String>?> _showFinalizeRowEditDialog(
  BuildContext context, {
  required String title,
  required List<_FinalizeEditFieldSpec> fields,
}) async {
  final controllers = [
    for (final f in fields) TextEditingController(text: f.initialValue),
  ];
  final result = await showDialog<Map<int, String>?>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          const Icon(Icons.edit_note_rounded, color: Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < fields.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                Text(
                  fields[i].label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                VoiceTextFormField(
                  controller: controllers[i],
                  maxLines: fields[i].multiline ? 4 : 1,
                  decoration: InputDecoration(
                    hintText: fields[i].hintText ?? fields[i].label,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF4338CA), width: 1.5),
                    ),
                  ),
                  autofocus: i == 0,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final map = <int, String>{};
            for (var i = 0; i < controllers.length; i++) {
              map[i] = controllers[i].text.trim();
            }
            Navigator.of(dialogContext).pop(map);
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  for (final c in controllers) {
    c.dispose();
  }
  return result;
}
