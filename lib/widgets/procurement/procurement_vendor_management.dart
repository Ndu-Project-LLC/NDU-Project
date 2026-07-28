import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/services/vendor_service.dart';
import 'package:ndu_project/widgets/procurement/procurement_common_widgets.dart';
import 'package:ndu_project/widgets/responsive.dart';

class VendorHealthMetric {
  const VendorHealthMetric({
    required this.category,
    required this.score,
    required this.change,
  });

  final String category;
  final double score;
  final String change;
}

enum VendorTaskStatus { pending, inReview, complete }

extension VendorTaskStatusX on VendorTaskStatus {
  String get label {
    switch (this) {
      case VendorTaskStatus.pending:
        return 'Pending';
      case VendorTaskStatus.inReview:
        return 'In Review';
      case VendorTaskStatus.complete:
        return 'Complete';
    }
  }

  Color get backgroundColor {
    switch (this) {
      case VendorTaskStatus.pending:
        return const Color(0xFFF1F5F9);
      case VendorTaskStatus.inReview:
        return const Color(0xFFFFF7ED);
      case VendorTaskStatus.complete:
        return const Color(0xFFE8FFF4);
    }
  }

  Color get textColor {
    switch (this) {
      case VendorTaskStatus.pending:
        return const Color(0xFF64748B);
      case VendorTaskStatus.inReview:
        return const Color(0xFFF97316);
      case VendorTaskStatus.complete:
        return const Color(0xFF047857);
    }
  }

  Color get borderColor {
    switch (this) {
      case VendorTaskStatus.pending:
        return const Color(0xFFE2E8F0);
      case VendorTaskStatus.inReview:
        return const Color(0xFFFED7AA);
      case VendorTaskStatus.complete:
        return const Color(0xFFBBF7D0);
    }
  }
}

class VendorOnboardingTask {
  const VendorOnboardingTask({
    required this.title,
    required this.owner,
    required this.dueDate,
    required this.status,
  });

  final String title;
  final String owner;
  final String dueDate;
  final VendorTaskStatus status;
}

enum RiskSeverity { low, medium, high }

extension RiskSeverityX on RiskSeverity {
  String get label {
    switch (this) {
      case RiskSeverity.low:
        return 'Low';
      case RiskSeverity.medium:
        return 'Medium';
      case RiskSeverity.high:
        return 'High';
    }
  }

  Color get backgroundColor {
    switch (this) {
      case RiskSeverity.low:
        return const Color(0xFFF1F5F9);
      case RiskSeverity.medium:
        return const Color(0xFFFFF7ED);
      case RiskSeverity.high:
        return const Color(0xFFFFF1F2);
    }
  }

  Color get textColor {
    switch (this) {
      case RiskSeverity.low:
        return const Color(0xFF64748B);
      case RiskSeverity.medium:
        return const Color(0xFFF97316);
      case RiskSeverity.high:
        return const Color(0xFFDC2626);
    }
  }

  Color get borderColor {
    switch (this) {
      case RiskSeverity.low:
        return const Color(0xFFE2E8F0);
      case RiskSeverity.medium:
        return const Color(0xFFFED7AA);
      case RiskSeverity.high:
        return const Color(0xFFFECACA);
    }
  }
}

class VendorRiskItem {
  const VendorRiskItem({
    required this.vendor,
    required this.risk,
    required this.severity,
    required this.lastIncident,
  });

  final String vendor;
  final String risk;
  final RiskSeverity severity;
  final String lastIncident;
}

extension VendorModelUi on VendorModel {
  bool get isApproved {
    final value = status.toLowerCase();
    return value == 'active' || value == 'approved';
  }

  bool get isPreferred {
    final value = criticality.toLowerCase();
    return value == 'high' || status.toLowerCase() == 'preferred';
  }

  String get contactLabel {
    final email = createdByEmail.trim();
    if (email.isNotEmpty) return email;
    final name = createdByName.trim();
    if (name.isNotEmpty) return name;
    return '-';
  }

  int get ratingScore {
    final raw = rating.trim().toUpperCase();
    final parsed = int.tryParse(raw);
    if (parsed != null) return parsed.clamp(1, 5);
    switch (raw) {
      case 'A':
        return 5;
      case 'B':
        return 4;
      case 'C':
        return 3;
      case 'D':
        return 2;
      case 'E':
        return 1;
      default:
        return 3;
    }
  }
}

