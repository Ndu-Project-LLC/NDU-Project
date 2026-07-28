import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ndu_project/models/design_phase_models.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
class RequirementsTraceabilityDashboard extends StatelessWidget {
  const RequirementsTraceabilityDashboard({
    super.key,
    required this.projectData,
    required this.requirements,
    required this.checklistItems,
    required this.ownerOptions,
    required this.notesController,
    required this.selectedRequirementIndex,
    required this.selectedRequirement,
    required this.showAllRows,
    required this.onAddRequirement,
    required this.onRefreshContext,
    required this.onToggleShowAll,
    required this.onSelectRequirement,
    required this.onDeleteRequirement,
    required this.onArtifactTap,
    required this.onUpdateSelectedRequirement,
    required this.onUploadArtifact,
  });

  final ProjectDataModel projectData;
  final List<RequirementRow> requirements;
  final List<RequirementChecklistItem> checklistItems;
  final List<String> ownerOptions;
  final TextEditingController notesController;
  final int selectedRequirementIndex;
  final RequirementRow? selectedRequirement;
  final bool showAllRows;
  final VoidCallback onAddRequirement;
  final VoidCallback onRefreshContext;
  final VoidCallback onToggleShowAll;
  final ValueChanged<int> onSelectRequirement;
  final ValueChanged<int> onDeleteRequirement;
  final ValueChanged<RequirementRow> onArtifactTap;
  final void Function(RequirementRow Function(RequirementRow current))
      onUpdateSelectedRequirement;
  final Future<void> Function(RequirementRow row) onUploadArtifact;

