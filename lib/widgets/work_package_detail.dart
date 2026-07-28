import 'package:flutter/material.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/integrated_work_package_service.dart';
import 'package:ndu_project/theme.dart';

class WorkPackageDetailView extends StatelessWidget {
  const WorkPackageDetailView({
    super.key,
    required this.workPackage,
    required this.activities,
    this.onEdit,
    this.onReleaseForExecution,
  });

  final WorkPackage workPackage;
  final List<ScheduleActivity> activities;
  final VoidCallback? onEdit;

  /// Called when user wants to release this EWP for execution.
  final VoidCallback? onReleaseForExecution;

  @override
  Widget build(BuildContext context) {
    final progress = workPackage.budgetedCost > 0
        ? (workPackage.actualCost / workPackage.budgetedCost).clamp(0.0, 1.0)
        : 0.0;
    final readinessWarnings =
        IntegratedWorkPackageService.validateReadiness(workPackage);

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
          minWidth: 720,
        ),
        child: SizedBox(
          width: 780,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header — always visible
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        workPackage.title.isNotEmpty
                            ? workPackage.title
                            : 'Untitled Work Package',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    if (onEdit != null)
                      OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${(progress * 100).toStringAsFixed(1)}% of budget used',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 16),
                _WarningPanel(warnings: readinessWarnings),
                const SizedBox(height: 16),
                _AccordionSection(
                  title: 'Package Details',
                  icon: Icons.info_outline,
                  initiallyExpanded: true,
                  child: _DetailGrid(
                    items: [
                      _DetailItem(
                        label: 'Classification',
                        value: workPackage.packageClassification.isNotEmpty
                            ? _classificationLabel(
                                workPackage.packageClassification,
                              )
                            : 'Unclassified',
                      ),
                      _DetailItem(
                        label: 'Package Code',
                        value: workPackage.packageCode.isNotEmpty
                            ? workPackage.packageCode
                            : 'Not set',
                      ),
                      _DetailItem(
                        label: 'Package Level',
                        value: workPackage.packageLevel > 0
                            ? 'Level ${workPackage.packageLevel}'
                            : 'Not set',
                      ),
                      _DetailItem(
                        label: 'Release Status',
                        value: workPackage.releaseStatus == 'released'
                            ? 'Released${workPackage.releaseForExecutionDate != null ? " on ${workPackage.releaseForExecutionDate}" : ""}'
                            : _titleCase(workPackage.releaseStatus),
                      ),
                      _DetailItem(
                        label: 'Discipline',
                        value: workPackage.discipline.isNotEmpty
                            ? workPackage.discipline
                            : 'N/A',
                      ),
                      _DetailItem(
                        label: 'WBS Level 2',
                        value: workPackage.wbsLevel2Title.isNotEmpty
                            ? workPackage.wbsLevel2Title
                            : 'Unassigned',
                      ),
                      _DetailItem(
                        label: 'WBS Source Node',
                        value: workPackage.sourceWbsLevel3Title.isNotEmpty
                            ? workPackage.sourceWbsLevel3Title
                            : 'Unassigned',
                      ),
                      _DetailItem(
                        label: 'Area / System',
                        value: workPackage.areaOrSystem.isNotEmpty
                            ? workPackage.areaOrSystem
                            : 'Not set',
                      ),
                      _DetailItem(
                        label: 'Contractor / Crew',
                        value: workPackage.contractorOrCrew.isNotEmpty
                            ? workPackage.contractorOrCrew
                            : 'Not set',
                      ),
                      _DetailItem(
                        label: 'Contract IDs',
                        value: workPackage.contractIds.isNotEmpty
                            ? workPackage.contractIds.join(', ')
                            : 'Not set',
                      ),
                      _DetailItem(
                        label: 'Vendor IDs',
                        value: workPackage.vendorIds.isNotEmpty
                            ? workPackage.vendorIds.join(', ')
                            : 'Not set',
                      ),
                      _DetailItem(
                        label: 'Planned Start',
                        value: workPackage.plannedStart != null &&
                                workPackage.plannedStart!.isNotEmpty
                            ? workPackage.plannedStart!
                            : 'Not set',
                      ),
                      _DetailItem(
                        label: 'Planned End',
                        value: workPackage.plannedEnd != null &&
                                workPackage.plannedEnd!.isNotEmpty
                            ? workPackage.plannedEnd!
                            : 'Not set',
                      ),
                      _DetailItem(
                        label: 'Budgeted Cost',
                        value:
                            '\$${workPackage.budgetedCost.toStringAsFixed(2)}',
                      ),
                      _DetailItem(
                        label: 'Actual Cost',
                        value: '\$${workPackage.actualCost.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _AccordionSection(
                  title: 'Readiness',
                  icon: Icons.verified_outlined,
                  initiallyExpanded: false,
                  child: _ReadinessSummary(readiness: workPackage.readiness),
                ),
                const SizedBox(height: 16),
                _AccordionSection(
                  title: 'Estimate Basis',
                  icon: Icons.calculate_outlined,
                  initiallyExpanded: false,
                  child:
                      _EstimateBasisSummary(basis: workPackage.estimateBasis),
                ),
                if (workPackage.packageClassification ==
                        IntegratedWorkPackageService.procurementPackage ||
                    workPackage.procurementBreakdown.category.isNotEmpty ||
                    workPackage
                        .procurementBreakdown.scopeDefinition.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _AccordionSection(
                    title: 'Procurement Breakdown',
                    icon: Icons.local_shipping_outlined,
                    initiallyExpanded: false,
                    child: _ProcurementSummary(
                      procurement: workPackage.procurementBreakdown,
                    ),
                  ),
                ],
                if (workPackage.packageClassification ==
                    IntegratedWorkPackageService.engineeringEwp) ...[
                  const SizedBox(height: 16),
                  _AccordionSection(
                    title: 'EWP Release Gate',
                    icon: Icons.lock_outline,
                    initiallyExpanded: false,
                    child: _EwpReleaseGate(
                      workPackage: workPackage,
                      onRelease: onReleaseForExecution,
                    ),
                  ),
                ],
                if (workPackage.deliverables.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _AccordionSection(
                    title: 'Package Deliverables',
                    icon: Icons.inventory_2_outlined,
                    initiallyExpanded: false,
                    child: Column(
                      children: workPackage.deliverables
                          .map((item) => _DeliverableRow(deliverable: item))
                          .toList(),
                    ),
                  ),
                ],
                if (workPackage.linkedDesignSpecificationIds.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _AccordionSection(
                    title: 'Linked Design Specifications',
                    icon: Icons.link_outlined,
                    initiallyExpanded: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${workPackage.linkedDesignSpecificationIds.length} specification(s) linked to this package.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...workPackage.linkedDesignSpecificationIds.map(
                          (id) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.link,
                                  size: 12,
                                  color: Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  id,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: appFontFamily,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (workPackage.acceptingCriteria.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _AccordionSection(
                    title: 'Accepting Criteria',
                    icon: Icons.fact_check_outlined,
                    initiallyExpanded: false,
                    child: Text(
                      workPackage.acceptingCriteria,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                ],
                if (activities.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _AccordionSection(
                    title: 'Linked Activities (${activities.length})',
                    icon: Icons.timeline_outlined,
                    initiallyExpanded: true,
                    child: Column(
                      children: activities
                          .map(
                            (a) => Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppSemanticColors.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: _statusDotColor(a.status),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      a.title.isNotEmpty
                                          ? a.title
                                          : 'Untitled Activity',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${(a.progress * 100).round()}%',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
                if (workPackage.notes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _AccordionSection(
                    title: 'Notes',
                    icon: Icons.sticky_note_2_outlined,
                    initiallyExpanded: false,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppSemanticColors.border),
                      ),
                      child: Text(
                        workPackage.notes,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _titleCase(String value) {
    final words = value.split('_');
    return words.map((word) {
      if (word.isEmpty) return word;
      return '${word[0].toUpperCase()}${word.substring(1)}';
    }).join(' ');
  }

  String _classificationLabel(String value) {
    switch (value) {
      case IntegratedWorkPackageService.engineeringEwp:
        return 'Engineering Work Package';
      case IntegratedWorkPackageService.procurementPackage:
        return 'Procurement Package';
      case IntegratedWorkPackageService.deliveryPackage:
        return 'Deliverable Work Package';
      case IntegratedWorkPackageService.constructionCwp:
        return 'Construction Work Package';
      case IntegratedWorkPackageService.implementationWorkPackage:
        return 'Implementation Work Package';
      case IntegratedWorkPackageService.agileIterationPackage:
        return 'Agile Iteration Package';
      case IntegratedWorkPackageService.preCommissioningPackage:
        return 'Pre-Commissioning Package';
      case IntegratedWorkPackageService.commissioningPackage:
        return 'Commissioning Package';
      default:
        return _titleCase(value);
    }
  }

  Color _statusDotColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'complete':
        return const Color(0xFF10B981);
      case 'in_progress':
        return const Color(0xFFFBBF24);
      case 'overdue':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  Color _statusChipColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'complete':
        return const Color(0xFF10B981);
      case 'in_progress':
        return const Color(0xFFFBBF24);
      case 'blocked':
      case 'on_hold':
        return const Color(0xFFEF4444);
      case 'overdue':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }
}

/// Quick stat chip for the header row.
class _QuickStatChip extends StatelessWidget {
  const _QuickStatChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Collapsible accordion section (P9).
class _AccordionSection extends StatelessWidget {
  const _AccordionSection({
    required this.title,
    required this.icon,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppSemanticColors.border),
      ),
      child: Theme(
        // Remove default ExpansionTile divider lines
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          leading: Icon(icon, size: 18, color: const Color(0xFF4B5563)),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          children: [child],
        ),
      ),
    );
  }
}

class _WarningPanel extends StatelessWidget {
  const _WarningPanel({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF10B981)),
        ),
        child: const Text(
          'No readiness warnings.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF047857),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF97316)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${warnings.length} readiness warning${warnings.length == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF9A3412),
            ),
          ),
          const SizedBox(height: 6),
          ...warnings.map(
            (warning) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '- $warning',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7C2D12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageSection extends StatelessWidget {
  const _PackageSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppSemanticColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ReadinessSummary extends StatelessWidget {
  const _ReadinessSummary({required this.readiness});

  final PackageReadinessChecklist readiness;

  @override
  Widget build(BuildContext context) {
    final rows = {
      'Requirements traced': readiness.requirementsTraced,
      'Drawings complete': readiness.drawingsComplete,
      'Specifications complete': readiness.specificationsComplete,
      'BOM complete': readiness.billOfMaterialsComplete,
      'Design review complete': readiness.designReviewComplete,
      'IFC/design approved': readiness.ifcApproved,
      'Procurement scope defined': readiness.procurementScopeDefined,
      'RFQ/RFP issued': readiness.rfqIssued,
      'Bids evaluated': readiness.bidsEvaluated,
      'Contract awarded': readiness.contractAwarded,
      'Materials available': readiness.materialsAvailable,
      'Permits approved': readiness.permitsApproved,
      'Access ready': readiness.accessReady,
      'Predecessors complete': readiness.predecessorsComplete,
      'Resources assigned': readiness.resourcesAssigned,
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: rows.entries.map((entry) {
        final complete = entry.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: complete ? const Color(0xFFECFDF5) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  complete ? const Color(0xFF10B981) : const Color(0xFFD1D5DB),
            ),
          ),
          child: Text(
            '${complete ? 'OK' : 'OPEN'} ${entry.key}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color:
                  complete ? const Color(0xFF047857) : const Color(0xFF4B5563),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _EstimateBasisSummary extends StatelessWidget {
  const _EstimateBasisSummary({required this.basis});

  final PackageEstimateBasis basis;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InlineRow(label: 'Method', value: _fallback(basis.method)),
        _InlineRow(label: 'Source data', value: _fallback(basis.sourceData)),
        _InlineRow(
          label: 'Confidence',
          value: _fallback(basis.confidenceLevel),
        ),
        _InlineRow(
          label: 'Productivity',
          value: _fallback(basis.productivityBasis),
        ),
        _InlineRow(
          label: 'Resources',
          value: _fallback(basis.resourceBasis),
        ),
        _InlineRow(
          label: 'Working calendar',
          value: _fallback(basis.workingCalendar),
        ),
        _InlineRow(
          label: 'Lead time basis',
          value: _fallback(basis.procurementLeadTimeBasis),
        ),
        _InlineRow(
          label: 'Review allowance',
          value: _fallback(basis.reviewAllowance),
        ),
        _InlineRow(
          label: 'Assumptions',
          value: basis.assumptions.isEmpty
              ? 'Not documented'
              : basis.assumptions.join('; '),
        ),
        _InlineRow(
          label: 'Exclusions',
          value:
              basis.exclusions.isEmpty ? 'None' : basis.exclusions.join('; '),
        ),
      ],
    );
  }
}

class _ProcurementSummary extends StatelessWidget {
  const _ProcurementSummary({required this.procurement});

  final PackageProcurementBreakdown procurement;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InlineRow(label: 'Category', value: _fallback(procurement.category)),
        _InlineRow(
          label: 'Lead time',
          value: procurement.leadTimeDays > 0
              ? '${procurement.leadTimeDays} days'
              : 'Not set',
        ),
        _InlineRow(
          label: 'Scope',
          value: _fallback(procurement.scopeDefinition),
        ),
        _InlineRow(
          label: 'Activities',
          value: procurement.activities.isEmpty
              ? 'Not set'
              : procurement.activities.join(', '),
        ),
      ],
    );
  }
}

class _InlineRow extends StatelessWidget {
  const _InlineRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _fallback(String value) => value.trim().isEmpty ? 'Not set' : value;

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.items});

  final List<_DetailItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: items
          .map((item) => SizedBox(
                width: (MediaQuery.sizeOf(context).width - 120) / 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.value,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _DetailItem {
  final String label;
  final String value;

  _DetailItem({required this.label, required this.value});
}

/// Fix 1.4: EWP Release Gate widget.
/// Shows the release status of an EWP and provides a button to
/// release it for execution if all gate criteria are met.
class _EwpReleaseGate extends StatelessWidget {
  const _EwpReleaseGate({
    required this.workPackage,
    this.onRelease,
  });

  final WorkPackage workPackage;
  final VoidCallback? onRelease;

  @override
  Widget build(BuildContext context) {
    final isReleased = workPackage.isReleasedForExecution;
    final blockers =
        IntegratedWorkPackageService.checkEwpReleaseReadiness(workPackage);
    final canRelease = blockers.isEmpty && !isReleased;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isReleased
            ? const Color(0xFFECFDF5)
            : (blockers.isEmpty
                ? const Color(0xFFFFF7E6)
                : const Color(0xFFFFF7ED)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isReleased
              ? const Color(0xFF10B981)
              : (blockers.isEmpty
                  ? const Color(0xFFFBBF24)
                  : const Color(0xFFF97316)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isReleased
                    ? Icons.check_circle
                    : (blockers.isEmpty ? Icons.lock_open : Icons.lock),
                size: 18,
                color: isReleased
                    ? const Color(0xFF047857)
                    : (blockers.isEmpty
                        ? const Color(0xFFD97706)
                        : const Color(0xFF9A3412)),
              ),
              const SizedBox(width: 8),
              Text(
                isReleased
                    ? 'Released for Execution'
                    : (blockers.isEmpty
                        ? 'Ready to Release'
                        : '${blockers.length} Blocker(s) Before Release'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isReleased
                      ? const Color(0xFF047857)
                      : (blockers.isEmpty
                          ? const Color(0xFFD97706)
                          : const Color(0xFF9A3412)),
                ),
              ),
            ],
          ),
          if (workPackage.releaseForExecutionDate != null) ...[
            const SizedBox(height: 4),
            Text(
              'Released on: ${workPackage.releaseForExecutionDate}',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
          if (blockers.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...blockers.take(4).map(
                  (blocker) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '- $blocker',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF7C2D12),
                      ),
                    ),
                  ),
                ),
            if (blockers.length > 4)
              Text(
                '... and ${blockers.length - 4} more',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF7C2D12),
                ),
              ),
          ],
          if (canRelease && onRelease != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onRelease,
                icon: const Icon(Icons.lock_open, size: 16),
                label: const Text('Release for Execution'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Enhanced deliverable row showing traceability information
/// (Fix 1.3: feedsProcurementPackageIds, Fix 1.2: linkedSpecificationIds).
class _DeliverableRow extends StatelessWidget {
  const _DeliverableRow({required this.deliverable});

  final PackageDeliverable deliverable;

  @override
  Widget build(BuildContext context) {
    final isReleased = deliverable.isReleased;
    final hasSpecLink = deliverable.linkedSpecificationIds.isNotEmpty;
    final hasProcurementLink =
        deliverable.feedsProcurementPackageIds.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isReleased ? const Color(0xFFECFDF5) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color:
              isReleased ? const Color(0xFF10B981) : AppSemanticColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isReleased ? Icons.check_circle : Icons.circle_outlined,
                size: 14,
                color: isReleased
                    ? const Color(0xFF10B981)
                    : const Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  deliverable.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isReleased
                        ? const Color(0xFF047857)
                        : const Color(0xFF111827),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _statusColor(deliverable.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  deliverable.status,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _statusColor(deliverable.status),
                  ),
                ),
              ),
            ],
          ),
          if (deliverable.type.isNotEmpty ||
              hasProcurementLink ||
              hasSpecLink ||
              deliverable.requiredForProcurement) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (deliverable.type.isNotEmpty)
                  _traceChip(
                    icon: Icons.category,
                    label: deliverable.type,
                    color: const Color(0xFF6B7280),
                  ),
                if (deliverable.requiredForProcurement)
                  const _traceChip(
                    icon: Icons.local_shipping,
                    label: 'Required for Procurement',
                    color: Color(0xFFD97706),
                  ),
                if (hasProcurementLink)
                  _traceChip(
                    icon: Icons.arrow_forward,
                    label:
                        'Feeds ${deliverable.feedsProcurementPackageIds.length} procurement pkg(s)',
                    color: const Color(0xFFD97706),
                  ),
                if (hasSpecLink)
                  _traceChip(
                    icon: Icons.link,
                    label:
                        '${deliverable.linkedSpecificationIds.length} spec(s)',
                    color: const Color(0xFF7C3AED),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'released':
      case 'complete':
      case 'completed':
        return const Color(0xFF10B981);
      case 'in_review':
        return const Color(0xFFFBBF24);
      case 'planned':
        return const Color(0xFF9CA3AF);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

class _traceChip extends StatelessWidget {
  const _traceChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
