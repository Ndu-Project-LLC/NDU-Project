import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/design_phase_models.dart';
import 'package:ndu_project/models/project_activity.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/widgets/csv_table_import_button.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/responsive_table_widgets.dart';

class DesignGovernanceDashboard extends StatelessWidget {
  const DesignGovernanceDashboard({
    super.key,
    required this.projectData,
    required this.managementData,
    this.readiness,
    this.architectureNodeCount = 0,
    this.onImportChangeLog,
    this.onImportRfi,
  });

  final ProjectDataModel projectData;
  final DesignManagementData managementData;
  final DesignReadinessModel? readiness;
  final int architectureNodeCount;

  /// Callback when CSV rows are imported for the Change Control & Variation Log.
  final ValueChanged<List<Map<String, String>>>? onImportChangeLog;

  /// Callback when CSV rows are imported for the RFI Log.
  final ValueChanged<List<Map<String, String>>>? onImportRfi;

  @override
  Widget build(BuildContext context) {
    final snapshot = _GovernanceSnapshot.from(
      projectData: projectData,
      managementData: managementData,
      readiness: readiness ?? managementData.readiness,
      architectureNodeCount: architectureNodeCount,
    );
    final isMobile = AppBreakpoints.isMobile(context);
    final spacing = isMobile ? 16.0 : 20.0;

    final lowerCards = [
      _buildAuditTrailCard(snapshot),
      _buildVersionControlCard(snapshot),
      _buildCoordinationCard(snapshot),
      _buildDecisionRegisterCard(snapshot),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHubHeader(context, snapshot),
        SizedBox(height: spacing),
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildReviewScheduleCard(snapshot),
              SizedBox(height: spacing),
              _buildWorkloadCard(snapshot),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildReviewScheduleCard(snapshot)),
              SizedBox(width: spacing),
              Expanded(child: _buildWorkloadCard(snapshot)),
            ],
          ),
        SizedBox(height: spacing),
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildChangeControlCard(snapshot),
              SizedBox(height: spacing),
              _buildRfiCard(snapshot),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildChangeControlCard(snapshot)),
              SizedBox(width: spacing),
              Expanded(child: _buildRfiCard(snapshot)),
            ],
          ),
        SizedBox(height: spacing),
        LayoutBuilder(
          builder: (context, constraints) {
            final columnCount = constraints.maxWidth >= 1360
                ? 4
                : constraints.maxWidth >= 900
                    ? 2
                    : 1;
            final tileWidth = columnCount == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - (spacing * (columnCount - 1))) /
                    columnCount;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: lowerCards
                  .map((card) => SizedBox(width: tileWidth, child: card))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHubHeader(BuildContext context, _GovernanceSnapshot snapshot) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF111827),
            Color(0xFF1E293B),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180F172A),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.14)),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Governance & Administration Hub',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_fallbackText(projectData.projectName, 'Current design package')} is orchestrating review gates from prior scope, risks, milestones, team inputs, and AI-assisted working notes.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.82),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _HeaderBadge(
                label: '${snapshot.readinessPercent}% ready',
                icon: Icons.verified_outlined,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricPill(
                label: 'Controlled Changes',
                value: snapshot.changeLog.length.toString(),
              ),
              _MetricPill(
                label: 'Open RFIs',
                value: snapshot.openRfiCount.toString(),
              ),
              _MetricPill(
                label: 'Team Signals',
                value: snapshot.workload.length.toString(),
              ),
              _MetricPill(
                label: 'AI Context',
                value: snapshot.aiSignalCount.toString(),
              ),
              _MetricPill(
                label: 'Locked Versions',
                value: snapshot.lockedVersionCount.toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewScheduleCard(_GovernanceSnapshot snapshot) {
    return _GovernanceCard(
      title: 'Design Review & Gatekeeping Schedule',
      subtitle:
          'Sequenced from current readiness, planning milestones, and design-control expectations.',
      icon: Icons.timeline_outlined,
      trailing: _CompactInfoChip(
        label:
            '${snapshot.reviewStages.where((stage) => stage.isComplete).length}/${snapshot.reviewStages.length} gates touched',
        color: const Color(0xFF2563EB),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final usableWidth = math.max(120.0, constraints.maxWidth - 40);
              return SizedBox(
                height: 116,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 28,
                      left: 18,
                      right: 18,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 28,
                      left: 18,
                      child: Container(
                        width: ((usableWidth - 8) *
                                (snapshot.readinessPercent / 100.0))
                            .clamp(0.0, usableWidth),
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF0F172A),
                              Color(0xFFF59E0B),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    ...snapshot.reviewStages.map((stage) {
                      final position =
                          18 + ((usableWidth - 8) * (stage.percent / 100));
                      return Positioned(
                        left: position.clamp(0.0, usableWidth + 18),
                        top: 10,
                        child: Transform.translate(
                          offset: const Offset(-14, 0),
                          child: SizedBox(
                            width: 90,
                            child: Column(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: stage.isActive
                                        ? const Color(0xFFF59E0B)
                                        : stage.isComplete
                                            ? const Color(0xFF0F172A)
                                            : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: stage.isActive || stage.isComplete
                                          ? Colors.transparent
                                          : const Color(0xFFCBD5E1),
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    stage.isComplete
                                        ? Icons.check
                                        : stage.isActive
                                            ? Icons.flag_outlined
                                            : Icons.radio_button_unchecked,
                                    size: 16,
                                    color: stage.isActive || stage.isComplete
                                        ? Colors.white
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${stage.percent.toInt()}% ${stage.label}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: stage.isActive
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  stage.note,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    height: 1.35,
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
            },
          ),
          const SizedBox(height: 12),
          const _SectionLabel('Required Attendees'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: snapshot.attendees
                .map(
                  (attendee) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      attendee,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkloadCard(_GovernanceSnapshot snapshot) {
    return _GovernanceCard(
      title: 'Team Workload & Utilization',
      subtitle:
          'Allocation is inferred from the live roster, activity log, risks, and design-control workload.',
      icon: Icons.stacked_bar_chart_outlined,
      trailing: _CompactInfoChip(
        label: '${snapshot.overloadedCount} overloaded',
        color: snapshot.overloadedCount > 0
            ? const Color(0xFFDC2626)
            : const Color(0xFF16A34A),
      ),
      child: Column(
        children: snapshot.workload
            .map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                entry.role,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _StatusBadge(
                          label: entry.status,
                          background: entry.backgroundColor,
                          foreground: entry.foregroundColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: entry.utilization / 100,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          entry.barColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${entry.utilization.toInt()}% allocated',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.note,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildChangeControlCard(_GovernanceSnapshot snapshot) {
    return _GovernanceCard(
      title: 'Change Control & Variation Log',
      subtitle:
          'Pulled from inherited scope, constraints, requirements, and governance-derived design actions.',
      icon: Icons.change_circle_outlined,
      trailing: onImportChangeLog != null
          ? CsvTableImportButton(
              tableTitle: 'Change Control & Variation Log',
              compact: true,
              columns: const [
                CsvColumnSpec(
                    key: 'changeId',
                    label: 'Change ID',
                    required: true,
                    sampleValue: 'CC-01',
                    hint: 'Unique change identifier'),
                CsvColumnSpec(
                    key: 'description',
                    label: 'Description',
                    required: true,
                    sampleValue: 'Scope refinement',
                    hint: 'Change description'),
                CsvColumnSpec(
                    key: 'impact',
                    label: 'Impact Assessment',
                    required: false,
                    sampleValue: 'Updates baseline package',
                    hint: 'Impact of the change'),
                CsvColumnSpec(
                    key: 'status',
                    label: 'Status',
                    required: false,
                    allowedValues: [
                      'Open',
                      'Under Review',
                      'Approved',
                      'Rejected',
                      'Implemented'
                    ],
                    defaultValue: 'Open',
                    sampleValue: 'Open',
                    hint: 'Current status'),
              ],
              onImport: onImportChangeLog!,
            )
          : null,
      child: ResponsiveDataTableWrapper(
        minWidth: 720,
        maxHeight: 336,
        child: Column(
          children: [
            const _TableHeaderRow(
              flexes: [2, 5, 5, 3],
              labels: [
                'Change ID',
                'Description',
                'Impact Assessment',
                'Status',
              ],
            ),
            ...snapshot.changeLog.map(
              (entry) => _TableDataRow(
                flexes: const [2, 5, 5, 3],
                cells: [
                  Text(
                    entry.id,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  TruncatedTableCell(
                    text: entry.description,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0F172A),
                      height: 1.4,
                    ),
                  ),
                  TruncatedTableCell(
                    text: entry.impact,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _StatusBadge(
                      label: entry.status,
                      background: entry.backgroundColor,
                      foreground: entry.foregroundColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRfiCard(_GovernanceSnapshot snapshot) {
    return _GovernanceCard(
      title: 'Request for Information (RFI) Log',
      subtitle:
          'Questions are framed from outstanding requirements, interfaces, and discipline handoffs.',
      icon: Icons.help_outline,
      trailing: onImportRfi != null
          ? CsvTableImportButton(
              tableTitle: 'RFI Log',
              compact: true,
              columns: const [
                CsvColumnSpec(
                    key: 'question',
                    label: 'Question',
                    required: true,
                    sampleValue: 'Confirm requirement intent',
                    hint: 'RFI question text'),
                CsvColumnSpec(
                    key: 'dueDate',
                    label: 'Due Date',
                    required: false,
                    sampleValue: '2025-04-15',
                    hint: 'e.g. 2025-04-15'),
                CsvColumnSpec(
                    key: 'response',
                    label: 'Response',
                    required: false,
                    sampleValue: 'Awaiting response',
                    hint: 'Response or status'),
              ],
              onImport: onImportRfi!,
            )
          : null,
      child: ResponsiveDataTableWrapper(
        minWidth: 620,
        maxHeight: 336,
        child: Column(
          children: [
            const _TableHeaderRow(
              flexes: [6, 2, 3],
              labels: ['Question', 'Due Date', 'Response'],
            ),
            ...snapshot.rfis.map(
              (entry) => _TableDataRow(
                flexes: const [6, 2, 3],
                cells: [
                  TruncatedTableCell(
                    text: entry.question,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0F172A),
                      height: 1.4,
                    ),
                  ),
                  Text(
                    entry.dueDate,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _StatusBadge(
                      label: entry.status,
                      background: entry.backgroundColor,
                      foreground: entry.foregroundColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditTrailCard(_GovernanceSnapshot snapshot) {
    return _GovernanceCard(
      title: 'Quality Assurance & Audit Trail',
      subtitle:
          'Checklist combines software controls with physical compliance checks for the active design package.',
      icon: Icons.fact_check_outlined,
      child: Column(
        children: snapshot.audits
            .map(
              (entry) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: entry.pass
                            ? AppSemanticColors.successSurface
                            : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        entry.pass ? Icons.check : Icons.close,
                        size: 18,
                        color: entry.pass
                            ? AppSemanticColors.success
                            : const Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              _StatusBadge(
                                label: entry.pass ? 'Pass' : 'Fail',
                                background: entry.pass
                                    ? AppSemanticColors.successSurface
                                    : const Color(0xFFFEE2E2),
                                foreground: entry.pass
                                    ? AppSemanticColors.success
                                    : const Color(0xFFDC2626),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            entry.note,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildVersionControlCard(_GovernanceSnapshot snapshot) {
    return _GovernanceCard(
      title: 'Configuration & Version Control',
      subtitle:
          'Release notes respond to actual design maturity, linked documents, and architecture workspace progress.',
      icon: Icons.lock_outline,
      child: Column(
        children: snapshot.versions
            .map(
              (entry) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: entry.locked
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: entry.locked
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: entry.locked
                            ? Colors.white.withOpacity(0.08)
                            : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        entry.locked
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                        size: 18,
                        color: entry.locked
                            ? Colors.white
                            : const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.version,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: entry.locked
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              Text(
                                entry.locked ? 'Locked' : 'Working',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: entry.locked
                                      ? Colors.white.withOpacity(0.78)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            entry.notes,
                            style: TextStyle(
                              fontSize: 12,
                              color: entry.locked
                                  ? Colors.white.withOpacity(0.82)
                                  : const Color(0xFF64748B),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildCoordinationCard(_GovernanceSnapshot snapshot) {
    return _GovernanceCard(
      title: 'Inter-Discipline Coordination',
      subtitle:
          'Conflict board reflects the active state of architecture, software, and venue-facing disciplines.',
      icon: Icons.hub_outlined,
      child: Column(
        children: snapshot.coordination
            .map(
              (entry) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: BoxDecoration(
                        color: entry.resolved
                            ? AppSemanticColors.success
                            : const Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.discipline,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              _StatusBadge(
                                label: entry.resolved ? 'Resolved' : 'Pending',
                                background: entry.resolved
                                    ? AppSemanticColors.successSurface
                                    : const Color(0xFFFFF7E6),
                                foreground: entry.resolved
                                    ? AppSemanticColors.success
                                    : const Color(0xFFD97706),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            entry.note,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildDecisionRegisterCard(_GovernanceSnapshot snapshot) {
    return _GovernanceCard(
      title: 'Decision Register',
      subtitle:
          'Key governance decisions are tied back to delivery context rather than isolated screen state.',
      icon: Icons.rule_folder_outlined,
      child: Column(
        children: snapshot.decisions
            .map(
              (entry) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.gavel_outlined,
                        size: 18,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            entry.rationale,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _GovernanceCard extends StatelessWidget {
  const _GovernanceCard({
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0F172A),
                      Color(0xFF1E293B),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _GovernanceSnapshot {
  const _GovernanceSnapshot({
    required this.readinessPercent,
    required this.aiSignalCount,
    required this.reviewStages,
    required this.attendees,
    required this.workload,
    required this.changeLog,
    required this.rfis,
    required this.audits,
    required this.versions,
    required this.coordination,
    required this.decisions,
    required this.lockedVersionCount,
    required this.openRfiCount,
    required this.overloadedCount,
  });

  final int readinessPercent;
  final int aiSignalCount;
  final List<_ReviewStage> reviewStages;
  final List<String> attendees;
  final List<_WorkloadEntry> workload;
  final List<_ChangeLogEntry> changeLog;
  final List<_RfiEntry> rfis;
  final List<_AuditEntry> audits;
  final List<_VersionEntry> versions;
  final List<_CoordinationEntry> coordination;
  final List<_DecisionEntry> decisions;
  final int lockedVersionCount;
  final int openRfiCount;
  final int overloadedCount;

  factory _GovernanceSnapshot.from({
    required ProjectDataModel projectData,
    required DesignManagementData managementData,
    required DesignReadinessModel readiness,
    required int architectureNodeCount,
  }) {
    final readinessPercent =
        (readiness.overallScore * 100).round().clamp(18, 100);
    final aiSignalCount = projectData.aiRecommendations.length +
        projectData.aiIntegrations.length;
    final reviewStages = _buildReviewStages(
      projectData: projectData,
      readinessPercent: readinessPercent.toDouble(),
    );
    final attendees = _buildAttendees(projectData, managementData);
    final workload = _buildWorkload(
      projectData: projectData,
      managementData: managementData,
      architectureNodeCount: architectureNodeCount,
    );
    final changeLog = _buildChangeLog(projectData, managementData);
    final rfis = _buildRfis(projectData);
    final audits = _buildAudits(
      projectData: projectData,
      managementData: managementData,
      architectureNodeCount: architectureNodeCount,
    );
    final versions = _buildVersions(
      projectData: projectData,
      managementData: managementData,
      readinessPercent: readinessPercent.toDouble(),
      architectureNodeCount: architectureNodeCount,
    );
    final coordination = _buildCoordination(
      projectData: projectData,
      managementData: managementData,
      architectureNodeCount: architectureNodeCount,
    );
    final decisions = _buildDecisions(
      projectData: projectData,
      managementData: managementData,
      readinessPercent: readinessPercent.toDouble(),
      architectureNodeCount: architectureNodeCount,
    );

    return _GovernanceSnapshot(
      readinessPercent: readinessPercent,
      aiSignalCount: aiSignalCount,
      reviewStages: reviewStages,
      attendees: attendees,
      workload: workload,
      changeLog: changeLog,
      rfis: rfis,
      audits: audits,
      versions: versions,
      coordination: coordination,
      decisions: decisions,
      lockedVersionCount: versions.where((entry) => entry.locked).length,
      openRfiCount: rfis.where((entry) => entry.status != 'Answered').length,
      overloadedCount:
          workload.where((entry) => entry.status == 'Overloaded').length,
    );
  }
}

class _ReviewStage {
  const _ReviewStage({
    required this.percent,
    required this.label,
    required this.note,
    required this.isComplete,
    required this.isActive,
  });

  final double percent;
  final String label;
  final String note;
  final bool isComplete;
  final bool isActive;
}

class _WorkloadEntry {
  const _WorkloadEntry({
    required this.name,
    required this.role,
    required this.utilization,
    required this.status,
    required this.note,
    required this.barColor,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String name;
  final String role;
  final double utilization;
  final String status;
  final String note;
  final Color barColor;
  final Color backgroundColor;
  final Color foregroundColor;
}

class _ChangeLogEntry {
  const _ChangeLogEntry({
    required this.id,
    required this.description,
    required this.impact,
    required this.status,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String id;
  final String description;
  final String impact;
  final String status;
  final Color backgroundColor;
  final Color foregroundColor;
}

class _RfiEntry {
  const _RfiEntry({
    required this.question,
    required this.dueDate,
    required this.status,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String question;
  final String dueDate;
  final String status;
  final Color backgroundColor;
  final Color foregroundColor;
}

class _AuditEntry {
  const _AuditEntry({
    required this.title,
    required this.note,
    required this.pass,
  });

  final String title;
  final String note;
  final bool pass;
}

class _VersionEntry {
  const _VersionEntry({
    required this.version,
    required this.notes,
    required this.locked,
  });

  final String version;
  final String notes;
  final bool locked;
}

class _CoordinationEntry {
  const _CoordinationEntry({
    required this.discipline,
    required this.note,
    required this.resolved,
  });

  final String discipline;
  final String note;
  final bool resolved;
}

class _DecisionEntry {
  const _DecisionEntry({
    required this.title,
    required this.rationale,
  });

  final String title;
  final String rationale;
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactInfoChip extends StatelessWidget {
  const _CompactInfoChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Color(0xFF64748B),
        letterSpacing: 0.4,
      ),
    );
  }
}

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow({
    required this.flexes,
    required this.labels,
  });

  final List<int> flexes;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          return Expanded(
            flex: flexes[index],
            child: Padding(
              padding:
                  EdgeInsets.only(right: index == labels.length - 1 ? 0 : 12),
              child: Text(
                labels[index],
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF475569),
                  letterSpacing: 0.25,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TableDataRow extends StatelessWidget {
  const _TableDataRow({
    required this.flexes,
    required this.cells,
  });

  final List<int> flexes;
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(cells.length, (index) {
          return Expanded(
            flex: flexes[index],
            child: Padding(
              padding:
                  EdgeInsets.only(right: index == cells.length - 1 ? 0 : 12),
              child: cells[index],
            ),
          );
        }),
      ),
    );
  }
}

List<_ReviewStage> _buildReviewStages({
  required ProjectDataModel projectData,
  required double readinessPercent,
}) {
  final reviewNotes = _nextMilestoneNotes(projectData.keyMilestones);
  const stages = [
    (30.0, 'Concept'),
    (60.0, 'Coordination'),
    (90.0, 'Final'),
    (100.0, 'Issue'),
  ];

  return List.generate(stages.length, (index) {
    final percent = stages[index].$1;
    final note = reviewNotes.length > index
        ? reviewNotes[index]
        : index == 0
            ? 'Baseline package aligned'
            : index == 1
                ? 'Cross-discipline clash review'
                : index == 2
                    ? 'Client and PMO sign-off'
                    : 'Controlled release package';
    final nextPercent =
        index == stages.length - 1 ? 1000.0 : stages[index + 1].$1;
    return _ReviewStage(
      percent: percent,
      label: stages[index].$2,
      note: note,
      isComplete: readinessPercent >= percent,
      isActive: readinessPercent >= percent && readinessPercent < nextPercent,
    );
  });
}

List<String> _buildAttendees(
  ProjectDataModel projectData,
  DesignManagementData managementData,
) {
  final attendees = <String>[];
  for (final member in projectData.teamMembers) {
    final displayName =
        member.name.trim().isNotEmpty ? member.name.trim() : member.role.trim();
    if (displayName.isEmpty) {
      continue;
    }
    attendees.add(member.role.trim().isNotEmpty
        ? '$displayName · ${member.role.trim()}'
        : displayName);
    if (attendees.length == 5) {
      break;
    }
  }

  if (attendees.isEmpty) {
    attendees.addAll([
      'Project Lead · Governance',
      'Design Authority · Architecture',
      'UI/UX Lead · Experience',
      managementData.industry == ProjectIndustry.construction
          ? 'Venue Safety Lead · Compliance'
          : 'API Lead · Integration',
      'Client Approver · Sign-off',
    ]);
  }

  if (projectData.aiRecommendations.isNotEmpty ||
      projectData.aiIntegrations.isNotEmpty) {
    attendees.add('AI Governance · Advisory');
  }

  return attendees.take(6).toList();
}

List<_WorkloadEntry> _buildWorkload({
  required ProjectDataModel projectData,
  required DesignManagementData managementData,
  required int architectureNodeCount,
}) {
  final entries = <_WorkloadEntry>[];
  final complexityScore = projectData.withinScopeItems.length +
      (projectData.frontEndPlanning.requirementItems.length * 2) +
      projectData.frontEndPlanning.riskRegisterItems.length +
      projectData.interfaceEntries.length +
      math.max(1, architectureNodeCount ~/ 2) +
      projectData.designDeliverablesData.register.length;

  List<(String, String)> fallbackRoster() {
    return [
      ('Project Lead', 'Governance'),
      ('Design Authority', 'Architecture'),
      ('Frontend Lead', 'UI/UX'),
      managementData.industry == ProjectIndustry.construction
          ? ('Venue Safety Lead', 'Safety / AV')
          : ('Integration Lead', 'Backend / API'),
    ];
  }

  final roster = projectData.teamMembers.isNotEmpty
      ? projectData.teamMembers
          .map((member) => (
                _fallbackText(
                    member.name, _fallbackText(member.role, 'Team Member')),
                _fallbackText(member.role, 'Design Team')
              ))
          .take(5)
          .toList()
      : fallbackRoster();

  for (var index = 0; index < roster.length; index++) {
    final item = roster[index];
    final name = item.$1;
    final role = item.$2;
    final assignedSignals =
        _countAssignedSignals(projectData.projectActivities, name, role);
    final utilization = (34 +
            (complexityScore * 1.8) +
            (_roleWeight(role) * 0.65) +
            (assignedSignals * 11) +
            (index * 4))
        .clamp(42.0, 96.0);

    final status = utilization >= 85
        ? 'Overloaded'
        : utilization >= 68
            ? 'At capacity'
            : 'Available';
    final colors = _statusColors(status);

    entries.add(
      _WorkloadEntry(
        name: name,
        role: role,
        utilization: utilization,
        status: status,
        note: assignedSignals > 0
            ? '$assignedSignals governed workstreams currently pointing at this role'
            : 'Capacity inferred from current design complexity and review pressure',
        barColor: status == 'Overloaded'
            ? const Color(0xFFDC2626)
            : status == 'At capacity'
                ? const Color(0xFFF59E0B)
                : const Color(0xFF16A34A),
        backgroundColor: colors.$1,
        foregroundColor: colors.$2,
      ),
    );
  }

  return entries;
}

List<_ChangeLogEntry> _buildChangeLog(
  ProjectDataModel projectData,
  DesignManagementData managementData,
) {
  final items = <_ChangeLogEntry>[];
  var idCounter = 1;

  void addEntry({
    required String description,
    required String impact,
    required String status,
  }) {
    if (description.trim().isEmpty || items.length >= 5) {
      return;
    }
    final colors = _statusColors(status);
    items.add(
      _ChangeLogEntry(
        id: 'CC-${idCounter.toString().padLeft(2, '0')}',
        description: _limitText(description, max: 90),
        impact: _limitText(impact, max: 96),
        status: status,
        backgroundColor: colors.$1,
        foregroundColor: colors.$2,
      ),
    );
    idCounter += 1;
  }

  for (final scope in projectData.withinScopeItems.take(2)) {
    addEntry(
      description: 'Scope refinement: ${scope.description}',
      impact:
          'Updates baseline package, review narrative, and downstream coordination notes.',
      status: items.isEmpty ? 'Approved' : 'In Review',
    );
  }

  for (final constraint in projectData.constraintItems.take(2)) {
    addEntry(
      description: 'Constraint response: ${constraint.description}',
      impact:
          'May alter UI audit guardrails, venue clearances, or interface sequencing.',
      status: items.length.isEven ? 'Rejected' : 'Approved',
    );
  }

  for (final requirement
      in projectData.frontEndPlanning.requirementItems.take(1)) {
    addEntry(
      description: 'Requirement clarification: ${requirement.description}',
      impact:
          'Requires design-system updates and API or operations validation before final gate.',
      status: 'Approved',
    );
  }

  for (final risk in projectData.frontEndPlanning.riskRegisterItems.take(1)) {
    addEntry(
      description: 'Mitigation-driven variation: ${risk.riskName}',
      impact:
          'Introduces extra safety review, commissioning proof, or control-point evidence.',
      status: 'Rejected',
    );
  }

  final fallbacks = [
    (
      'UI audit response for check-in kiosk hierarchy and touch-target consistency',
      'Shifts component library sign-off and front-end QA retest coverage.',
      'Approved'
    ),
    (
      'Venue safety circulation revision around AV control room egress route',
      'Adds physical coordination review with brand and compliance stakeholders.',
      'Rejected'
    ),
    (
      'API schema update for visitor credential sync and badge-print timeout handling',
      'Requires interface review, regression testing, and revised RFI closeout.',
      'In Review'
    ),
  ];

  for (final fallback in fallbacks) {
    addEntry(
      description: fallback.$1,
      impact: fallback.$2,
      status: fallback.$3,
    );
  }

  return items;
}

List<_RfiEntry> _buildRfis(ProjectDataModel projectData) {
  final milestoneDates = projectData.keyMilestones
      .map((milestone) => _tryParseDate(milestone.dueDate))
      .whereType<DateTime>()
      .toList()
    ..sort();
  final items = <_RfiEntry>[];

  void addEntry(String question, String status) {
    if (question.trim().isEmpty || items.length >= 5) {
      return;
    }
    final dueDate = _formatDueDate(
      milestoneDates.length > items.length
          ? milestoneDates[items.length]
          : DateTime.now().add(Duration(days: 4 + (items.length * 3))),
    );
    final colors = _statusColors(status);
    items.add(
      _RfiEntry(
        question: _limitText(question, max: 106),
        dueDate: dueDate,
        status: status,
        backgroundColor: colors.$1,
        foregroundColor: colors.$2,
      ),
    );
  }

  for (final requirement
      in projectData.frontEndPlanning.requirementItems.take(2)) {
    addEntry(
      'Confirm requirement intent for "${requirement.description}" before detailed sign-off.',
      requirement.person.trim().isNotEmpty ? 'Answered' : 'Awaiting response',
    );
  }

  for (final entry in projectData.interfaceEntries.take(2)) {
    addEntry(
      'Who owns the final response for ${_fallbackText(entry.boundary, 'interface boundary')} and its ${_fallbackText(entry.risk, 'coordination risk')}?',
      entry.status.trim().toLowerCase().contains('resolved')
          ? 'Answered'
          : 'Open',
    );
  }

  for (final risk in projectData.frontEndPlanning.riskRegisterItems.take(1)) {
    addEntry(
      'What is the approved mitigation path for "${risk.riskName}" during the design freeze window?',
      'Awaiting response',
    );
  }

  if (items.length < 5) {
    addEntry(
      'Should the design system enforce the kiosk accessibility pattern before the 60% coordination review?',
      'Open',
    );
  }
  if (items.length < 5) {
    addEntry(
      'Who signs off the venue safety overlay after AV rack and wayfinding revisions are issued?',
      'Awaiting response',
    );
  }

  return items.take(5).toList();
}

List<_AuditEntry> _buildAudits({
  required ProjectDataModel projectData,
  required DesignManagementData managementData,
  required int architectureNodeCount,
}) {
  final requirementsReady =
      projectData.frontEndPlanning.requirementItems.isNotEmpty ||
          projectData.designManagementData?.specifications.isNotEmpty == true;
  final safetyReady = projectData.ssherData.entries.isNotEmpty ||
      projectData.ssherData.safetyItems.isNotEmpty;
  final apiReady = projectData.interfaceEntries.isNotEmpty ||
      projectData.aiIntegrations.isNotEmpty ||
      projectData.technologyDefinitions.isNotEmpty;
  final brandReady = managementData.documents.isNotEmpty ||
      projectData.designDeliverablesData.register.isNotEmpty;

  return [
    _AuditEntry(
      title: 'UI Audit',
      note: requirementsReady
          ? 'Component intent has upstream requirement coverage and design review inputs.'
          : 'No structured requirement evidence is tied back to the visual system yet.',
      pass: requirementsReady,
    ),
    _AuditEntry(
      title: 'Venue Safety',
      note: safetyReady
          ? 'Physical safety or SSHER evidence has been attached for design governance.'
          : managementData.industry == ProjectIndustry.construction
              ? 'Construction context exists, but no safety evidence is linked for the gate pack.'
              : 'No physical safety evidence has been attached to the current package.',
      pass: safetyReady,
    ),
    _AuditEntry(
      title: 'API Contract Review',
      note: apiReady
          ? 'Interface, technology, or AI integration inputs are present for system validation.'
          : 'Backend/API control points are still implied instead of documented.',
      pass: apiReady,
    ),
    _AuditEntry(
      title: 'Brand Review',
      note: brandReady
          ? 'Controlled outputs or deliverables are already present for release-note governance.'
          : 'No locked design artifact is currently supporting brand and messaging review.',
      pass: brandReady,
    ),
    _AuditEntry(
      title: 'Architecture Integrity',
      note: architectureNodeCount >= 3
          ? 'Architecture canvas contains $architectureNodeCount linked elements for review.'
          : 'Architecture workspace is still too light to support a robust integrity audit.',
      pass: architectureNodeCount >= 3,
    ),
  ];
}

List<_VersionEntry> _buildVersions({
  required ProjectDataModel projectData,
  required DesignManagementData managementData,
  required double readinessPercent,
  required int architectureNodeCount,
}) {
  final requirementCount = projectData.frontEndPlanning.requirementItems.length;
  final rfiCount = _buildRfis(projectData).length;

  return [
    _VersionEntry(
      version: 'v0.3 Concept Pack',
      notes:
          '${projectData.withinScopeItems.length} scope signals aligned with the project objective and early governance narrative.',
      locked: projectData.withinScopeItems.isNotEmpty ||
          projectData.projectObjective.trim().isNotEmpty,
    ),
    _VersionEntry(
      version: 'v0.6 Coordination Set',
      notes:
          '$architectureNodeCount architecture elements and ${projectData.interfaceEntries.length} interface touchpoints prepared for cross-discipline review.',
      locked:
          architectureNodeCount >= 3 || projectData.interfaceEntries.isNotEmpty,
    ),
    _VersionEntry(
      version: 'v0.9 Final Review',
      notes:
          '$requirementCount requirements and $rfiCount governance RFIs are informing the final quality gate.',
      locked: readinessPercent >= 75,
    ),
    _VersionEntry(
      version: 'v1.0 Controlled Issue',
      notes:
          '${managementData.documents.length} design docs and ${projectData.aiRecommendations.length} AI-supported notes are queued for release control.',
      locked: readinessPercent >= 92,
    ),
  ];
}

List<_CoordinationEntry> _buildCoordination({
  required ProjectDataModel projectData,
  required DesignManagementData managementData,
  required int architectureNodeCount,
}) {
  final hasUiInputs =
      projectData.frontEndPlanning.requirementItems.isNotEmpty ||
          managementData.specifications.isNotEmpty;
  final hasBackendInputs = projectData.interfaceEntries.isNotEmpty ||
      projectData.aiIntegrations.isNotEmpty ||
      projectData.technologyDefinitions.isNotEmpty;
  final hasSafetyInputs = projectData.ssherData.entries.isNotEmpty ||
      projectData.ssherData.safetyItems.isNotEmpty;

  return [
    _CoordinationEntry(
      discipline: 'Architecture',
      note: architectureNodeCount >= 3
          ? 'Diagram package is rich enough to coordinate interfaces and gate sequencing.'
          : 'Architecture canvas still needs more definition before clash review can be closed.',
      resolved: architectureNodeCount >= 3,
    ),
    _CoordinationEntry(
      discipline: 'UI/UX',
      note: hasUiInputs
          ? 'User-facing flows are tied to actual requirements and audit-ready design intent.'
          : 'Visual control decisions are not yet anchored to structured design requirements.',
      resolved: hasUiInputs,
    ),
    _CoordinationEntry(
      discipline: 'Backend / API',
      note: hasBackendInputs
          ? 'Integration boundaries or AI-led system signals exist for technical coordination.'
          : 'API and integration dependencies still need explicit coordination evidence.',
      resolved: hasBackendInputs,
    ),
    _CoordinationEntry(
      discipline: managementData.industry == ProjectIndustry.construction
          ? 'AV / Venue Safety'
          : 'Operations / Safety',
      note: hasSafetyInputs
          ? 'Physical and operational risks have traceable governance input.'
          : 'Pending response from safety or operations owners before the next gate.',
      resolved: hasSafetyInputs,
    ),
  ];
}

List<_DecisionEntry> _buildDecisions({
  required ProjectDataModel projectData,
  required DesignManagementData managementData,
  required double readinessPercent,
  required int architectureNodeCount,
}) {
  final decisions = <_DecisionEntry>[
    _DecisionEntry(
      title:
          'Methodology locked to ${_humanizeToken(managementData.methodology.name)}',
      rationale:
          'The design pack is being governed against a ${_humanizeToken(managementData.methodology.name).toLowerCase()} delivery cadence to keep review gates predictable and auditable.',
    ),
    _DecisionEntry(
      title:
          'Execution strategy set to ${_humanizeExecution(managementData.executionStrategy)}',
      rationale:
          'Current team coverage and package complexity indicate ${_humanizeExecution(managementData.executionStrategy).toLowerCase()} is the most controllable route for design delivery.',
    ),
    _DecisionEntry(
      title: '90% final gate must close before controlled issue',
      rationale:
          '${projectData.frontEndPlanning.riskRegisterItems.length} risk items and $architectureNodeCount architecture signals justify a firm pre-release hold point.',
    ),
  ];

  if (projectData.aiRecommendations.isNotEmpty ||
      projectData.aiIntegrations.isNotEmpty) {
    decisions.add(
      const _DecisionEntry(
        title: 'AI context remains advisory, not approving authority',
        rationale:
            'AI-supported notes are preserved to speed iteration, but governance decisions still require accountable human sign-off.',
      ),
    );
  } else if (readinessPercent < 80) {
    decisions.add(
      const _DecisionEntry(
        title: 'Version lock deferred until coordination evidence improves',
        rationale:
            'Readiness is below the preferred final-gate threshold, so the package stays open for controlled refinement.',
      ),
    );
  }

  return decisions;
}

List<String> _nextMilestoneNotes(List<Milestone> milestones) {
  final parsed = milestones
      .map((milestone) => (
            milestone,
            _tryParseDate(milestone.dueDate),
          ))
      .where((item) => item.$2 != null)
      .toList()
    ..sort((a, b) => a.$2!.compareTo(b.$2!));

  if (parsed.isEmpty) {
    return const [
      'Concept package baseline',
      'Discipline alignment checkpoint',
      'Final stakeholder sign-off',
      'Issued for control',
    ];
  }

  return parsed
      .take(4)
      .map(
        (item) =>
            '${_limitText(_fallbackText(item.$1.name, 'Milestone'), max: 18)} · ${_formatDueDate(item.$2!)}',
      )
      .toList();
}

int _countAssignedSignals(
  List<ProjectActivity> activities,
  String name,
  String role,
) {
  final nameToken = name.toLowerCase().split(' ').first;
  final roleToken = role.toLowerCase().split(RegExp(r'[\s/]+')).first;

  return activities.where((activity) {
    final assigned = (activity.assignedTo ?? '').toLowerCase();
    final activityRole = activity.role.toLowerCase();
    return (nameToken.isNotEmpty && assigned.contains(nameToken)) ||
        (roleToken.isNotEmpty && activityRole.contains(roleToken));
  }).length;
}

double _roleWeight(String role) {
  final normalized = role.toLowerCase();
  if (normalized.contains('project') || normalized.contains('lead')) {
    return 20;
  }
  if (normalized.contains('architect') || normalized.contains('design')) {
    return 24;
  }
  if (normalized.contains('ui') || normalized.contains('ux')) {
    return 19;
  }
  if (normalized.contains('backend') ||
      normalized.contains('api') ||
      normalized.contains('integration')) {
    return 17;
  }
  if (normalized.contains('safety') ||
      normalized.contains('av') ||
      normalized.contains('ops')) {
    return 15;
  }
  return 12;
}

(Color, Color) _statusColors(String status) {
  switch (status) {
    case 'Approved':
    case 'Answered':
    case 'Available':
    case 'Pass':
    case 'Resolved':
      return (AppSemanticColors.successSurface, AppSemanticColors.success);
    case 'Rejected':
    case 'Overloaded':
    case 'Fail':
      return (const Color(0xFFFEE2E2), const Color(0xFFDC2626));
    default:
      return (const Color(0xFFFFF7E6), const Color(0xFFD97706));
  }
}

String _humanizeToken(String token) {
  final spaced = token.replaceAllMapped(
    RegExp(r'(?<!^)([A-Z])'),
    (match) => ' ${match.group(1)}',
  );
  final normalized = spaced.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) {
    return '';
  }
  return normalized
      .split(RegExp(r'\s+'))
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String _humanizeExecution(ExecutionStrategy strategy) {
  switch (strategy) {
    case ExecutionStrategy.inHouse:
      return 'In-House';
    case ExecutionStrategy.contracted:
      return 'Contracted';
    case ExecutionStrategy.hybrid:
      return 'Hybrid';
  }
}

String _fallbackText(String value, String fallback) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

String _limitText(String value, {int max = 80}) {
  final trimmed = value.trim();
  if (trimmed.length <= max) {
    return trimmed;
  }
  return '${trimmed.substring(0, max - 1)}...';
}

DateTime? _tryParseDate(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final direct = DateTime.tryParse(trimmed);
  if (direct != null) {
    return direct;
  }

  final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2,4})$').firstMatch(trimmed);
  if (slash != null) {
    final month = int.tryParse(slash.group(1)!);
    final day = int.tryParse(slash.group(2)!);
    var year = int.tryParse(slash.group(3)!);
    if (month != null && day != null && year != null) {
      if (year < 100) {
        year += 2000;
      }
      return DateTime(year, month, day);
    }
  }

  final dash = RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{2,4})$').firstMatch(trimmed);
  if (dash != null) {
    final month = int.tryParse(dash.group(1)!);
    final day = int.tryParse(dash.group(2)!);
    var year = int.tryParse(dash.group(3)!);
    if (month != null && day != null && year != null) {
      if (year < 100) {
        year += 2000;
      }
      return DateTime(year, month, day);
    }
  }

  return null;
}

String _formatDueDate(DateTime date) {
  return DateFormat('dd MMM').format(date);
}