  @override
  Widget build(BuildContext context) {
    final displayRows = List.generate(
        requirements.length, (index) => _viewOf(requirements[index], index));
    final snapshot = _DashboardSnapshot.from(
      projectData: projectData,
      requirements: displayRows,
      checklistItems: checklistItems,
    );
    final selectedView = selectedRequirement == null
        ? null
        : _viewOf(selectedRequirement!, selectedRequirementIndex);
    final stacked = MediaQuery.of(context).size.width < 1100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        stacked
            ? Column(
                children: [
                  _hero(context, snapshot),
                  const SizedBox(height: 18),
                  _notesCard(context),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 8, child: _hero(context, snapshot)),
                  const SizedBox(width: 18),
                  Expanded(flex: 5, child: _notesCard(context)),
                ],
              ),
        const SizedBox(height: 24),
        _coverage(snapshot),
        const SizedBox(height: 24),
        stacked
            ? Column(
                children: [
                  _matrix(context, displayRows, snapshot),
                  const SizedBox(height: 20),
                  _allocation(snapshot),
                  const SizedBox(height: 20),
                  _gaps(snapshot),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      flex: 8, child: _matrix(context, displayRows, snapshot)),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        _allocation(snapshot),
                        const SizedBox(height: 20),
                        _gaps(snapshot),
                      ],
                    ),
                  ),
                ],
              ),
        const SizedBox(height: 24),
        stacked
            ? Column(
                children: [
                  _detail(context, selectedView),
                  const SizedBox(height: 20),
                  _conflicts(context, snapshot, selectedView),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: _detail(context, selectedView)),
                  const SizedBox(width: 20),
                  Expanded(
                      flex: 5,
                      child: _conflicts(context, snapshot, selectedView)),
                ],
              ),
      ],
    );
  }

  _DisplayRequirement _viewOf(RequirementRow row, int index) {
    final artifacts = [
      ...projectData.designDeliverablesData.register
          .map((item) => item.name.trim())
          .where((name) => name.isNotEmpty),
      ...projectData.designDeliverablesData.pipeline
          .map((item) => item.label.trim())
          .where((label) => label.isNotEmpty),
    ];
    final title = row.title.trim().isNotEmpty
        ? row.title.trim()
        : 'Requirement ${index + 1}';
    final type = row.requirementType.trim().isNotEmpty
        ? (row.requirementType.toLowerCase().contains('non')
            ? 'Non-Functional'
            : 'Functional')
        : _inferType('$title ${row.definition}');
    final isOutOfScope = row.isOutOfScope ||
        projectData.outOfScopeItems.any((item) {
          final candidate = _normalize(item.description);
          return candidate.isNotEmpty &&
              (_normalize(title).contains(candidate) ||
                  candidate.contains(_normalize(title)));
        });
    final status = isOutOfScope
        ? 'Unmapped'
        : row.validationStatus.toLowerCase().contains('map') &&
                !row.validationStatus.toLowerCase().contains('un')
            ? 'Mapped'
            : 'Unmapped';
    final artifactLabel = isOutOfScope
        ? ''
        : row.designArtifactLabel.trim().isNotEmpty
            ? row.designArtifactLabel.trim()
            : status == 'Mapped' && artifacts.isNotEmpty
                ? artifacts[index % artifacts.length]
                : '';
    return _DisplayRequirement(
      source: row,
      requirementId: row.requirementId.trim().isNotEmpty
          ? row.requirementId.trim()
          : 'REQ-${(index + 1).toString().padLeft(3, '0')}',
      title: title,
      definition: row.definition.trim().isNotEmpty
          ? row.definition.trim()
          : 'Carry the requirement into design artifacts and implementation evidence.',
      type: type,
      artifactLabel: artifactLabel,
      artifactType: row.designArtifactType.trim().isNotEmpty
          ? row.designArtifactType.trim()
          : type == 'Non-Functional'
              ? 'PDF'
              : 'Figma',
      validationStatus: status,
      acceptanceCriteria: row.acceptanceCriteria.trim().isNotEmpty
          ? row.acceptanceCriteria.trim()
          : type == 'Non-Functional'
              ? 'Controls and review evidence are explicit in the design package.'
              : 'Flow states and implementation expectations are clear in the approved artifact.',
      testMethod: row.testMethod.trim().isNotEmpty
          ? row.testMethod.trim()
          : type == 'Non-Functional'
              ? 'Governance review'
              : 'Design walkthrough',
      sourceDocument: row.sourceDocument.trim().isNotEmpty
          ? row.sourceDocument.trim()
          : 'Planning requirement register',
      gapStatus: row.gapStatus.toLowerCase().contains('closed')
          ? 'Closed'
          : 'Pending Approval',
      conflictNote: row.conflictNote.trim(),
      conflictImpact:
          row.conflictImpact.toLowerCase().contains('high') ? 'High' : 'Low',
      isOutOfScope: isOutOfScope,
    );
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  String _inferType(String value) {
    const signals = [
      'latency',
      'performance',
      'security',
      'capacity',
      'safety',
      'brand',
      'audit',
      'compliance',
      'privacy',
      'wayfinding',
      'signage',
      'retention',
    ];
    final normalized = value.toLowerCase();
    return signals.any(normalized.contains) ? 'Non-Functional' : 'Functional';
  }

  Future<void> _handleArtifactTap(RequirementRow row) async {
    final uri = Uri.tryParse(row.designArtifactUrl.trim());
    if (uri != null && uri.hasScheme) {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) return;
    }
    onArtifactTap(row);
  }

  Widget _hero(BuildContext context, _DashboardSnapshot snapshot) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF173052), Color(0xFF1E3A5F)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.rule_folder_outlined, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Design Specifications',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Traceability and validation bridge for ${projectData.projectName.trim().isNotEmpty ? projectData.projectName.trim() : 'the current design package'}, covering technical items like API endpoints and physical controls like venue capacity.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.84),
                      height: 1.45,
                    ),
              ),
            ]),
          ),
          _pill('${snapshot.mappedPercent}% mapped'),
        ]),
        const SizedBox(height: 18),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _metricPill('Requirements', '${snapshot.total}'),
          _metricPill('Artifacts', '${snapshot.artifacts}'),
          _metricPill('AI Signals', '${snapshot.aiSignals}'),
          _metricPill('Gap Items', '${snapshot.gaps.length}'),
        ]),
        const SizedBox(height: 18),
        Wrap(spacing: 12, runSpacing: 12, children: [
          FilledButton.icon(
            onPressed: onAddRequirement,
            icon: const Icon(Icons.add_task),
            label: const Text('Add Requirement'),
          ),
          OutlinedButton.icon(
            onPressed: onRefreshContext,
            icon: const Icon(Icons.sync_outlined),
            label: const Text('Refresh Context'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.28)),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _notesCard(BuildContext context) {
    return _panel(
      context,
      title: 'Carry-Forward Notes',
      subtitle:
          'Keep prior planning, AI signals, and design assumptions visible.',
      icon: Icons.history_edu_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        VoiceTextField(
          controller: notesController,
          minLines: 6,
          maxLines: 8,
          decoration: InputDecoration(
            hintText:
                'Capture dependency notes, validation caveats, sponsor expectations, and implementation assumptions.',
            fillColor: const Color(0xFFF8FAFC),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${projectData.planningRequirementItems.length} planning requirements, ${projectData.frontEndPlanning.requirementItems.length} front-end requirements, and ${projectData.designDeliverablesData.register.length} deliverable register items are available as context.',
          style: const TextStyle(
              fontSize: 12, color: Color(0xFF64748B), height: 1.45),
        ),
      ]),
    );
  }

  Widget _coverage(_DashboardSnapshot snapshot) {
    final items = [
      (
        'Total Requirements',
        snapshot.total == 0 ? 0 : 100,
        '${snapshot.total} tracked',
        const Color(0xFF0F172A)
      ),
      (
        'Designed',
        snapshot.mappedPercent,
        '${snapshot.mapped} mapped',
        const Color(0xFF16A34A)
      ),
      (
        'Not Yet Designed',
        snapshot.unmappedPercent,
        '${snapshot.unmapped} pending',
        const Color(0xFFDC2626)
      ),
      (
        'Out of Scope',
        snapshot.outPercent,
        '${snapshot.outOfScope} excluded',
        const Color(0xFFF59E0B)
      ),
    ];

    return _panel(
      null,
      title: 'Implementation Coverage Dashboard',
      subtitle:
          'Coverage percentages and progress bars for traceable implementation readiness.',
      icon: Icons.analytics_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1160
              ? 4
              : constraints.maxWidth >= 720
                  ? 2
                  : 1;
          final spacing = 16.0;
          final width = columns == 1
              ? constraints.maxWidth
              : (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: items
                .map((item) => SizedBox(
                      width: width,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.$1,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF475569))),
                              const SizedBox(height: 14),
                              Text('${item.$2}%',
                                  style: TextStyle(
                                      fontSize: 34,
                                      height: 1,
                                      fontWeight: FontWeight.w900,
                                      color: item.$4)),
                              const SizedBox(height: 4),
                              Text(item.$3,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 14),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  minHeight: 8,
                                  value: item.$2 / 100,
                                  backgroundColor:
                                      item.$4.withOpacity(0.12),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(item.$4),
                                ),
                              ),
                            ]),
                      ),
                    ))
                .toList(),
          );
        },
      ),
    );
  }

  Widget _matrix(BuildContext context, List<_DisplayRequirement> rows,
      _DashboardSnapshot snapshot) {
    final visible =
        showAllRows || rows.length <= 6 ? rows : rows.take(6).toList();
    return _panel(
      context,
      title: 'Requirements Traceability Matrix (RTM)',
      subtitle:
          'Zebra-striped matrix connecting requirement statements to design artifacts and validation status.',
      icon: Icons.table_chart_outlined,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        _status('Mapped ${snapshot.mapped}', _Badge.success),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: rows.length <= 6 ? null : onToggleShowAll,
          icon: Icon(showAllRows
              ? Icons.unfold_less_outlined
              : Icons.unfold_more_outlined),
          label: Text(showAllRows ? 'Collapse' : 'Expand'),
        ),
      ]),
      child: rows.isEmpty
          ? const Text(
              'No requirements loaded yet. Refresh context or add a requirement to start the matrix.',
              style: TextStyle(
                  fontSize: 13, color: Color(0xFF64748B), height: 1.45))
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 1020),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(children: [
                      SizedBox(
                          width: 150,
                          child: Text('Requirement ID',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF334155)))),
                      SizedBox(width: 16),
                      SizedBox(
                          width: 330,
                          child: Text('Description',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF334155)))),
                      SizedBox(width: 16),
                      SizedBox(
                          width: 250,
                          child: Text('Design Artifact',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF334155)))),
                      SizedBox(width: 16),
                      SizedBox(
                          width: 170,
                          child: Text('Validation Status',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF334155)))),
                      SizedBox(width: 16),
                      SizedBox(
                          width: 110,
                          child: Text('Actions',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF334155)))),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  for (int index = 0; index < visible.length; index++) ...[
                    _matrixRow(visible[index], index),
                    if (index != visible.length - 1) const SizedBox(height: 8),
                  ],
                ]),
              ),
            ),
    );
  }

  Widget _matrixRow(_DisplayRequirement row, int index) {
    final selected = index == selectedRequirementIndex;
    final zebra = index.isOdd;
    return InkWell(
      onTap: () => onSelectRequirement(index),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFEFF6FF)
              : zebra
                  ? const Color(0xFFF8FAFC)
                  : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color:
                  selected ? const Color(0xFF60A5FA) : const Color(0xFFE2E8F0)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 150,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.requirementId,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A))),
                    const SizedBox(height: 8),
                    _status(
                        row.type,
                        row.type == 'Non-Functional'
                            ? _Badge.warning
                            : _Badge.info),
                  ])),
          const SizedBox(width: 16),
          SizedBox(
              width: 330,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    Text(row.definition,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            height: 1.45)),
                    const SizedBox(height: 8),
                    Text('Source: ${row.sourceDocument}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w600)),
                  ])),
          const SizedBox(width: 16),
          SizedBox(
            width: 250,
            child: row.isOutOfScope
                ? const Row(children: [
                    Icon(Icons.block_outlined,
                        size: 18, color: Color(0xFFF59E0B)),
                    SizedBox(width: 8),
                    Expanded(
                        child: Text('Held outside current release',
                            style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF92400E),
                                fontWeight: FontWeight.w700))),
                  ])
                : InkWell(
                    onTap: row.artifactLabel.isEmpty
                        ? null
                        : () => _handleArtifactTap(row.source),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: row.artifactLabel.isEmpty
                            ? const Color(0xFFF8FAFC)
                            : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: row.artifactLabel.isEmpty
                                ? const Color(0xFFE2E8F0)
                                : const Color(0xFFBFDBFE)),
                      ),
                      child: Row(children: [
                        Icon(
                            row.artifactType.toLowerCase().contains('pdf')
                                ? Icons.picture_as_pdf_outlined
                                : Icons.draw_outlined,
                            size: 18,
                            color: row.artifactLabel.isEmpty
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF1D4ED8)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            row.artifactLabel.isEmpty
                                ? 'Artifact not linked'
                                : row.artifactLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: row.artifactLabel.isEmpty
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF1D4ED8),
                              decoration: row.artifactLabel.isEmpty
                                  ? TextDecoration.none
                                  : TextDecoration.underline,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          SizedBox(
              width: 170,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _status(
                        row.validationStatus,
                        row.validationStatus == 'Mapped'
                            ? _Badge.success
                            : _Badge.danger),
                    const SizedBox(height: 8),
                    _status(
                        row.gapStatus,
                        row.gapStatus == 'Closed'
                            ? _Badge.success
                            : _Badge.warning),
                  ])),
          const SizedBox(width: 16),
          SizedBox(
            width: 110,
            child: Row(children: [
              IconButton(
                  onPressed: () => onSelectRequirement(index),
                  icon: const Icon(Icons.open_in_new_outlined),
                  color: const Color(0xFF1D4ED8)),
              IconButton(
                  onPressed: () => onDeleteRequirement(index),
                  icon: const Icon(Icons.delete_outline),
                  color: const Color(0xFFDC2626)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _allocation(_DashboardSnapshot snapshot) => _panel(
        null,
        title: 'Functional vs. Non-Functional Allocation',
        subtitle:
            'Split of behavioral requirements versus control and compliance constraints.',
        icon: Icons.donut_large_outlined,
        child: Column(children: [
          SizedBox(
            width: 150,
            height: 150,
            child: CustomPaint(
              painter: _DonutPainter(
                  functional: snapshot.functional,
                  nonFunctional: snapshot.nonFunctional),
              child: Center(
                child: Text(
                  '${snapshot.functionalPercent}%',
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _legend(const Color(0xFF2563EB), 'Functional', snapshot.functional),
          const SizedBox(height: 10),
          _legend(const Color(0xFFF59E0B), 'Non-Functional',
              snapshot.nonFunctional),
        ]),
      );

  Widget _gaps(_DashboardSnapshot snapshot) => _panel(
        null,
        title: 'Gap & Exception Analysis',
        subtitle:
            'Unmet requirements and exceptions still awaiting governance decisions.',
        icon: Icons.report_problem_outlined,
        child: snapshot.gaps.isEmpty
            ? const Text(
                'No active gap items. Current mapped requirements are closed and traceable.',
                style: TextStyle(
                    fontSize: 13, color: Color(0xFF64748B), height: 1.45))
            : Column(
                children: snapshot.gaps.take(5).map((row) {
                  final note = row.isOutOfScope
                      ? 'Excluded from current release and awaiting variation control.'
                      : row.conflictNote.isNotEmpty
                          ? row.conflictNote
                          : 'Requirement has not yet been fully mapped into a released design artifact.';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.pending_actions_outlined,
                                size: 18, color: Color(0xFFB45309)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(row.title,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF92400E)))),
                            _status(row.gapStatus, _Badge.warning),
                          ]),
                          const SizedBox(height: 8),
                          Text(note,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF78350F),
                                  height: 1.45)),
                        ]),
                  );
                }).toList(),
              ),
      );

  Widget _detail(BuildContext context, _DisplayRequirement? selected) => _panel(
        context,
        title: 'Acceptance Criteria & Source Verification',
        subtitle:
            'Editable form view for the selected requirement and its verification evidence.',
        icon: Icons.assignment_turned_in_outlined,
        child: selected == null
            ? const Text(
                'Select a requirement from the matrix to inspect and update it.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)))
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 10, runSpacing: 10, children: [
                  _status(selected.requirementId, _Badge.info),
                  _status(
                      selected.validationStatus,
                      selected.validationStatus == 'Mapped'
                          ? _Badge.success
                          : _Badge.danger),
                  if (selected.isOutOfScope)
                    _status('Out of Scope', _Badge.warning),
                ]),
                const SizedBox(height: 18),
                LayoutBuilder(builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 720;
                  final row = [
                    Expanded(
                        child: _field(
                            label: 'Requirement ID',
                            value: selected.requirementId,
                            fieldKey: '${selected.source.id}-reqid',
                            onChanged: (v) => onUpdateSelectedRequirement(
                                (c) => c.copyWith(requirementId: v.trim())))),
                    const SizedBox(width: 14, height: 14),
                    Expanded(
                        child: _dropdown(
                            label: 'Owner',
                            value: selected.source.owner,
                            items: ownerOptions,
                            onChanged: (v) => onUpdateSelectedRequirement(
                                (c) => c.copyWith(owner: v)))),
                    const SizedBox(width: 14, height: 14),
                    Expanded(
                        child: _dropdown(
                            label: 'Requirement Type',
                            value: selected.type,
                            items: const ['Functional', 'Non-Functional'],
                            onChanged: (v) => onUpdateSelectedRequirement((c) =>
                                c.copyWith(
                                    requirementType: v,
                                    designArtifactType: v == 'Non-Functional'
                                        ? 'PDF'
                                        : 'Figma')))),
                  ];
                  return stacked ? Column(children: row) : Row(children: row);
                }),
                const SizedBox(height: 14),
                LayoutBuilder(builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 720;
                  final row = [
                    Expanded(
                        child: _dropdown(
                            label: 'Source',
                            value: selected.source.ruleType,
                            items: const ['Internal', 'External'],
                            onChanged: (v) => onUpdateSelectedRequirement(
                                (c) => c.copyWith(ruleType: v)))),
                    const SizedBox(width: 14, height: 14),
                    Expanded(
                        child: _dropdown(
                            label: 'Source Type',
                            value: selected.source.sourceType,
                            items: const [
                              'Contract',
                              'Vendor',
                              'Regulatory',
                              'Standard'
                            ],
                            onChanged: (v) => onUpdateSelectedRequirement(
                                (c) => c.copyWith(sourceType: v)))),
                  ];
                  return stacked ? Column(children: row) : Row(children: row);
                }),
                const SizedBox(height: 14),
                _field(
                    label: 'Description',
                    value: selected.title,
                    fieldKey: '${selected.source.id}-title',
                    maxLines: 2,
                    onChanged: (v) => onUpdateSelectedRequirement(
                        (c) => c.copyWith(title: v))),
                const SizedBox(height: 14),
                _field(
                    label: 'Definition / Intent',
                    value: selected.definition,
                    fieldKey: '${selected.source.id}-definition',
                    maxLines: 3,
                    onChanged: (v) => onUpdateSelectedRequirement(
                        (c) => c.copyWith(definition: v))),
                const SizedBox(height: 14),
                LayoutBuilder(builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 720;
                  final row = [
                    Expanded(
                      flex: 2,
                      child: _field(
                        label: 'Design Artifact',
                        value: selected.artifactLabel,
                        fieldKey: '${selected.source.id}-artifact',
                        onChanged: (v) =>
                            onUpdateSelectedRequirement((c) => c.copyWith(
                                  designArtifactLabel: v,
                                  validationStatus: v.trim().isNotEmpty &&
                                          !c.isOutOfScope &&
                                          c.validationStatus == 'Unmapped'
                                      ? 'Mapped'
                                      : c.validationStatus,
                                )),
                      ),
                    ),
                    const SizedBox(width: 14, height: 14),
                    Expanded(
                        child: _dropdown(
                            label: 'Artifact Type',
                            value: selected.artifactType,
                            items: const ['Figma', 'PDF'],
                            onChanged: (v) => onUpdateSelectedRequirement(
                                (c) => c.copyWith(designArtifactType: v)))),
                    const SizedBox(width: 14, height: 14),
                    Expanded(
                        child: _dropdown(
                            label: 'Validation Status',
                            value: selected.validationStatus,
                            items: const ['Mapped', 'Unmapped'],
                            onChanged: (v) => onUpdateSelectedRequirement((c) =>
                                c.copyWith(
                                    validationStatus:
                                        c.isOutOfScope ? 'Unmapped' : v)))),
                  ];
                  return stacked ? Column(children: row) : Row(children: row);
                }),
                const SizedBox(height: 14),
                _field(
                    label: 'Criteria',
                    value: selected.acceptanceCriteria,
                    fieldKey: '${selected.source.id}-criteria',
                    maxLines: 4,
                    onChanged: (v) => onUpdateSelectedRequirement(
                        (c) => c.copyWith(acceptanceCriteria: v))),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                      child: _field(
                          label: 'Test Method',
                          value: selected.testMethod,
                          fieldKey: '${selected.source.id}-test',
                          onChanged: (v) => onUpdateSelectedRequirement(
                              (c) => c.copyWith(testMethod: v)))),
                  const SizedBox(width: 14),
                  Expanded(
                      child: _field(
                          label: 'Source Document',
                          value: selected.sourceDocument,
                          fieldKey: '${selected.source.id}-source',
                          onChanged: (v) => onUpdateSelectedRequirement(
                              (c) => c.copyWith(sourceDocument: v)))),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                      child: _field(
                          label: 'Artifact URL',
                          value: selected.source.designArtifactUrl,
                          fieldKey: '${selected.source.id}-artifact-url',
                          onChanged: (v) => onUpdateSelectedRequirement(
                              (c) => c.copyWith(designArtifactUrl: v.trim())))),
                  const SizedBox(width: 14),
                  ElevatedButton.icon(
                    onPressed: () => onUploadArtifact(selected.source),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload File'),
                  ),
                ]),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Material(
                    type: MaterialType.transparency,
                    child: SwitchListTile.adaptive(
                    title: const Text('Mark as out of scope',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A))),
                    subtitle: const Text(
                        'Keep the requirement visible in governance without consuming active design effort.',
                        style: TextStyle(
                            fontSize: 12.5, color: Color(0xFF64748B))),
                    value: selected.isOutOfScope,
                    onChanged: (v) => onUpdateSelectedRequirement((c) =>
                        c.copyWith(
                            isOutOfScope: v,
                            validationStatus:
                                v ? 'Unmapped' : c.validationStatus,
                            designArtifactLabel: v ? '' : c.designArtifactLabel,
                            gapStatus: v ? 'Pending Approval' : c.gapStatus)),
                  ),
                    ),
                ),
              ]),
      );

  Widget _conflicts(BuildContext context, _DashboardSnapshot snapshot,
          _DisplayRequirement? selected) =>
      _panel(
        context,
        title: 'Conflict Resolver & Change Impact',
        subtitle:
            'Warning-style list of active conflicts between requirements and design outputs.',
        icon: Icons.warning_amber_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (snapshot.conflicts.isEmpty)
            const Text(
                'No active requirement conflicts are currently registered.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)))
          else
            ...snapshot.conflicts.take(4).map((row) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFECACA))),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 20, color: Color(0xFFDC2626)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(row.title,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF991B1B))),
                              const SizedBox(height: 6),
                              Text(
                                  row.conflictNote.isNotEmpty
                                      ? row.conflictNote
                                      : 'Potential mismatch between requirement intent and design response.',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF7F1D1D),
                                      height: 1.45)),
                            ])),
                        _status(
                            '${row.conflictImpact} Impact',
                            row.conflictImpact == 'High'
                                ? _Badge.danger
                                : _Badge.warning),
                      ]),
                )),
          if (selected != null) ...[
            const SizedBox(height: 6),
            const Divider(),
            const SizedBox(height: 14),
            Text('Selected Requirement Controls',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A))),
            const SizedBox(height: 12),
            _field(
                label: 'Conflict Note',
                value: selected.conflictNote,
                fieldKey: '${selected.source.id}-conflict',
                maxLines: 4,
                hintText:
                    'Describe the contradiction, dependency, or missing design response.',
                onChanged: (v) => onUpdateSelectedRequirement(
                    (c) => c.copyWith(conflictNote: v))),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: _dropdown(
                      label: 'Impact Level',
                      value: selected.conflictImpact,
                      items: const ['High', 'Low'],
                      onChanged: (v) => onUpdateSelectedRequirement(
                          (c) => c.copyWith(conflictImpact: v)))),
              const SizedBox(width: 14),
              Expanded(
                  child: _dropdown(
                      label: 'Gap Status',
                      value: selected.gapStatus,
                      items: const ['Pending Approval', 'Closed'],
                      onChanged: (v) => onUpdateSelectedRequirement(
                          (c) => c.copyWith(gapStatus: v)))),
            ]),
          ],
        ]),
      );

  Widget _panel(BuildContext? context,
      {required String title,
      required String subtitle,
      required IconData icon,
      Widget? trailing,
      required Widget child}) {
    final theme = context != null ? Theme.of(context) : null;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0E0F172A), blurRadius: 24, offset: Offset(0, 12))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: const Color(0xFF0F172A))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: theme?.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A)) ??
                        const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        height: 1.45)),
              ])),
          if (trailing != null) ...[const SizedBox(width: 12), trailing],
        ]),
        const SizedBox(height: 20),
        child,
      ]),
    );
  }

  Widget _status(String label, _Badge badge) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: badge.background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: badge.border)),
        child: Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: badge.foreground)),
      );

  Widget _metricPill(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.72))),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
        ]),
      );

  Widget _pill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.18))),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800)),
      );

  Widget _legend(Color color, String label, int value) => Row(children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(999))),
        const SizedBox(width: 10),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A)))),
        Text('$value',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF475569))),
      ]);

  Widget _field(
          {required String label,
          required String value,
          required String fieldKey,
          required ValueChanged<String> onChanged,
          int maxLines = 1,
          String? hintText}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF475569))),
          const SizedBox(height: 8),
          VoiceTextFormField(
            key: ValueKey(fieldKey),
            initialValue: value,
            maxLines: maxLines,
            minLines: maxLines > 1 ? maxLines : 1,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hintText,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFF1D4ED8), width: 1.4)),
            ),
          ),
        ],
      );

  Widget _dropdown(
      {required String label,
      required String value,
      required List<String> items,
      required ValueChanged<String> onChanged}) {
    final options = items.contains(value) ? items : [value, ...items];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF475569))),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: options.first,
        isExpanded: true,
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFF1D4ED8), width: 1.4)),
        ),
        items: options
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: (selected) {
          if (selected == null) return;
          onChanged(selected);
        },
      ),
    ]);
  }
}