class VendorManagementView extends StatelessWidget {
  const VendorManagementView({
    super.key,
    required this.vendors,
    required this.allVendors,
    required this.selectedVendorIds,
    required this.approvedOnly,
    required this.preferredOnly,
    required this.listView,
    required this.categoryFilter,
    required this.categoryOptions,
    required this.healthMetrics,
    required this.onboardingTasks,
    required this.riskItems,
    required this.onAddVendor,
    required this.onInviteVendor,
    required this.onApprovedChanged,
    required this.onPreferredChanged,
    required this.onCategoryChanged,
    required this.onViewModeChanged,
    required this.onToggleVendorSelected,
    required this.onEditVendor,
    required this.onDeleteVendor,
    required this.onOpenApprovedVendorList,
  });

  final List<VendorModel> vendors;
  final List<VendorModel> allVendors;
  final Set<String> selectedVendorIds;
  final bool approvedOnly;
  final bool preferredOnly;
  final bool listView;
  final String categoryFilter;
  final List<String> categoryOptions;
  final List<VendorHealthMetric> healthMetrics;
  final List<VendorOnboardingTask> onboardingTasks;
  final List<VendorRiskItem> riskItems;
  final VoidCallback onAddVendor;
  final VoidCallback onInviteVendor;
  final ValueChanged<bool> onApprovedChanged;
  final ValueChanged<bool> onPreferredChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<bool> onViewModeChanged;
  final void Function(String vendorId, bool selected) onToggleVendorSelected;
  final ValueChanged<VendorModel> onEditVendor;
  final ValueChanged<String> onDeleteVendor;
  final VoidCallback onOpenApprovedVendorList;

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    final totalVendors = allVendors.length;
    final preferredCount =
        allVendors.where((vendor) => vendor.isPreferred).length;
    final avgRating = totalVendors == 0
        ? 0
        : allVendors.fold<int>(
                0, (total, vendor) => total + vendor.ratingScore) /
            totalVendors;
    final preferredRate =
        totalVendors == 0 ? 0 : (preferredCount / totalVendors * 100).round();

    final metricCards = [
      ProcurementSummaryCard(
        icon: Icons.inventory_2_outlined,
        iconBackground: const Color(0xFFEFF6FF),
        value: '$totalVendors',
        label: 'Active Vendors',
      ),
      ProcurementSummaryCard(
        icon: Icons.star_outline,
        iconBackground: const Color(0xFFFFF7ED),
        value: '$preferredRate%',
        label: 'Preferred Coverage',
        valueColor: const Color(0xFFF97316),
      ),
      ProcurementSummaryCard(
        icon: Icons.thumb_up_alt_outlined,
        iconBackground: const Color(0xFFF1F5F9),
        value: avgRating.toStringAsFixed(1),
        label: 'Avg Rating',
      ),
      ProcurementSummaryCard(
        icon: Icons.shield_outlined,
        iconBackground: const Color(0xFFFFF1F2),
        value: '${riskItems.length}',
        label: 'Compliance Actions',
        valueColor: const Color(0xFFDC2626),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Vendor Management',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A)),
              ),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onInviteVendor,
                  icon: const Icon(Icons.send_outlined, size: 18),
                  label: const Text('Invite Vendor'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onAddVendor,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Vendor'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (isMobile)
          Column(
            children: [
              metricCards[0],
              const SizedBox(height: 12),
              metricCards[1],
              const SizedBox(height: 12),
              metricCards[2],
              const SizedBox(height: 12),
              metricCards[3],
            ],
          )
        else
          Row(
            children: [
              for (var i = 0; i < metricCards.length; i++) ...[
                Expanded(child: metricCards[i]),
                if (i != metricCards.length - 1) const SizedBox(width: 16),
              ],
            ],
          ),
        const SizedBox(height: 24),
        if (isMobile)
          Column(
            children: [
              _VendorHealthCard(metrics: healthMetrics),
              const SizedBox(height: 16),
              _VendorOnboardingCard(tasks: onboardingTasks),
              const SizedBox(height: 16),
              _VendorRiskCard(riskItems: riskItems),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _VendorHealthCard(metrics: healthMetrics)),
              const SizedBox(width: 16),
              Expanded(child: _VendorOnboardingCard(tasks: onboardingTasks)),
              const SizedBox(width: 16),
              Expanded(child: _VendorRiskCard(riskItems: riskItems)),
            ],
          ),
        const SizedBox(height: 24),
        _VendorsSection(
          vendors: vendors,
          allVendorsCount: allVendors.length,
          selectedVendorIds: selectedVendorIds,
          approvedOnly: approvedOnly,
          preferredOnly: preferredOnly,
          listView: listView,
          categoryFilter: categoryFilter,
          categoryOptions: categoryOptions,
          onAddVendor: onAddVendor,
          onApprovedChanged: onApprovedChanged,
          onPreferredChanged: onPreferredChanged,
          onCategoryChanged: onCategoryChanged,
          onViewModeChanged: onViewModeChanged,
          onToggleVendorSelected: onToggleVendorSelected,
          onEditVendor: onEditVendor,
          onDeleteVendor: onDeleteVendor,
          onOpenApprovedVendorList: onOpenApprovedVendorList,
        ),
        const SizedBox(height: 24),
        _ApprovedVendorsSection(
          approvedVendors:
              allVendors.where((vendor) => vendor.isApproved).toList(),
        ),
      ],
    );
  }
}

