import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/expandable_text.dart';
import 'package:ndu_project/widgets/page_regenerate_all_button.dart';
import 'package:ndu_project/providers/project_data_provider.dart';

// ─── Brand Color Tokens ───
class BrandColors {
  static const background = Color(0xFFF7F9FB);
  static const primary = Color(0xFFB45309);
  static const primaryContainer = Color(0xFFD97706);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onPrimaryContainer = Color(0xFFFEFCFF);
  static const surface = Color(0xFFF7F9FB);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainer = Color(0xFFECEEF0);
  static const inverseSurface = Color(0xFF2D3133);
  static const onSurface = Color(0xFF191C1E);
  static const onSurfaceVariant = Color(0xFF414754);
  static const outline = Color(0xFF717786);
  static const outlineVariant = Color(0xFFC0C6D6);
  static const error = Color(0xFFBA1A1A);
  static const tertiaryFixedDim = Color(0xFFFABD00);
  static const tertiary = Color(0xFF755700);
  static const secondaryContainer = Color(0xFFE2DFDE);
  static const secondary = Color(0xFF5F5E5E);
  static const primaryFixed = Color(0xFFD6E3FF);
  static const onPrimaryFixedVariant = Color(0xFF00468C);
  static const tertiaryFixed = Color(0xFFFFDF9E);
  static const onTertiaryFixedVariant = Color(0xFF5B4300);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);
  static const onTertiary = Color(0xFFFFFFFF);
  static const onError = Color(0xFFFFFFFF);
}

// ─── Shared Styles (backward compatibility) ───
const kSectionTitleStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w700,
  color: Color(0xFF111827),
  letterSpacing: 0.5,
);

const kCardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(12)),
  boxShadow: [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.05),
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
  ],
);

const kCardBorderDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(12)),
  border: Border.fromBorderSide(
    BorderSide(color: BrandColors.outlineVariant, width: 1),
  ),
  boxShadow: [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.04),
      offset: Offset(0, 1),
      blurRadius: 3,
    ),
  ],
);

Widget sectionTitleWithIcon(IconData icon, String title) {
  return Row(
    children: [
      Icon(icon, size: 20, color: BrandColors.primary),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: BrandColors.onSurface,
        ),
      ),
    ],
  );
}

Widget labelStyle(String text) {
  return Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: BrandColors.onSurfaceVariant,
      letterSpacing: 0.8,
    ),
  );
}

// ─── 1. Hero Header ───

class CharterHeroHeader extends StatelessWidget {
  final ProjectDataModel? data;
  final VoidCallback? onRegenerateAll;
  final bool isLoading;