class _DisplayRequirement {
  const _DisplayRequirement({
    required this.source,
    required this.requirementId,
    required this.title,
    required this.definition,
    required this.type,
    required this.artifactLabel,
    required this.artifactType,
    required this.validationStatus,
    required this.acceptanceCriteria,
    required this.testMethod,
    required this.sourceDocument,
    required this.gapStatus,
    required this.conflictNote,
    required this.conflictImpact,
    required this.isOutOfScope,
  });

  final RequirementRow source;
  final String requirementId;
  final String title;
  final String definition;
  final String type;
  final String artifactLabel;
  final String artifactType;
  final String validationStatus;
  final String acceptanceCriteria;
  final String testMethod;
  final String sourceDocument;
  final String gapStatus;
  final String conflictNote;
  final String conflictImpact;
  final bool isOutOfScope;
}

class _DashboardSnapshot {
  const _DashboardSnapshot({
    required this.total,
    required this.mapped,
    required this.unmapped,
    required this.outOfScope,
    required this.functional,
    required this.nonFunctional,
    required this.artifacts,
    required this.aiSignals,
    required this.gaps,
    required this.conflicts,
  });

  final int total;
  final int mapped;
  final int unmapped;
  final int outOfScope;
  final int functional;
  final int nonFunctional;
  final int artifacts;
  final int aiSignals;
  final List<_DisplayRequirement> gaps;
  final List<_DisplayRequirement> conflicts;