class _VendorHealthCard extends StatelessWidget {
  const _VendorHealthCard({required this.metrics});

  final List<VendorHealthMetric> metrics;

  Color _scoreColor(double score) {
    if (score >= 0.85) return const Color(0xFF10B981);
    if (score >= 0.7) return const Color(0xFF2563EB);
    return const Color(0xFFF97316);
  }

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return const ProcurementEmptyStateCard(
        icon: Icons.health_and_safety_outlined,
        title: 'Vendor health by category',
        message:
            'Health metrics will appear once vendor performance is tracked.',
        compact: true,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vendor health by category',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < metrics.length; i++) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    metrics[i].category,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937)),
                  ),
                ),
                Text(
                  '${(metrics[i].score * 100).round()}%',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: metrics[i].score,
                minHeight: 8,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                    _scoreColor(metrics[i].score)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              metrics[i].change,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            if (i != metrics.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _VendorOnboardingCard extends StatelessWidget {
  const _VendorOnboardingCard({required this.tasks});

  final List<VendorOnboardingTask> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const ProcurementEmptyStateCard(
        icon: Icons.assignment_turned_in_outlined,
        title: 'Onboarding pipeline',
        message: 'No onboarding tasks yet. Add vendors to start the pipeline.',
        compact: true,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Onboarding pipeline',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < tasks.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tasks[i].title,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Owner: ${tasks[i].owner} \u00b7 Due ${DateFormat('M/d').format(DateTime.parse(tasks[i].dueDate))}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _VendorTaskStatusPill(status: tasks[i].status),
              ],
            ),
            if (i != tasks.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _VendorRiskCard extends StatelessWidget {
  const _VendorRiskCard({required this.riskItems});

  final List<VendorRiskItem> riskItems;

  @override
  Widget build(BuildContext context) {
    if (riskItems.isEmpty) {
      return const ProcurementEmptyStateCard(
        icon: Icons.shield_outlined,
        title: 'Risk watchlist',
        message: 'Risk items will appear once vendors are assessed.',
        compact: true,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Risk watchlist',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < riskItems.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        riskItems[i].vendor,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        riskItems[i].risk,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last incident: ${DateFormat('M/d').format(DateTime.parse(riskItems[i].lastIncident))}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _RiskSeverityPill(severity: riskItems[i].severity),
              ],
            ),
            if (i != riskItems.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _VendorTaskStatusPill extends StatelessWidget {
  const _VendorTaskStatusPill({required this.status});

  final VendorTaskStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.borderColor),
      ),
      child: Text(
        status.label,
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: status.textColor),
      ),
    );
  }
}

class _RiskSeverityPill extends StatelessWidget {
  const _RiskSeverityPill({required this.severity});

  final RiskSeverity severity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: severity.backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: severity.borderColor),
      ),
      child: Text(
        severity.label,
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: severity.textColor),
      ),
    );
  }
}

class _VendorsSection extends StatelessWidget {
  const _VendorsSection({
    required this.vendors,
    required this.allVendorsCount,
    required this.selectedVendorIds,
    required this.approvedOnly,
    required this.preferredOnly,
    required this.listView,
    required this.categoryFilter,
    required this.categoryOptions,
    required this.onApprovedChanged,
    required this.onPreferredChanged,
    required this.onCategoryChanged,
    required this.onViewModeChanged,
    required this.onToggleVendorSelected,
    required this.onEditVendor,
    required this.onDeleteVendor,
    required this.onOpenApprovedVendorList,
    this.onAddVendor,
  });