  const CharterHeroHeader({
    super.key,
    required this.data,
    this.onRegenerateAll,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final projectName = data?.projectName.isNotEmpty == true
        ? data!.projectName
        : 'Untitled Project';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top row: Label + Export PDF + AI Assist + Regenerate button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PROJECT CHARTER',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: BrandColors.primary,
                letterSpacing: 1.2,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onRegenerateAll != null) ...[
                  const SizedBox(width: 8),
                  PageRegenerateAllButton(
                    onRegenerateAll: onRegenerateAll!,
                    isLoading: isLoading,
                    tooltip: 'Regenerate all charter content',
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Project name + Active badge
        Row(
          children: [
            Expanded(
              child: Text(
                projectName,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.onSurface,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: BrandColors.primaryContainer.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Active',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: BrandColors.primary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── 2. Dashboard Stats Grid ───

class CharterDashboardStats extends StatelessWidget {
  final ProjectDataModel? data;

  const CharterDashboardStats({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data == null) return const SizedBox();

    final totalCost = _calculateTotalCost(data!);
    final opportunities = _countOpportunities(data!);
    final duration = _calculateDuration(data!);
    final riskLevel = _calculateRiskLevel(data!);
    final projectManager = _determineProjectManager(data!);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 768;
    final mobileItemWidth = (screenWidth - 96) / 2;

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: 24,
        horizontal: isMobile ? 16 : 32,
      ),
      decoration: BoxDecoration(
        color: BrandColors.inverseSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.15),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Wrap(
        spacing: isMobile ? 12 : 0,
        runSpacing: isMobile ? 16 : 0,
        alignment: isMobile ? WrapAlignment.start : WrapAlignment.spaceBetween,
        children: [
          _buildStatItem(
            'TOTAL COST',
            totalCost,
            Colors.white,
            isMobile,
            mobileWidth: mobileItemWidth,
          ),
          if (!isMobile) _buildDivider(),
          _buildStatItem(
            'OPPORTUNITIES',
            opportunities,
            const Color(0xFF4ADE80),
            isMobile,
            mobileWidth: mobileItemWidth,
          ),
          if (!isMobile) _buildDivider(),
          _buildStatItem(
            'DURATION',
            duration,
            const Color(0xFFFBBF24),
            isMobile,
            mobileWidth: mobileItemWidth,
          ),
          if (!isMobile) _buildDivider(),
          _buildStatItem(
            'RISK',
            riskLevel,
            riskLevel.toLowerCase() == 'high'
                ? const Color(0xFFF87171)
                : riskLevel.toLowerCase() == 'medium'
                ? BrandColors.tertiaryFixedDim
                : const Color(0xFF4ADE80),
            isMobile,
            mobileWidth: mobileItemWidth,
          ),
          if (!isMobile) _buildDivider(),
          _buildStatItem(
            'PROJECT MANAGER',
            projectManager,
            const Color(0xFFFBBF24),
            isMobile,
            mobileWidth: mobileItemWidth,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    Color valueColor,
    bool isMobile, {
    double? mobileWidth,
  }) {
    return SizedBox(
      width: isMobile && mobileWidth != null ? mobileWidth : null,
      child: Column(
        crossAxisAlignment: isMobile
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: isMobile ? TextAlign.left : TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: isMobile ? TextAlign.left : TextAlign.center,
            style: TextStyle(
              color: valueColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withOpacity(0.2),
    );
  }

  String _calculateTotalCost(ProjectDataModel data) {
    final total = ProjectDataHelper.getTotalEstimatedCostValue(data);
    return NumberFormat.simpleCurrency(
      name: data.costBenefitCurrency,
    ).format(total);
  }

  String _countOpportunities(ProjectDataModel data) {
    return ProjectDataHelper.getExpectedOpportunitiesCount(data).toString();
  }

  String _calculateDuration(ProjectDataModel data) {
    if (data.keyMilestones.isEmpty) return 'TBD';
    DateTime? start;
    DateTime? end;
    for (var m in data.keyMilestones) {
      final date = DateTime.tryParse(m.dueDate);
      if (date != null) {
        if (start == null || date.isBefore(start)) start = date;
        if (end == null || date.isAfter(end)) end = date;
      }
    }
    if (start != null && end != null) {
      final days = end.difference(start).inDays;
      return '${days < 0 ? 0 : days} Days';
    }
    return 'TBD';
  }

  String _calculateRiskLevel(ProjectDataModel data) {
    final register = data.frontEndPlanning.riskRegisterItems;
    if (register.isNotEmpty) {
      if (register.any((r) => r.impactLevel.toLowerCase() == 'high')) {
        return 'High';
      }
      if (register.any((r) => r.impactLevel.toLowerCase() == 'medium')) {
        return 'Medium';
      }
      return 'Low';
    }
    if (data.solutionRisks.isNotEmpty) return 'Medium';
    return 'Low';
  }

  String _determineProjectManager(ProjectDataModel data) {
    if (data.charterProjectManagerName.isNotEmpty) {
      return data.charterProjectManagerName;
    }
    if (data.charterProjectSponsorName.isNotEmpty) {
      return data.charterProjectSponsorName;
    }
    return 'Not Assigned';
  }
}

// ─── 3. Meta Info Horizontal Scroll ───

class CharterMetaInfoScroll extends StatefulWidget {
  final ProjectDataModel? data;

  const CharterMetaInfoScroll({super.key, required this.data});

  @override
  State<CharterMetaInfoScroll> createState() => _CharterMetaInfoScrollState();
}

class _CharterMetaInfoScrollState extends State<CharterMetaInfoScroll> {
  @override
  Widget build(BuildContext context) {
    if (widget.data == null) return const SizedBox();

    final data = widget.data!;
    final hasManager = data.charterProjectManagerName.isNotEmpty;

    final items = [
      _MetaInfoItem(
        icon: Icons.person_outline,
        label: 'Project Manager',
        value: hasManager ? data.charterProjectManagerName : 'Assign Manager',
        iconBgColor: BrandColors.secondaryContainer,
        iconFgColor: const Color(0xFF636262),
        onTap: hasManager ? null : () => _showAssignManagerDialog(data),
      ),
      // Ref-ID removed per user request — the charter no longer displays
      // an internal reference ID badge in the meta info row.
      _MetaInfoItem(
        icon: Icons.calendar_today_outlined,
        label: 'Start Date',
        value: _formatDate(data.createdAt),
        iconBgColor: BrandColors.tertiaryFixed,
        iconFgColor: BrandColors.onTertiaryFixedVariant,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _MetaInfoCard(item: item),
          );
        }).toList(),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not Provided';
    return DateFormat('MMM d, yyyy').format(date);
  }

  Future<void> _showAssignManagerDialog(ProjectDataModel data) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_add_outlined,
                  color: Color(0xFFB45309),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Assign Project Manager'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assign a project manager to this project. '
                    'A manager must be assigned before proceeding to the next step.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Manager Name',
                      hintText: 'e.g. John Doe',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a manager name';
                      }
                      if (value.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email (optional)',
                      hintText: 'e.g. john.doe@company.com',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop({
                    'name': nameController.text.trim(),
                    'email': emailController.text.trim(),
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC812),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Assign'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    // Persist the manager assignment to Firestore via ProjectDataHelper
    try {
      await ProjectDataHelper.updateAndSave(
        context: context,
        checkpoint: 'project_charter',
        dataUpdater: (current) =>
            current.copyWith(charterProjectManagerName: result['name']!),
        showSnackbar: false,
      );

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result['name']} assigned as Project Manager'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign manager: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      nameController.dispose();
      emailController.dispose();
    }
  }
}

class _MetaInfoItem {
  final IconData icon;
  final String label;
  final String value;
  final Color iconBgColor;
  final Color iconFgColor;
  final VoidCallback? onTap;

  const _MetaInfoItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconBgColor,
    required this.iconFgColor,
    this.onTap,
  });
}

class _MetaInfoCard extends StatelessWidget {
  final _MetaInfoItem item;

  const _MetaInfoCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: kCardBorderDecoration,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, size: 20, color: item.iconFgColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: BrandColors.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BrandColors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (item.onTap != null) {
      return GestureDetector(
        onTap: item.onTap,
        child: MouseRegion(cursor: SystemMouseCursors.click, child: card),
      );
    }
    return card;
  }
}

// ─── 4a. Project Definition Card ───

class CharterProjectDefinition extends StatelessWidget {
  final ProjectDataModel? data;
  final VoidCallback? onEdit;

  /// Project Purpose is sourced from Project Details. The charter only
  /// reflects that content, so the card links back for edits instead of
  /// generating new text locally.

  const CharterProjectDefinition({
    super.key,
    required this.data,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (data == null) return const SizedBox();

    final projectPurposeText = data!.projectObjective.trim().isNotEmpty
        ? data!.projectObjective
        : data!.solutionDescription.trim().isNotEmpty
        ? data!.solutionDescription
        : data!.businessCase;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: kCardBorderDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              sectionTitleWithIcon(
                Icons.description_outlined,
                'Project Purpose',
              ),
              if (onEdit != null)
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text(
                    'Edit on Details Page',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: BrandColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Project Purpose text
          ExpandableText(
            text: projectPurposeText.trim().isEmpty
                ? 'Summarize the overall aim of the project and what it will deliver.'
                : projectPurposeText,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: projectPurposeText.trim().isEmpty
                  ? BrandColors.onSurfaceVariant
                  : BrandColors.onSurface,
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 20),
          const Divider(color: BrandColors.outlineVariant),
          const SizedBox(height: 16),
          // Business Case subsection
          Text(
            'BUSINESS CASE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: BrandColors.primary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          ExpandableText(
            text: data!.businessCase.trim().isEmpty
                ? 'Provide the financial and strategic rationale (ROI/NPV context) for this project.'
                : data!.businessCase,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: data!.businessCase.trim().isEmpty
                  ? BrandColors.onSurfaceVariant
                  : BrandColors.onSurface,
            ),
            maxLines: 4,
          ),
        ],
      ),
    );
  }
}

// ─── 4b. Financial Overview Card ───

class CharterFinancialOverview extends StatelessWidget {
  final ProjectDataModel? data;

  const CharterFinancialOverview({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data == null) return const SizedBox();

    final cost = ProjectDataHelper.getTotalEstimatedCostValue(data!);
    final costStr = NumberFormat.simpleCurrency(
      name: data!.costBenefitCurrency,
    ).format(cost);
    final opportunitiesCount = ProjectDataHelper.getExpectedOpportunitiesCount(
      data!,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: kCardBorderDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              sectionTitleWithIcon(
                Icons.payments_outlined,
                'Financial Overview',
              ),
              // "ROI Analysis" badge removed per user request — the
              // charter no longer displays an ROI Analysis pill.
            ],
          ),
          const SizedBox(height: 20),

          // Metrics row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    labelStyle('Total Cost'),
                    const SizedBox(height: 4),
                    Text(
                      costStr,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: BrandColors.error,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: BrandColors.outlineVariant,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    labelStyle('Opportunities'),
                    const SizedBox(height: 4),
                    Text(
                      opportunitiesCount.toString(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: BrandColors.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: BrandColors.outlineVariant),
          const SizedBox(height: 16),

          // Cost breakdown bar
          labelStyle('Estimated Cost Breakdown'),
          const SizedBox(height: 12),
          _buildCostChart(data!),
        ],
      ),
    );
  }

  Widget _buildCostChart(ProjectDataModel data) {
    final segments = _buildCostBreakdownSegments(data);
    if (segments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'No cost estimates to display.',
          style: TextStyle(
            color: BrandColors.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    final total = segments.fold<double>(
      0.0,
      (sum, segment) => sum + segment.amount,
    );
    final currency = NumberFormat.compactSimpleCurrency(
      name: data.costBenefitCurrency,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stacked progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(
            children: [
              for (final segment in segments)
                Expanded(
                  flex:
                      (segment.amount <= 0
                              ? 1
                              : (segment.amount / total * 100).round())
                          .clamp(1, 100),
                  child: Tooltip(
                    message:
                        '${segment.label}: ${currency.format(segment.amount)}',
                    child: Container(height: 14, color: segment.color),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Legend
        ...segments.map((segment) {
          final pct = total > 0 ? (segment.amount / total) * 100 : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: segment.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    segment.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    '${pct.toStringAsFixed(1)}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      color: BrandColors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: Text(
                    currency.format(segment.amount),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  List<_CostBreakdownSegment> _buildCostBreakdownSegments(
    ProjectDataModel data,
  ) {
    final segments = <_CostBreakdownSegment>[];

    final estimateItems =
        ProjectDataHelper.getActiveCostEstimateItems(
            data,
            costState: 'forecast',
          ).where((item) => item.amount > 0).toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));

    if (estimateItems.isNotEmpty) {
      for (var i = 0; i < estimateItems.length && i < 6; i++) {
        final item = estimateItems[i];
        segments.add(
          _CostBreakdownSegment(
            label: item.title.trim().isNotEmpty
                ? item.title.trim()
                : 'Estimate Item ${i + 1}',
            amount: item.amount,
            color: _getColor(i),
          ),
        );
      }
      return segments;
    }

    final categoryTotals = <String, double>{
      'Allowances': data.frontEndPlanning.allowanceItems.fold<double>(
        0.0,
        (sum, item) => sum + item.amount,
      ),
      'Contracting': data.contractors.fold<double>(
        0.0,
        (sum, item) => sum + item.estimatedCost,
      ),
      'Procurement': data.vendors.fold<double>(
        0.0,
        (sum, item) => sum + item.estimatedPrice,
      ),
    };

    var colorIndex = 0;
    categoryTotals.forEach((label, amount) {
      if (amount <= 0) return;
      segments.add(
        _CostBreakdownSegment(
          label: label,
          amount: amount,
          color: _getColor(colorIndex++),
        ),
      );
    });

    if (segments.isNotEmpty) return segments;

    final costAnalysisTotal =
        data.costAnalysisData?.solutionCosts.fold<double>(
          0.0,
          (sum, solution) =>
              sum +
              solution.costRows.fold<double>(
                0.0,
                (rowSum, row) => rowSum + (double.tryParse(row.cost) ?? 0.0),
              ),
        ) ??
        0.0;
    if (costAnalysisTotal > 0) {
      segments.add(
        _CostBreakdownSegment(
          label: 'Initial Cost Estimate',
          amount: costAnalysisTotal,
          color: _getColor(0),
        ),
      );
    }

    return segments;
  }

  Color _getColor(int index) {
    const table = [
      BrandColors.primary,
      BrandColors.error,
      Color(0xFF10B981),
      BrandColors.tertiaryFixedDim,
      Color(0xFF8B5CF6),
    ];
    return table[index % table.length];
  }
}

class _CostBreakdownSegment {
  final String label;
  final double amount;
  final Color color;

  const _CostBreakdownSegment({
    required this.label,
    required this.amount,
    required this.color,
  });
}

// ─── 4c. Success Criteria Card ───

class CharterSuccessCriteria extends StatelessWidget {
  final ProjectDataModel? data;

  const CharterSuccessCriteria({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data == null) return const SizedBox();

    final items = data!.frontEndPlanning.successCriteriaItems;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: kCardBorderDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitleWithIcon(Icons.task_alt_outlined, 'Success Criteria'),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Text(
              'No success criteria defined.',
              style: TextStyle(
                color: BrandColors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 20,
                      color: BrandColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title.isNotEmpty
                                ? item.title
                                : item.description,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: BrandColors.onSurface,
                            ),
                          ),
                          if (item.title.isNotEmpty &&
                              item.description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                item.description,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: BrandColors.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── 4d. Project Scope Card ───

class CharterScope extends StatelessWidget {
  final ProjectDataModel? data;
  final VoidCallback? onGenerate;

  /// When provided, the card shows an "Edit" button that navigates the user
  /// back to the Project Details page (where the scope actually lives).
  /// The AI Generate button has been removed — the charter merely reflects
  /// what was entered on the Project Details page.
  final VoidCallback? onEdit;

  const CharterScope({
    super.key,
    required this.data,
    this.onGenerate,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (data == null) return const SizedBox();

    final inScopeItems = data!.withinScope
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final outOfScopeItems = data!.outOfScope
        .where((s) => s.trim().isNotEmpty)
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: kCardBorderDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              sectionTitleWithIcon(Icons.zoom_in_outlined, 'Project Scope'),
              // AI Generate removed — scope comes from the Project Details
              // page. Show an Edit button that takes the user back there.
              if (onEdit != null)
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text(
                    'Edit on Details Page',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: BrandColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Within Scope - tag pills
          Text(
            'WITHIN SCOPE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: BrandColors.primary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          if (inScopeItems.isEmpty)
            const Text(
              'Not specified',
              style: TextStyle(
                color: BrandColors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: inScopeItems.map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: BrandColors.primaryFixed,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: BrandColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    item.trim(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: BrandColors.onPrimaryFixedVariant,
                    ),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 20),

          // Out of Scope - bullet list with error-colored label
          Text(
            'OUT OF SCOPE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: BrandColors.error,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          if (outOfScopeItems.isEmpty)
            const Text(
              'Not specified',
              style: TextStyle(
                color: BrandColors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: outOfScopeItems.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 6, right: 10),
                        decoration: const BoxDecoration(
                          color: BrandColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item.trim(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: BrandColors.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

// ─── 5. Key Risks Section ───

class CharterRisks extends StatelessWidget {
  final ProjectDataModel? data;
  final VoidCallback? onGenerate;

  const CharterRisks({super.key, required this.data, this.onGenerate});

  @override
  Widget build(BuildContext context) {
    if (data == null) return const SizedBox();

    final riskRegister = data!.frontEndPlanning.riskRegisterItems;
    List<Map<String, dynamic>> allRisks = [];

    if (riskRegister.isNotEmpty) {
      for (var risk in riskRegister) {
        allRisks.add({
          'type': 'Risk',
          'description': risk.riskName,
          'impact': risk.impactLevel,
          'likelihood': 'Medium',
          'mitigation': risk.mitigationStrategy,
        });
      }
    } else {
      for (var solutionRisk in data!.solutionRisks) {
        for (var riskStr in solutionRisk.risks) {
          allRisks.add({
            'type': 'Risk',
            'description': riskStr,
            'impact': 'Medium',
            'likelihood': 'Medium',
            'mitigation': 'TBD',
          });
        }
      }
    }

    allRisks.sort((a, b) {
      final scoreA = _impactScore(a['impact']);
      final scoreB = _impactScore(b['impact']);
      return scoreB.compareTo(scoreA);
    });

    final displayRisks = allRisks.take(5).toList();
    final totalRisksCount = allRisks.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: kCardBorderDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 20,
                color: BrandColors.error,
              ),
              const SizedBox(width: 8),
              const Text(
                'Key Risks',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: BrandColors.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: BrandColors.errorContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$totalRisksCount Total',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: BrandColors.onErrorContainer,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              // AI Generate button removed per user request — Key Risks
              // reflect the risk register maintained on the dedicated Risks
              // page; the charter is a reflection, not a generator.
            ],
          ),
          const SizedBox(height: 20),

          // Risk items with border-left severity
          if (allRisks.isEmpty)
            const Text(
              'No risks identified.',
              style: TextStyle(
                color: BrandColors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Column(
              children: displayRisks.map((item) {
                final impact = item['impact'].toString();
                final Color borderColor;
                final Color badgeBg;
                final Color badgeText;
                if (impact.toLowerCase() == 'high') {
                  borderColor = BrandColors.error;
                  badgeBg = BrandColors.errorContainer;
                  badgeText = BrandColors.onErrorContainer;
                } else if (impact.toLowerCase() == 'medium') {
                  borderColor = BrandColors.tertiaryFixedDim;
                  badgeBg = BrandColors.tertiaryFixed;
                  badgeText = BrandColors.onTertiaryFixedVariant;
                } else {
                  borderColor = const Color(0xFF4ADE80);
                  badgeBg = const Color(0xFFDCFCE7);
                  badgeText = const Color(0xFF166534);
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(color: borderColor, width: 4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        offset: const Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['description'],
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: BrandColors.onSurface,
                              ),
                            ),
                            if (item['mitigation'] != null &&
                                item['mitigation'].toString().isNotEmpty &&
                                item['mitigation'].toString() != 'TBD')
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Mitigation: ${item['mitigation']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: BrandColors.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          impact,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: badgeText,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

          // Constraints
          if (data!.constraints.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(color: BrandColors.outlineVariant),
            const SizedBox(height: 16),
            labelStyle('Project Constraints'),
            const SizedBox(height: 8),
            ...data!.constraints
                .take(5)
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(
                            color: BrandColors.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            c,
                            style: const TextStyle(
                              fontSize: 13,
                              color: BrandColors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  int _impactScore(String impact) {
    switch (impact.toLowerCase()) {
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 0;
    }
  }
}

// ─── 6. Technical & Procurement Bento ───

class CharterTechnicalProcurementBento extends StatelessWidget {
  final ProjectDataModel? data;
  final VoidCallback? onGenerate;

  /// When provided, shows a "View / Edit Source" button that takes the
  /// user back to the Business Case section (read-only after the
  /// preferred solution is locked).
  final VoidCallback? onEdit;

  const CharterTechnicalProcurementBento({
    super.key,
    required this.data,
    this.onGenerate,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (data == null) return const SizedBox();

    final it = data!.itConsiderationsData;
    final infra = data!.infrastructureConsiderationsData;
    final vendorCount = data!.vendors.length;
    final contractCount = data!.contractors.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            sectionTitleWithIcon(
              Icons.precision_manufacturing_outlined,
              'Technical & Procurement',
            ),
            // AI Generate removed per user request — IT considerations and
            // Infrastructure come from the preferred solution (Business Case
            // section, which is locked once the preferred solution is selected).
            if (onEdit != null)
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text(
                  'View / Edit Source',
                  style: TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 768;
            return isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // IT + Infrastructure card
                      Expanded(child: _buildTechCard(it, infra)),
                      const SizedBox(width: 12),
                      // Contracts + Procurement side by side
                      Expanded(
                        child: Column(
                          children: [
                            _buildStatCard(
                              'Contracts',
                              contractCount,
                              'Contracts Pending',
                              Icons.description_outlined,
                              BrandColors.primary,
                              BrandColors.primaryFixed,
                            ),
                            const SizedBox(height: 12),
                            _buildStatCard(
                              'Procurement',
                              vendorCount,
                              'Items Identified',
                              Icons.inventory_2_outlined,
                              BrandColors.tertiary,
                              BrandColors.tertiaryFixed,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildTechCard(it, infra),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Contracts',
                              contractCount,
                              'Contracts Pending',
                              Icons.description_outlined,
                              BrandColors.primary,
                              BrandColors.primaryFixed,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Procurement',
                              vendorCount,
                              'Items Identified',
                              Icons.inventory_2_outlined,
                              BrandColors.tertiary,
                              BrandColors.tertiaryFixed,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
          },
        ),
      ],
    );
  }

  Widget _buildTechCard(
    ITConsiderationsData? it,
    InfrastructureConsiderationsData? infra,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: kCardBorderDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          labelStyle('IT Considerations'),
          const SizedBox(height: 8),
          if (it == null ||
              (it.hardwareRequirements.isEmpty &&
                  it.softwareRequirements.isEmpty &&
                  it.networkRequirements.isEmpty))
            const Text(
              'No specific requirements defined.',
              style: TextStyle(
                color: BrandColors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
            )
          else ...[
            if (it.hardwareRequirements.isNotEmpty)
              _buildReqRow('Hardware', it.hardwareRequirements),
            if (it.softwareRequirements.isNotEmpty)
              _buildReqRow('Software', it.softwareRequirements),
            if (it.networkRequirements.isNotEmpty)
              _buildReqRow('Network', it.networkRequirements),
          ],
          const SizedBox(height: 16),
          const Divider(color: BrandColors.outlineVariant),
          const SizedBox(height: 12),
          labelStyle('Infrastructure'),
          const SizedBox(height: 8),
          if (infra == null ||
              (infra.physicalSpaceRequirements.isEmpty &&
                  infra.powerCoolingRequirements.isEmpty &&
                  infra.connectivityRequirements.isEmpty))
            const Text(
              'No specific requirements defined.',
              style: TextStyle(
                color: BrandColors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
            )
          else ...[
            if (infra.physicalSpaceRequirements.isNotEmpty)
              _buildReqRow('Space', infra.physicalSpaceRequirements),
            if (infra.powerCoolingRequirements.isNotEmpty)
              _buildReqRow('Power/Cooling', infra.powerCoolingRequirements),
            if (infra.connectivityRequirements.isNotEmpty)
              _buildReqRow('Connectivity', infra.connectivityRequirements),
          ],
        ],
      ),
    );
  }

  Widget _buildReqRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: BrandColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    int count,
    String subtitle,
    IconData icon,
    Color accentColor,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: kCardBorderDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accentColor.withOpacity(0.8),
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

// ─── 7. Tentative Schedule Timeline ───

class CharterScheduleTimeline extends StatelessWidget {
  final ProjectDataModel? data;

  const CharterScheduleTimeline({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data == null) return const SizedBox();

    final milestones = data!.keyMilestones
        .where((m) => m.dueDate.isNotEmpty)
        .toList();
    if (milestones.isEmpty) return const SizedBox();

    // Sort by date
    milestones.sort((a, b) {
      final da = DateTime.tryParse(a.dueDate) ?? DateTime.now();
      final db = DateTime.tryParse(b.dueDate) ?? DateTime.now();
      return da.compareTo(db);
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: kCardBorderDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitleWithIcon(Icons.schedule_outlined, 'Tentative Schedule'),
          const SizedBox(height: 24),
          // Timeline
          ...milestones.asMap().entries.map((entry) {
            final index = entry.key;
            final m = entry.value;
            final mDate = DateTime.tryParse(m.dueDate);
            final isCompleted = mDate != null && mDate.isBefore(DateTime.now());
            final isLast = index == milestones.length - 1;

            return _TimelineItem(
              name: m.name,
              description: m.discipline.isNotEmpty ? m.discipline : '',
              date: mDate != null
                  ? DateFormat('MMM d, yyyy').format(mDate)
                  : 'TBD',
              isCompleted: isCompleted,
              isLast: isLast,
            );
          }),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String name;
  final String description;
  final String date;
  final bool isCompleted;
  final bool isLast;

  const _TimelineItem({
    required this.name,
    required this.description,
    required this.date,
    required this.isCompleted,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // Dot
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isCompleted ? BrandColors.primary : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCompleted
                          ? BrandColors.primary
                          : BrandColors.outline,
                      width: 2,
                    ),
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, size: 10, color: Colors.white)
                      : null,
                ),
                // Line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: BrandColors.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isCompleted
                          ? BrandColors.onSurface
                          : BrandColors.onSurfaceVariant,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: BrandColors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 12,
                      color: BrandColors.outline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 8. Floating Approval Action Bar ───

class CharterFloatingApprovalBar extends StatefulWidget {
  final ProjectDataModel? data;

  const CharterFloatingApprovalBar({super.key, required this.data});

  @override
  State<CharterFloatingApprovalBar> createState() =>
      _CharterFloatingApprovalBarState();
}

class _CharterFloatingApprovalBarState
    extends State<CharterFloatingApprovalBar> {
  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    // Determine signer info
    String signerName = data?.charterProjectSponsorName ?? '';
    String signerRole = 'Project Sponsor';
    if (signerName.isEmpty) {
      signerName = data?.charterProjectManagerName ?? '';
      signerRole = 'Project Owner';
    }
    if (signerName.isEmpty) {
      signerName = 'Pending Assignment';
    }
    final isApproved =
        data?.charterApprovalDate != null ||
        (data?.frontEndPlanning.charterApproved ?? false);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: BrandColors.inverseSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            offset: const Offset(0, -4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              if (isMobile) {
                return Column(
                  children: [
                    _buildApprovalInfo(signerName, signerRole, isApproved),
                    const SizedBox(height: 12),
                    _buildApproveButton(context, signerName, isApproved),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildApprovalInfo(signerName, signerRole, isApproved),
                  _buildApproveButton(context, signerName, isApproved),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildApprovalInfo(
    String signerName,
    String signerRole,
    bool isApproved,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.gavel_outlined, size: 18, color: Colors.white70),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Approval Authority: $signerName ($signerRole) — Charter to be approved by sponsor, owner or applicable lead',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isApproved) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'APPROVED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildApproveButton(
    BuildContext context,
    String signerName,
    bool isApproved,
  ) {
    if (isApproved) return const SizedBox();

    return InkWell(
      onTap: () => _showApprovalConfirmationDialog(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [BrandColors.primary, BrandColors.primaryContainer],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: BrandColors.primary.withOpacity(0.3),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Click to Approve',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showApprovalConfirmationDialog() async {
    final data = widget.data;
    if (data == null) return;
    if ((data.charterProjectSponsorName.isEmpty) &&
        (data.charterProjectManagerName.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Assign a sponsor or project owner before approval. Use the sponsor suggestion banner in the Governance section.',
          ),
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
      return;
    }
    if (data.charterApprovalRequestedAt == null ||
        data.charterApprovalRequestedToEmail.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Send the charter review request from the Governance section before approving.',
          ),
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
      return;
    }

    bool smeReviewed = data.frontEndPlanning.charterFepSmeReviewConfirmed;
    bool sponsorConfirmed = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.gavel_outlined,
                color: BrandColors.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              const Text('Confirm Charter Approval'),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Charter to be approved by sponsor, owner or applicable lead. Confirm.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 14),
                CheckboxListTile(
                  value: smeReviewed,
                  onChanged: (v) =>
                      setDialogState(() => smeReviewed = v ?? false),
                  title: const Text(
                    'I confirm the applicable subject matter experts have reviewed all relevant sections of the Front End Execution Plan.',
                    style: TextStyle(fontSize: 12),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                CheckboxListTile(
                  value: sponsorConfirmed,
                  onChanged: (v) =>
                      setDialogState(() => sponsorConfirmed = v ?? false),
                  title: const Text(
                    'I am the project sponsor, owner, or applicable lead and I am authorized to approve this charter.',
                    style: TextStyle(fontSize: 12),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Once approved, the Front End Planning sections will be locked and the Planning phase will be unlocked.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFD97706),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (smeReviewed && sponsorConfirmed)
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm & Approve'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _approveCharter();
    }
  }

  Future<void> _approveCharter() async {
    final provider = ProjectDataInherited.maybeOf(context);
    if (provider == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to find project context.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    provider.updateField(
      (data) => data.copyWith(
        charterApprovalDate: DateTime.now(),
        frontEndPlanning: data.frontEndPlanning.copyWith(
          charterApproved: true,
          charterApprovedAt: DateTime.now(),
          charterFepSmeReviewConfirmed: true,
          charterFepSmeReviewConfirmedAt: DateTime.now(),
        ),
      ),
    );

    // Retry cloud sync up to 3 times to avoid the "Approval saved
    // locally, but cloud sync failed" message.
    bool success = false;
    String? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        success = await provider.saveToFirebase(checkpoint: 'project_charter');
        if (success) break;
      } catch (e) {
        lastError = e.toString();
      }
      await Future.delayed(const Duration(milliseconds: 800));
    }

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Project charter approved. Front End Planning is now locked and the Planning phase is unlocked.',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Approval saved locally but cloud sync failed after 3 retries. Please check your network connection and tap Approve again to retry. Error: $lastError',
          ),
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
    }
  }
}

// ─── Legacy// ─── Legacy/Kept widgets for compatibility ───

class CharterExecutiveSnapshot extends StatelessWidget {
  final ProjectDataModel? data;
  const CharterExecutiveSnapshot({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return CharterDashboardStats(data: data);
  }
}

class CharterExecutiveSummary extends StatelessWidget {
  final ProjectDataModel? data;
  const CharterExecutiveSummary({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CharterHeroHeader(data: data),
        const SizedBox(height: 16),
        CharterMetaInfoScroll(data: data),
      ],
    );
  }
}

class CharterFinancialSnapshot extends StatelessWidget {
  final ProjectDataModel? data;
  const CharterFinancialSnapshot({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return CharterFinancialOverview(data: data);
  }
}

class CharterMilestoneVisualizer extends StatelessWidget {
  final ProjectDataModel? data;
  const CharterMilestoneVisualizer({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return CharterScheduleTimeline(data: data);
  }
}

class CharterScheduleTable extends StatelessWidget {
  final ProjectDataModel? data;
  const CharterScheduleTable({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return CharterScheduleTimeline(data: data);
  }
}

class CharterCostChart extends StatelessWidget {
  final ProjectDataModel? data;
  const CharterCostChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}

class CharterResources extends StatelessWidget {
  final ProjectDataModel? data;
  const CharterResources({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}

class CharterTechnicalEnvironment extends StatelessWidget {
  final ProjectDataModel? data;
  final VoidCallback? onGenerate;

  const CharterTechnicalEnvironment({
    super.key,
    required this.data,
    this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return CharterTechnicalProcurementBento(data: data, onGenerate: onGenerate);
  }
}

class CharterStakeholders extends StatelessWidget {
  final ProjectDataModel? data;
  const CharterStakeholders({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}

// ─── Assumptions (Collapsible) ───

class CharterAssumptions extends StatefulWidget {
  final ProjectDataModel? data;
  const CharterAssumptions({super.key, required this.data});

  @override
  State<CharterAssumptions> createState() => _CharterAssumptionsState();
}

class _CharterAssumptionsState extends State<CharterAssumptions> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.data == null) return const SizedBox();

    final assumptions = widget.data!.assumptions
        .where((a) => a.trim().isNotEmpty)
        .toList();
    final constraints = widget.data!.constraints
        .where((c) => c.trim().isNotEmpty)
        .toList();

    if (assumptions.isEmpty && constraints.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: kCardBorderDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  size: 20,
                  color: BrandColors.tertiaryFixedDim,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Assumptions & Constraints',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: BrandColors.onSurface,
                  ),
                ),
                const Spacer(),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: BrandColors.onSurfaceVariant,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 16),
            if (assumptions.isNotEmpty) ...[
              labelStyle('Assumptions'),
              const SizedBox(height: 8),
              ...assumptions
                  .take(5)
                  .map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(
                              fontSize: 12,
                              color: BrandColors.onSurfaceVariant,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              a,
                              style: const TextStyle(
                                fontSize: 13,
                                color: BrandColors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
            if (constraints.isNotEmpty) ...[
              const SizedBox(height: 16),
              labelStyle('Constraints'),
              const SizedBox(height: 8),
              ...constraints
                  .take(5)
                  .map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(
                              fontSize: 12,
                              color: BrandColors.onSurfaceVariant,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              c,
                              style: const TextStyle(
                                fontSize: 13,
                                color: BrandColors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Beautiful visual walkthrough shown when no Project Manager is assigned.
class AssignManagerWalkthrough extends StatefulWidget {
  final VoidCallback onAssignTapped;
  const AssignManagerWalkthrough({super.key, required this.onAssignTapped});

  @override
  State<AssignManagerWalkthrough> createState() =>
      _AssignManagerWalkthroughState();
}

class _AssignManagerWalkthroughState extends State<AssignManagerWalkthrough>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bobController;

  @override
  void initState() {
    super.initState();
    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF8E1), Color(0xFFFFE8A3)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF5C518), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFFFC812),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_add_alt_1,
              color: Colors.black,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Assign your Project Manager',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Required',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Before you can move forward in the Project Charter, you need to assign a Project Manager. Here\'s how:',
                  style: TextStyle(fontSize: 13, color: Color(0xFF5B4300)),
                ),
                const SizedBox(height: 12),
                _walkthroughStep(
                  1,
                  'Tap the "PROJECT MANAGER" card below',
                  Icons.touch_app_outlined,
                ),
                _walkthroughStep(
                  2,
                  'Enter the manager\'s name in the dialog',
                  Icons.edit_outlined,
                ),
                _walkthroughStep(
                  3,
                  'Click "Assign" — you\'re all set!',
                  Icons.check_circle_outline,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: widget.onAssignTapped,
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text('Assign Manager Now'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC812),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _bobController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _bobController.value * 6 - 3),
                child: child,
              );
            },
            child: const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(Icons.south, color: Color(0xFFB45309), size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _walkthroughStep(int n, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Color(0xFFB45309),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$n',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 16, color: const Color(0xFF5B4300)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
            ),
          ),
        ],
      ),
    );
  }
}