  int get mappedPercent => total == 0 ? 0 : ((mapped / total) * 100).round();
  int get unmappedPercent =>
      total == 0 ? 0 : ((unmapped / total) * 100).round();
  int get outPercent => total == 0 ? 0 : ((outOfScope / total) * 100).round();
  int get functionalPercent => (functional + nonFunctional) == 0
      ? 0
      : ((functional / (functional + nonFunctional)) * 100).round();

  factory _DashboardSnapshot.from(
      {required ProjectDataModel projectData,
      required List<_DisplayRequirement> requirements,
      required List<RequirementChecklistItem> checklistItems}) {
    final mapped = requirements
        .where((row) => row.validationStatus == 'Mapped' && !row.isOutOfScope)
        .length;
    final outOfScope = requirements.where((row) => row.isOutOfScope).length;
    final total = requirements.length;
    return _DashboardSnapshot(
      total: total,
      mapped: mapped,
      unmapped: math.max(0, total - mapped - outOfScope),
      outOfScope: outOfScope,
      functional: requirements.where((row) => row.type == 'Functional').length,
      nonFunctional:
          requirements.where((row) => row.type == 'Non-Functional').length,
      artifacts:
          requirements.where((row) => row.artifactLabel.isNotEmpty).length,
      aiSignals: projectData.aiUsageCounts.values
              .fold<int>(0, (sum, value) => sum + value) +
          projectData.aiRecommendations.length +
          projectData.aiIntegrations.length,
      gaps: requirements
          .where((row) =>
              row.isOutOfScope ||
              row.validationStatus != 'Mapped' ||
              row.gapStatus != 'Closed')
          .toList(),
      conflicts: requirements
          .where((row) =>
              row.conflictNote.isNotEmpty ||
              row.conflictImpact == 'High' ||
              row.isOutOfScope)
          .toList(),
    );
  }
}