  final List<VendorModel> vendors;
  final int allVendorsCount;
  final Set<String> selectedVendorIds;
  final bool approvedOnly;
  final bool preferredOnly;
  final bool listView;
  final String categoryFilter;
  final List<String> categoryOptions;
  final ValueChanged<bool> onApprovedChanged;
  final ValueChanged<bool> onPreferredChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<bool> onViewModeChanged;
  final void Function(String vendorId, bool selected) onToggleVendorSelected;
  final ValueChanged<VendorModel> onEditVendor;
  final ValueChanged<String> onDeleteVendor;
  final VoidCallback onOpenApprovedVendorList;
  final VoidCallback? onAddVendor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Vendors',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A)),
            ),
            Text(
              '${vendors.length} of $allVendorsCount vendors',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Use the Approved, Preferred, and Category filters to refine vendors.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.filter_alt_outlined, size: 18),
              label: const Text('Filters'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            FilterChip(
              label: const Text('Approved Only'),
              selected: approvedOnly,
              onSelected: onApprovedChanged,
              selectedColor: const Color(0xFFEFF6FF),
              showCheckmark: false,
              labelStyle: TextStyle(
                color: approvedOnly
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF475569),
                fontWeight: FontWeight.w600,
              ),
            ),
            FilterChip(
              label: const Text('Preferred Only'),
              selected: preferredOnly,
              onSelected: onPreferredChanged,
              selectedColor: const Color(0xFFF1F5F9),
              showCheckmark: false,
              labelStyle: TextStyle(
                color: preferredOnly
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF475569),
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: categoryFilter,
                  items: categoryOptions
                      .map((option) => DropdownMenuItem<String>(
                            value: option,
                            child: Text(option),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onCategoryChanged(value);
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            ToggleButtons(
              borderRadius: BorderRadius.circular(12),
              constraints: const BoxConstraints(minHeight: 40, minWidth: 48),
              isSelected: [listView, !listView],
              onPressed: (index) => onViewModeChanged(index == 0),
              children: const [
                Icon(Icons.view_list_rounded, size: 20),
                Icon(Icons.grid_view_rounded, size: 20),
              ],
            ),
            OutlinedButton.icon(
              onPressed: onOpenApprovedVendorList,
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('View Company Approved Vendor List'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (vendors.isEmpty)
          ProcurementEmptyStateCard(
            icon: Icons.storefront_outlined,
            title: allVendorsCount == 0 ? 'No vendors yet' : 'No vendors match',
            message: allVendorsCount == 0
                ? 'Add your first vendor to track approvals, ratings, and performance.'
                : 'Adjust filters or add new vendors to expand coverage.',
            actionLabel: allVendorsCount == 0 ? 'Add Vendor' : null,
            onAction: onAddVendor,
          )
        else if (listView)
          _VendorDataTable(
            vendors: vendors,
            selectedVendorIds: selectedVendorIds,
            onToggleSelected: onToggleVendorSelected,
            onEditVendor: onEditVendor,
            onDeleteVendor: onDeleteVendor,
          )
        else
          _VendorGrid(
            vendors: vendors,
            selectedVendorIds: selectedVendorIds,
            onToggleSelected: onToggleVendorSelected,
            onEditVendor: onEditVendor,
            onDeleteVendor: onDeleteVendor,
          ),
      ],
    );
  }
}

class _ApprovedVendorsSection extends StatelessWidget {
  const _ApprovedVendorsSection({required this.approvedVendors});

  final List<VendorModel> approvedVendors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Approved Vendors',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A)),
              ),
            ),
            Text(
              '${approvedVendors.length}',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (approvedVendors.isEmpty)
          const ProcurementEmptyStateCard(
            icon: Icons.verified_user_outlined,
            title: 'No approved vendors yet',
            message:
                'Approved vendors appear here once vendor status is set to Active or Approved.',
            compact: true,
          )
        else
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                for (var i = 0; i < approvedVendors.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            approvedVendors[i].name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            approvedVendors[i].category,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: _RatingStars(
                            rating: approvedVendors[i].ratingScore,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            approvedVendors[i].nextReview.trim().isEmpty
                                ? 'Review date N/A'
                                : approvedVendors[i].nextReview,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i != approvedVendors.length - 1)
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _VendorDataTable extends StatelessWidget {
  const _VendorDataTable({
    required this.vendors,
    required this.selectedVendorIds,
    required this.onToggleSelected,
    required this.onEditVendor,
    required this.onDeleteVendor,
  });

  final List<VendorModel> vendors;
  final Set<String> selectedVendorIds;
  final void Function(String vendorId, bool selected) onToggleSelected;
  final ValueChanged<VendorModel> onEditVendor;
  final ValueChanged<String> onDeleteVendor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < vendors.length; i++) ...[
            InkWell(
              onTap: () => onEditVendor(vendors[i]),
              borderRadius: BorderRadius.vertical(
                top: i == 0 ? const Radius.circular(16) : Radius.zero,
                bottom: i == vendors.length - 1
                    ? const Radius.circular(16)
                    : Radius.zero,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Checkbox(
                      value: selectedVendorIds.contains(vendors[i].id),
                      onChanged: (selected) {
                        onToggleSelected(vendors[i].id, selected ?? false);
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vendors[i].name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            vendors[i].category,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _RatingStars(rating: vendors[i].ratingScore),
                    ),
                    const SizedBox(width: 12),
                    _YesNoBadge(value: vendors[i].isApproved, label: 'Approved'),
                    const SizedBox(width: 8),
                    _YesNoBadge(value: vendors[i].isPreferred, label: 'Preferred'),
                    const SizedBox(width: 12),
                    _VendorStatusPill(status: vendors[i].status),
                    const SizedBox(width: 8),
                    _VendorActionsMenu(
                      onEdit: () => onEditVendor(vendors[i]),
                      onDelete: () => onDeleteVendor(vendors[i].id),
                    ),
                  ],
                ),
              ),
            ),
            if (i != vendors.length - 1)
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
          ],
        ],
      ),
    );
  }
}

