import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ndu_project/services/vendor_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/widgets/inline_editable_text.dart';
import 'package:ndu_project/widgets/responsive_table_widgets.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';

/// World-class Vendor Scorecard Table
/// Professional design with rich data visualization, inline editing, and AI capabilities
class VendorsTableWidget extends StatelessWidget {
  const VendorsTableWidget({
    super.key,
    required this.vendors,
    required this.onUpdated,
    required this.onDeleted,
    this.canEdit = true,
    this.canDelete = true,
    this.canUseAi = true,
  });

  final List<VendorModel> vendors;
  final ValueChanged<VendorModel> onUpdated;
  final ValueChanged<VendorModel> onDeleted;
  final bool canEdit;
  final bool canDelete;
  final bool canUseAi;

  @override
  Widget build(BuildContext context) {
    if (vendors.isEmpty) {
      return buildNduTableEmptyState(
        context,
        message: 'No vendors added yet. Click + Add to get started.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ResponsiveDataTableWrapper(
            minWidth: constraints.maxWidth > 0 ? constraints.maxWidth : 1100,
            maxHeight: 520,
            child: buildNduDataTable(
              context: context,
              columnSpacing: 20,
              horizontalMargin: 18,
              headingRowHeight: 52,
              dataRowMinHeight: 56,
              dataRowMaxHeight: 72,
              columns: const [
                DataColumn(
                  label: _TableHeader('Vendor', icon: Icons.business_outlined),
                ),
                DataColumn(
                  label: _TableHeader('Category', icon: Icons.category_outlined),
                ),
                DataColumn(
                  label: _TableHeader('Criticality', icon: Icons.signal_cellular_alt),
                ),
                DataColumn(
                  label: _TableHeader('SLA', icon: Icons.verified_outlined),
                ),
                DataColumn(
                  label: _TableHeader('Rating', icon: Icons.star_outline),
                ),
                DataColumn(
                  label: _TableHeader('Status', icon: Icons.circle_outlined),
                ),
                DataColumn(
                  label: _TableHeader('Lead Time', icon: Icons.schedule_outlined),
                ),
                DataColumn(
                  label: _TableHeader('Actions', icon: Icons.more_horiz),
                ),
              ],
              rows: vendors.asMap().entries.map((entry) {
                final index = entry.key;
                final vendor = entry.value;
                return DataRow.byIndex(
                  index: index,
                  color: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) {
                      return const Color(0xFFF0F7FF);
                    }
                    return index.isOdd
                        ? const Color(0xFFFAFCFF)
                        : Colors.white;
                  }),
                  cells: [
                    // Vendor Name
                    DataCell(_VendorNameCell(
                      vendor: vendor,
                      canEdit: canEdit,
                      onUpdated: onUpdated,
                    )),
                    // Category
                    DataCell(_CategoryCell(
                      vendor: vendor,
                      canEdit: canEdit,
                      onUpdated: onUpdated,
                    )),
                    // Criticality
                    DataCell(_CriticalityCell(
                      vendor: vendor,
                      canEdit: canEdit,
                      onUpdated: onUpdated,
                    )),
                    // SLA Performance
                    DataCell(_SlaCell(
                      vendor: vendor,
                      canEdit: canEdit,
                      onUpdated: onUpdated,
                    )),
                    // Rating
                    DataCell(_RatingCell(
                      vendor: vendor,
                    )),
                    // Status
                    DataCell(_StatusCell(
                      vendor: vendor,
                    )),
                    // Lead Time
                    DataCell(_LeadTimeCell(
                      vendor: vendor,
                      canEdit: canEdit,
                      onUpdated: onUpdated,
                    )),
                    // Actions
                    DataCell(_ActionsCell(
                      vendor: vendor,
                      canEdit: canEdit,
                      canDelete: canDelete,
                      canUseAi: canUseAi,
                      onUpdated: onUpdated,
                      onDeleted: onDeleted,
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

// ─── Table Header ────────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.label, {this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF475569),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ─── Vendor Name Cell ────────────────────────────────────────────────────────

class _VendorNameCell extends StatelessWidget {
  const _VendorNameCell({
    required this.vendor,
    required this.canEdit,
    required this.onUpdated,
  });

  final VendorModel vendor;
  final bool canEdit;
  final ValueChanged<VendorModel> onUpdated;

  @override
  Widget build(BuildContext context) {
    if (!canEdit) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _vendorAvatar(vendor.name),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              vendor.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _vendorAvatar(vendor.name),
        const SizedBox(width: 10),
        Flexible(
          child: InlineEditableText(
            value: vendor.name,
            isListField: false,
            onChanged: (v) => onUpdated(_copyWith(name: v)),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
            textAlign: TextAlign.left,
          ),
        ),
      ],
    );
  }

  Widget _vendorAvatar(String name) {
    final initials = name.trim().isNotEmpty
        ? name
            .trim()
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : '?';

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  VendorModel _copyWith({String? name}) {
    return VendorModel(
      id: vendor.id,
      projectId: vendor.projectId,
      name: name ?? vendor.name,
      category: vendor.category,
      criticality: vendor.criticality,
      sla: vendor.sla,
      slaPerformance: vendor.slaPerformance,
      leadTime: vendor.leadTime,
      requiredDeliverables: vendor.requiredDeliverables,
      rating: vendor.rating,
      status: vendor.status,
      nextReview: vendor.nextReview,
      contractId: vendor.contractId,
      onTimeDelivery: vendor.onTimeDelivery,
      incidentResponse: vendor.incidentResponse,
      qualityScore: vendor.qualityScore,
      costAdherence: vendor.costAdherence,
      notes: vendor.notes,
      createdById: vendor.createdById,
      createdByEmail: vendor.createdByEmail,
      createdByName: vendor.createdByName,
      createdAt: vendor.createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

// ─── Category Cell ────────────────────────────────────────────────────────────

class _CategoryCell extends StatelessWidget {
  const _CategoryCell({
    required this.vendor,
    required this.canEdit,
    required this.onUpdated,
  });

  final VendorModel vendor;
  final bool canEdit;
  final ValueChanged<VendorModel> onUpdated;

  static const _categoryIcons = <String, IconData>{
    'Logistics': Icons.local_shipping_outlined,
    'IT Hardware': Icons.memory_outlined,
    'Consulting': Icons.psychology_outlined,
    'Raw Materials': Icons.inventory_2_outlined,
    'Utilities': Icons.bolt_outlined,
    'Technology': Icons.devices_outlined,
    'Operations': Icons.settings_outlined,
    'Facilities': Icons.apartment_outlined,
    'Services': Icons.handshake_outlined,
  };

  static const _categoryColors = <String, Color>{
    'Logistics': Color(0xFF0EA5E9),
    'IT Hardware': Color(0xFF6366F1),
    'Consulting': Color(0xFF8B5CF6),
    'Raw Materials': Color(0xFFF59E0B),
    'Utilities': Color(0xFF10B981),
    'Technology': Color(0xFFFBBF24),
    'Operations': Color(0xFF64748B),
    'Facilities': Color(0xFFEC4899),
    'Services': Color(0xFF14B8A6),
  };

  @override
  Widget build(BuildContext context) {
    final category = vendor.category;
    final icon = _categoryIcons[category] ?? Icons.label_outline;
    final color = _categoryColors[category] ?? const Color(0xFF64748B);

    if (!canEdit) {
      return _categoryPill(icon, color, category);
    }

    return DropdownButton<String>(
      value: category.isNotEmpty ? category : null,
      isDense: true,
      underline: const SizedBox(),
      icon: const SizedBox(width: 0, height: 0),
      items: _categoryIcons.keys
          .map((cat) => DropdownMenuItem(
                value: cat,
                child: _categoryPill(
                    _categoryIcons[cat] ?? Icons.label_outline,
                    _categoryColors[cat] ?? const Color(0xFF64748B),
                    cat),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null && v != category) {
          onUpdated(VendorModel(
            id: vendor.id,
            projectId: vendor.projectId,
            name: vendor.name,
            category: v,
            criticality: vendor.criticality,
            sla: vendor.sla,
            slaPerformance: vendor.slaPerformance,
            leadTime: vendor.leadTime,
            requiredDeliverables: vendor.requiredDeliverables,
            rating: vendor.rating,
            status: vendor.status,
            nextReview: vendor.nextReview,
            contractId: vendor.contractId,
            onTimeDelivery: vendor.onTimeDelivery,
            incidentResponse: vendor.incidentResponse,
            qualityScore: vendor.qualityScore,
            costAdherence: vendor.costAdherence,
            notes: vendor.notes,
            createdById: vendor.createdById,
            createdByEmail: vendor.createdByEmail,
            createdByName: vendor.createdByName,
            createdAt: vendor.createdAt,
            updatedAt: DateTime.now(),
          ));
        }
      },
      hint: _categoryPill(icon, color, category.isEmpty ? 'Select' : category),
    );
  }

  Widget _categoryPill(IconData icon, Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.15), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Criticality Cell ────────────────────────────────────────────────────────

class _CriticalityCell extends StatelessWidget {
  const _CriticalityCell({
    required this.vendor,
    required this.canEdit,
    required this.onUpdated,
  });

  final VendorModel vendor;
  final bool canEdit;
  final ValueChanged<VendorModel> onUpdated;

  static Color _getColor(String criticality) {
    return switch (criticality.toLowerCase()) {
      'high' => const Color(0xFFEF4444),
      'medium' => const Color(0xFFF59E0B),
      'low' => const Color(0xFF10B981),
      _ => const Color(0xFF9CA3AF),
    };
  }

  static IconData _getIcon(String criticality) {
    return switch (criticality.toLowerCase()) {
      'high' => Icons.keyboard_arrow_up_rounded,
      'medium' => Icons.remove_rounded,
      'low' => Icons.keyboard_arrow_down_rounded,
      _ => Icons.remove_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(vendor.criticality);
    final icon = _getIcon(vendor.criticality);

    if (!canEdit) {
      return _criticalityBadge(color, icon, vendor.criticality);
    }

    return DropdownButton<String>(
      value: vendor.criticality,
      isDense: true,
      underline: const SizedBox(),
      icon: const SizedBox(width: 0, height: 0),
      items: ['High', 'Medium', 'Low']
          .map((crit) => DropdownMenuItem(
                value: crit,
                child: _criticalityBadge(
                    _getColor(crit), _getIcon(crit), crit),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) {
          onUpdated(VendorModel(
            id: vendor.id,
            projectId: vendor.projectId,
            name: vendor.name,
            category: vendor.category,
            criticality: v,
            sla: vendor.sla,
            slaPerformance: vendor.slaPerformance,
            leadTime: vendor.leadTime,
            requiredDeliverables: vendor.requiredDeliverables,
            rating: vendor.rating,
            status: vendor.status,
            nextReview: vendor.nextReview,
            contractId: vendor.contractId,
            onTimeDelivery: vendor.onTimeDelivery,
            incidentResponse: vendor.incidentResponse,
            qualityScore: vendor.qualityScore,
            costAdherence: vendor.costAdherence,
            notes: vendor.notes,
            createdById: vendor.createdById,
            createdByEmail: vendor.createdByEmail,
            createdByName: vendor.createdByName,
            createdAt: vendor.createdAt,
            updatedAt: DateTime.now(),
          ));
        }
      },
    );
  }

  Widget _criticalityBadge(Color color, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SLA Performance Cell ────────────────────────────────────────────────────

class _SlaCell extends StatelessWidget {
  const _SlaCell({
    required this.vendor,
    required this.canEdit,
    required this.onUpdated,
  });

  final VendorModel vendor;
  final bool canEdit;
  final ValueChanged<VendorModel> onUpdated;

  @override
  Widget build(BuildContext context) {
    final perf = vendor.slaPerformance.clamp(0.0, 1.0);
    final percentage = (perf * 100).round();
    final slaLabel = vendor.sla.isNotEmpty ? vendor.sla : '$percentage%';

    Color perfColor;
    if (perf >= 0.8) {
      perfColor = const Color(0xFF10B981);
    } else if (perf >= 0.6) {
      perfColor = const Color(0xFFF59E0B);
    } else {
      perfColor = const Color(0xFFEF4444);
    }

    return SizedBox(
      width: 120,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                slaLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: perfColor,
                ),
              ),
              Text(
                vendor.onTimeDelivery >= 0.8 ? 'On track' : vendor.onTimeDelivery >= 0.6 ? 'At risk' : 'Behind',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: perfColor.withOpacity(0.7),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: perf,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: perfColor,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: perfColor.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Rating Cell ──────────────────────────────────────────────────────────────

class _RatingCell extends StatelessWidget {
  const _RatingCell({required this.vendor});

  final VendorModel vendor;

  static const _ratingConfig = <String, (Color, String)>{
    'A': (Color(0xFF10B981), 'Excellent'),
    'B': (Color(0xFF0EA5E9), 'Good'),
    'C': (Color(0xFFF59E0B), 'Fair'),
    'D': (Color(0xFFEF4444), 'Poor'),
  };

  @override
  Widget build(BuildContext context) {
    final rating = vendor.rating.toUpperCase();
    final config = _ratingConfig[rating] ??
        (const Color(0xFF9CA3AF), 'Unrated');
    final color = config.$1;
    final tooltip = config.$2;

    return Tooltip(
      message: '$rating - $tooltip',
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Center(
          child: Text(
            rating,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Status Cell ──────────────────────────────────────────────────────────────

class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.vendor});

  final VendorModel vendor;

  static const _statusConfig = <String, (Color, IconData)>{
    'Active': (Color(0xFF10B981), Icons.check_circle_rounded),
    'Watch': (Color(0xFFF59E0B), Icons.visibility_outlined),
    'At risk': (Color(0xFFEF4444), Icons.warning_amber_rounded),
    'Onboard': (Color(0xFF0EA5E9), Icons.flight_takeoff_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final status = vendor.status;
    final config = _statusConfig[status] ??
        (const Color(0xFF9CA3AF), Icons.help_outline_rounded);
    final color = config.$1;
    final icon = config.$2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.15), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Lead Time Cell ──────────────────────────────────────────────────────────

class _LeadTimeCell extends StatelessWidget {
  const _LeadTimeCell({
    required this.vendor,
    required this.canEdit,
    required this.onUpdated,
  });

  final VendorModel vendor;
  final bool canEdit;
  final ValueChanged<VendorModel> onUpdated;

  @override
  Widget build(BuildContext context) {
    if (!canEdit) {
      return _leadTimeChip(vendor.leadTime);
    }
    return InlineEditableText(
      value: vendor.leadTime,
      isListField: false,
      onChanged: (v) => onUpdated(VendorModel(
        id: vendor.id,
        projectId: vendor.projectId,
        name: vendor.name,
        category: vendor.category,
        criticality: vendor.criticality,
        sla: vendor.sla,
        slaPerformance: vendor.slaPerformance,
        leadTime: v,
        requiredDeliverables: vendor.requiredDeliverables,
        rating: vendor.rating,
        status: vendor.status,
        nextReview: vendor.nextReview,
        contractId: vendor.contractId,
        onTimeDelivery: vendor.onTimeDelivery,
        incidentResponse: vendor.incidentResponse,
        qualityScore: vendor.qualityScore,
        costAdherence: vendor.costAdherence,
        notes: vendor.notes,
        createdById: vendor.createdById,
        createdByEmail: vendor.createdByEmail,
        createdByName: vendor.createdByName,
        createdAt: vendor.createdAt,
        updatedAt: DateTime.now(),
      )),
      style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
      textAlign: TextAlign.left,
    );
  }

  Widget _leadTimeChip(String leadTime) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 12, color: Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            leadTime,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Actions Cell ─────────────────────────────────────────────────────────────

class _ActionsCell extends StatefulWidget {
  const _ActionsCell({
    required this.vendor,
    required this.canEdit,
    required this.canDelete,
    required this.canUseAi,
    required this.onUpdated,
    required this.onDeleted,
  });

  final VendorModel vendor;
  final bool canEdit;
  final bool canDelete;
  final bool canUseAi;
  final ValueChanged<VendorModel> onUpdated;
  final ValueChanged<VendorModel> onDeleted;

  @override
  State<_ActionsCell> createState() => _ActionsCellState();
}

class _ActionsCellState extends State<_ActionsCell> {
  bool _isHovering = false;
  bool _isRegenerating = false;
  VendorModel? _previousState;

  Future<void> _undo() async {
    if (_previousState == null) return;
    final previous = _previousState!;
    setState(() {
      _previousState = null;
    });
    try {
      await VendorService.updateVendor(
        projectId: previous.projectId,
        vendorId: previous.id,
        name: previous.name,
        category: previous.category,
        criticality: previous.criticality,
        sla: previous.sla,
        slaPerformance: previous.slaPerformance,
        leadTime: previous.leadTime,
        requiredDeliverables: previous.requiredDeliverables,
        rating: previous.rating,
        status: previous.status,
        nextReview: previous.nextReview,
        contractId: previous.contractId,
        onTimeDelivery: previous.onTimeDelivery,
        incidentResponse: previous.incidentResponse,
        qualityScore: previous.qualityScore,
        costAdherence: previous.costAdherence,
        notes: previous.notes,
      );
    } catch (e) {
      debugPrint('Error undoing vendor: $e');
    }
    widget.onUpdated(previous);
  }

  Future<void> _regenerateSLATerms() async {
    if (_isRegenerating) return;
    setState(() => _isRegenerating = true);

    try {
      final provider = ProjectDataInherited.maybeOf(context);
      if (provider == null) return;

      final contextText = ProjectDataHelper.buildExecutivePlanContext(
        provider.projectData,
        sectionLabel: 'Vendor Tracking',
      );

      final ai = OpenAiServiceSecure();
      final slaTerms = await ai.generateVendorSLATerms(
        context: contextText,
        vendorCategory: widget.vendor.category,
      );

      final updated = VendorModel(
        id: widget.vendor.id,
        projectId: widget.vendor.projectId,
        name: widget.vendor.name,
        category: widget.vendor.category,
        criticality: widget.vendor.criticality,
        sla: widget.vendor.sla,
        slaPerformance: widget.vendor.slaPerformance,
        leadTime: widget.vendor.leadTime,
        requiredDeliverables: slaTerms,
        rating: widget.vendor.rating,
        status: widget.vendor.status,
        nextReview: widget.vendor.nextReview,
        contractId: widget.vendor.contractId,
        onTimeDelivery: widget.vendor.onTimeDelivery,
        incidentResponse: widget.vendor.incidentResponse,
        qualityScore: widget.vendor.qualityScore,
        costAdherence: widget.vendor.costAdherence,
        notes: widget.vendor.notes,
        createdById: widget.vendor.createdById,
        createdByEmail: widget.vendor.createdByEmail,
        createdByName: widget.vendor.createdByName,
        createdAt: widget.vendor.createdAt,
        updatedAt: DateTime.now(),
      );

      _previousState = widget.vendor;
      await VendorService.updateVendor(
        projectId: updated.projectId,
        vendorId: updated.id,
        requiredDeliverables: updated.requiredDeliverables,
      );
      widget.onUpdated(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SLA terms regenerated successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error regenerating SLA terms: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  Future<void> _deleteVendor() async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Delete Vendor',
      itemLabel: widget.vendor.name,
    );
    if (!confirmed) return;
    final deleted = widget.vendor;

    try {
      await VendorService.deleteVendor(
        projectId: deleted.projectId,
        vendorId: deleted.id,
      );
    } catch (e) {
      debugPrint('Error deleting vendor: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting vendor: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    widget.onDeleted(deleted);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Vendor deleted'),
              Spacer(),
            ],
          ),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () async {
              try {
                await VendorService.createVendor(
                  projectId: deleted.projectId,
                  name: deleted.name,
                  category: deleted.category,
                  criticality: deleted.criticality,
                  sla: deleted.sla,
                  slaPerformance: deleted.slaPerformance,
                  leadTime: deleted.leadTime,
                  requiredDeliverables: deleted.requiredDeliverables,
                  rating: deleted.rating,
                  status: deleted.status,
                  nextReview: deleted.nextReview,
                  contractId: deleted.contractId,
                  onTimeDelivery: deleted.onTimeDelivery,
                  incidentResponse: deleted.incidentResponse,
                  qualityScore: deleted.qualityScore,
                  costAdherence: deleted.costAdherence,
                  notes: deleted.notes,
                  createdById: deleted.createdById,
                  createdByEmail: deleted.createdByEmail,
                  createdByName: deleted.createdByName,
                );
                widget.onUpdated(deleted);
              } catch (e) {
                debugPrint('Error restoring vendor: $e');
              }
            },
          ),
          duration: const Duration(seconds: 5),
          backgroundColor: const Color(0xFF111827),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) =>
          Future.microtask(() => setState(() => _isHovering = true)),
      onExit: (_) =>
          Future.microtask(() => setState(() => _isHovering = false)),
      child: _isHovering
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_previousState != null)
                  _actionIcon(
                    Icons.undo_rounded,
                    color: const Color(0xFF64748B),
                    tooltip: 'Undo',
                    onPressed: _undo,
                  ),
                if (widget.canUseAi)
                  _isRegenerating
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                        )
                      : _actionIcon(
                          Icons.auto_awesome,
                          color: const Color(0xFF7C3AED),
                          tooltip: 'Regenerate SLA',
                          onPressed: _regenerateSLATerms,
                        ),
                if (widget.canEdit)
                  _actionIcon(
                    Icons.edit_outlined,
                    color: const Color(0xFF0EA5E9),
                    tooltip: 'Edit',
                    onPressed: () {
                      // Trigger inline edit mode via the parent
                    },
                  ),
                if (widget.canDelete)
                  _actionIcon(
                    Icons.delete_outline_rounded,
                    color: const Color(0xFFEF4444),
                    tooltip: 'Delete',
                    onPressed: _deleteVendor,
                  ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.more_horiz,
                    size: 18, color: const Color(0xFFCBD5E1)),
              ],
            ),
    );
  }

  Widget _actionIcon(IconData icon,
      {required Color color, required String tooltip, VoidCallback? onPressed}) {
    return IconButton(
      icon: Icon(icon, size: 16, color: color),
      onPressed: onPressed,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      splashRadius: 14,
    );
  }
}