class _Badge {
  const _Badge(this.background, this.border, this.foreground);
  final Color background;
  final Color border;
  final Color foreground;
  static const info =
      _Badge(Color(0xFFEFF6FF), Color(0xFFBFDBFE), Color(0xFF1D4ED8));
  static const success =
      _Badge(Color(0xFFECFDF5), Color(0xFFA7F3D0), Color(0xFF047857));
  static const warning =
      _Badge(Color(0xFFFFFBEB), Color(0xFFFDE68A), Color(0xFFB45309));
  static const danger =
      _Badge(Color(0xFFFEF2F2), Color(0xFFFECACA), Color(0xFFB91C1C));
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.functional, required this.nonFunctional});
  final int functional;
  final int nonFunctional;

  @override
  void paint(Canvas canvas, Size size) {
    final total = functional + nonFunctional;
    final rect = Offset.zero & size;
    final stroke = size.width * 0.18;
    final bg = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        rect.deflate(stroke / 2), -math.pi / 2, math.pi * 2, false, bg);
    if (total == 0) return;
    final blue = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final amber = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final blueSweep = (functional / total) * math.pi * 2;
    canvas.drawArc(
        rect.deflate(stroke / 2), -math.pi / 2, blueSweep, false, blue);
    canvas.drawArc(rect.deflate(stroke / 2), -math.pi / 2 + blueSweep,
        (nonFunctional / total) * math.pi * 2, false, amber);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.functional != functional ||
      oldDelegate.nonFunctional != nonFunctional;
}