class _VendorGrid extends StatelessWidget {
  const _VendorGrid({
    required this.vendors,
    required this.selectedVendorIds,
    required this.onToggleSelected,
    required this.onEditVendor,
    required this.onDeleteVendor,
  });

  final List<VendorModel> vendors;
  final Set<String> selectedVendorIds;
  final void Function(String vendorId, bool selected) onToggleSelected;
  final ValueChanged<VendorModel> onEditVendor;
  final ValueChanged<String> onDeleteVendor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final int columns = width > 900 ? 3 : (width > 600 ? 2 : 1);
        final double cardWidth = (width - ((columns - 1) * 24)) / columns;

        return Wrap(
          spacing: 24,
          runSpacing: 24,
          children: List.generate(vendors.length, (index) {
            final vendor = vendors[index];
            return SizedBox(
              width: cardWidth,
              child: _VendorNameCell(
                vendor: vendor,
                selectedVendorIds: selectedVendorIds,
                onToggleSelected: onToggleSelected,
                onEditVendor: onEditVendor,
                onDeleteVendor: onDeleteVendor,
              ),
            );
          }),
        );
      },
    );
  }
}

class _VendorActionsMenu extends StatelessWidget {
  const _VendorActionsMenu({
    required this.onEdit,
    required this.onDelete,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onEdit();
          case 'delete':
            onDelete();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Text('Edit')),
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
      icon: const Icon(Icons.more_horiz, color: Color(0xFF64748B)),
    );
  }
}

class _VendorNameCell extends StatelessWidget {
  const _VendorNameCell({
    required this.vendor,
    required this.selectedVendorIds,
    required this.onToggleSelected,
    required this.onEditVendor,
    required this.onDeleteVendor,
  });

  final VendorModel vendor;
  final Set<String> selectedVendorIds;
  final void Function(String vendorId, bool selected) onToggleSelected;
  final ValueChanged<VendorModel> onEditVendor;
  final ValueChanged<String> onDeleteVendor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: selectedVendorIds.contains(vendor.id),
                onChanged: (selected) {
                  onToggleSelected(vendor.id, selected ?? false);
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vendor.category,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              _VendorActionsMenu(
                onEdit: () => onEditVendor(vendor),
                onDelete: () => onDeleteVendor(vendor.id),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _RatingStars(rating: vendor.ratingScore),
              const Spacer(),
              _YesNoBadge(value: vendor.isApproved, label: 'Approved'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _YesNoBadge(value: vendor.isPreferred, label: 'Preferred'),
              const Spacer(),
              _VendorStatusPill(status: vendor.status),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  const _RatingStars({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 16,
          color: index < rating
              ? const Color(0xFFF59E0B)
              : const Color(0xFFD1D5DB),
        );
      }),
    );
  }
}

class _YesNoBadge extends StatelessWidget {
  const _YesNoBadge({required this.value, required this.label});

  final bool value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: value
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: ${value ? "Yes" : "No"}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: value
              ? const Color(0xFF047857)
              : const Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _VendorStatusPill extends StatelessWidget {
  const _VendorStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    late Color bg;
    late Color fg;

    switch (status.toLowerCase()) {
      case 'active':
      case 'approved':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF047857);
      case 'pending':
      case 'invited':
        bg = const Color(0xFFFFF7ED);
        fg = const Color(0xFFF97316);
      case 'inactive':
      case 'suspended':
        bg = const Color(0xFFFFF1F2);
        fg = const Color(0xFFDC2626);
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
