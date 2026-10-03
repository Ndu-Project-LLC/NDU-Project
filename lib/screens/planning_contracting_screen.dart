import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/ai_suggesting_textfield.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/services/contract_service.dart';
import 'package:ndu_project/services/planning_contracting_service.dart';
import 'package:ndu_project/services/procurement_service.dart';
import 'package:ndu_project/models/contract_log.dart';
import 'package:ndu_project/models/design_phase_models.dart' show RequirementRow;
import 'package:ndu_project/services/design_phase_service.dart';
import 'package:ndu_project/models/contract_rfp_cycle.dart';
import 'package:ndu_project/models/planning_contracting_models.dart';
import 'package:ndu_project/models/procurement/procurement_models.dart'
    as procurement_models;
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/widgets/responsive_table_widgets.dart';
import 'package:ndu_project/widgets/searchable_table_section.dart';
import 'package:ndu_project/widgets/wrapped_table_primitives.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/widgets/spell_check/spell_checking_text_controller.dart';

const Color _kBrandYellow = Color(0xFFFFC812);
const Color _kFabYellow = Color(0xFFFBBF24);
const Color _kFabOnYellow = Color(0xFF111827);

String _formatCurrency(double value) {
 final rounded = value.round();
 final text = rounded.toString();
 return text.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
}

class _PlanningScopeOption {
 const _PlanningScopeOption({
 required this.id,
 required this.label,
 this.type = 'Scope',
 this.value = 0,
 this.status = 'Identified',
 });

 final String id;
 final String label;
 final String type;
 final double value;
 final String status;
}

List<_PlanningScopeOption> _planningScopeOptionsFromData(ProjectDataModel data) {
 final options = <_PlanningScopeOption>[];
 final seen = <String>{};

 for (final item in data.withinScopeItems) {
 final label = item.title.trim().isNotEmpty
 ? item.title.trim()
 : item.description.trim();
 final description = item.description.trim();
 if (label.isEmpty && description.isEmpty) continue;
 final id = item.id.trim().isNotEmpty
 ? item.id.trim()
 : label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
 if (!seen.add(id)) continue;
 options.add(_PlanningScopeOption(
 id: id,
 label: label.isNotEmpty ? label : description,
 type: 'Within Scope',
 status: 'Identified',
 ));
 }

 for (final contractor in data.contractors) {
 final name = contractor.service.trim().isNotEmpty
 ? contractor.service.trim()
 : contractor.name.trim();
 if (name.isEmpty) continue;
 final id =
 'contractor_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
 if (!seen.add(id)) continue;
 options.add(_PlanningScopeOption(
 id: id,
 label: name,
 type: 'Contractor Scope',
 value: contractor.estimatedCost,
 status: contractor.status.trim().isNotEmpty
 ? contractor.status.trim()
 : 'Imported',
 ));
 }

 return options;
}

class PlanningContractingScreen extends StatefulWidget {
 const PlanningContractingScreen({super.key});

 static void open(BuildContext context) {
 context.push('/fep-contracts');
 }

 @override
 State<PlanningContractingScreen> createState() =>
 _PlanningContractingScreenState();
}

/// One entry in the contracting tab strip.
class _ContractTabDef {
  const _ContractTabDef(this.label, this.builder);

  final String label;
  final Widget Function() builder;
}

/// Lusaka 27: "Can you click on any one of these instead of negotiation? …
/// please just hide it. Just hide it fully, don't delete it, just hide it."
///
/// The Negotiation planner stays in the codebase (and in the route table) but
/// is left out of the strip. Flip this to `true` to bring the tab back.
bool get _showNegotiationTab => false;

class _PlanningContractingScreenState extends State<PlanningContractingScreen> {
  int _selectedTab = 0;

  /// The tabs, in order. The old "Packages" tab is now the Contracts tab: it
  /// carries the contract log as its default view — "that table needs to be
  /// here. As a default view … This is where they have to go through the
  /// process of building it out" — with the package cards as the secondary
  /// view.
  List<_ContractTabDef> get _tabs => <_ContractTabDef>[
        _ContractTabDef(
          'Overview',
          () => _OverviewTab(
            onOpenContractLog: () => setState(() => _selectedTab = 1),
          ),
        ),
        const _ContractTabDef('Contracts', _ContractsTab.new),
        const _ContractTabDef('Tender Setup', _TenderSetupTab.new),
        const _ContractTabDef('Evaluation', _EvaluationTab.new),
        if (_showNegotiationTab)
          const _ContractTabDef('Negotiation', _NegotiationTab.new),
        const _ContractTabDef('Admin Controls', _AdminTab.new),
        const _ContractTabDef('Commercial & Forecast', _CommercialForecastTab.new),
        const _ContractTabDef('Handoff', _HandoffTab.new),
      ];


 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 final hPad = isMobile ? 20.0 : 40.0;

 return Scaffold(
 backgroundColor: Theme.of(context).scaffoldBackgroundColor,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Contract Planning',
 ),
 ),
 Expanded(
 child: Stack(
 children: [
 Column(
 children: [
 Expanded(
 child: SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: hPad, vertical: isMobile ? 20 : 36),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(title: 'Contracting', onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 _BuildHeader(
 onBack: () => PlanningPhaseNavigation.goToPrevious(context, 'contracts'),
 onForward: () => PlanningPhaseNavigation.goToNext(context, 'contracts'),
 onProcurement: _openProcurement,
 ),
 SizedBox(height: isMobile ? 18 : 28),
 _TabBar(
 labels: _tabs.map((tab) => tab.label).toList(),
 selectedIndex: _selectedTab,
 onSelected: (i) => setState(() => _selectedTab = i),
 ),
 SizedBox(height: isMobile ? 18 : 28),
 _buildTabContent(),
 SizedBox(height: isMobile ? 60 : 100),
 ],
 ),
 ),
 ),
 ],
 ),
 const MobileSidebarHamburger(
 sidebar: InitiationLikeSidebar(
 activeItemLabel: 'Contract Planning',
 ),
 ),
 const KazAiChatBubble(),
 const AdminEditToggle(),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }  Widget _buildTabContent() {
    final tabs = _tabs;
    if (_selectedTab < 0 || _selectedTab >= tabs.length) {
      return const SizedBox.shrink();
    }
    return tabs[_selectedTab].builder();
  }

 void _openProcurement() {
 context.push('/planning-procurement');
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 // The Contract Log itself, so the export shows the table the owner was
 // looking at instead of exporting nothing (Lusaka 27). The rows come from
 // the same model the on-screen log draws, so the two cannot drift.
 final projectId = projectData.projectId?.trim() ?? '';
 var contracts = const <ContractModel>[];
 if (projectId.isNotEmpty) {
 try {
 contracts = await ContractService.streamContracts(projectId).first;
 } catch (_) {
 // Nothing readable: export the rest rather than failing the export.
 contracts = const <ContractModel>[];
 }
 }
 if (!mounted) return;
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Planning Contracting',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName.isEmpty ? 'N/A' : projectData.projectName},
 {'Solution Title': projectData.solutionTitle.isEmpty ? 'N/A' : projectData.solutionTitle},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_contracting_notes'] ?? 'No data recorded.'),
 if (contracts.isNotEmpty)
 PdfSection.table(
 'Contract Log',
 headers: contractLogExportHeaders(),
 rows: contractLogExportRows(contracts),
 ),
 ],
 );
 }
}

class _BuildHeader extends StatelessWidget {
 const _BuildHeader({required this.onBack, required this.onForward, required this.onProcurement});
 final VoidCallback onBack;
 final VoidCallback onForward;
 final VoidCallback onProcurement;

 @override
 Widget build(BuildContext context) {
 return Row(
 children: [
 _CircleBtn(icon: Icons.arrow_back_ios_new, onTap: onBack),
 const SizedBox(width: 10),
 _CircleBtn(icon: Icons.arrow_forward_ios, onTap: onForward),
 const SizedBox(width: 20),
 const Text('Contract Planning',
 style: TextStyle(
 fontSize: 26,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827))),
 const Spacer(),
 const SizedBox(width: 8),
 ElevatedButton.icon(
 onPressed: onProcurement,
 icon: const Icon(Icons.inventory_2_outlined, size: 16),
 label: const Text('Procurement',
 style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
 style: ElevatedButton.styleFrom(
 backgroundColor: _kBrandYellow,
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 elevation: 0,
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ],
 );
 }
}

class _CircleBtn extends StatelessWidget {
 const _CircleBtn({required this.icon, this.onTap});
 final IconData icon;
 final VoidCallback? onTap;

 @override
 Widget build(BuildContext context) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(22),
 child: Container(
 width: 40,
 height: 40,
 decoration: BoxDecoration(
 color: Colors.white,
 shape: BoxShape.circle,
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Icon(icon, size: 16, color: const Color(0xFF374151)),
 ),
 );
 }
}

class _TabBar extends StatelessWidget {
 const _TabBar({
 required this.labels,
 required this.selectedIndex,
 required this.onSelected,
 });
 final List<String> labels;
 final int selectedIndex;
 final ValueChanged<int> onSelected;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(5),
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: LayoutBuilder(
 builder: (context, constraints) {
 final isCompact = constraints.maxWidth < labels.length * 130;
 if (isCompact) {
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: Row(
 children: List.generate(labels.length, (i) {
 final isSelected = i == selectedIndex;
 return Padding(
 padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 4),
 child: _TabPill(
 label: labels[i],
 selected: isSelected,
 onTap: () => onSelected(i),
 ),
 );
 }),
 ),
 );
 }

 return Wrap(
 spacing: 4,
 runSpacing: 4,
 children: List.generate(labels.length, (i) {
 final isSelected = i == selectedIndex;
 return _TabPill(
 label: labels[i],
 selected: isSelected,
 onTap: () => onSelected(i),
 );
 }),
 );
 },
 ),
 );
 }
}

class _TabPill extends StatelessWidget {
 const _TabPill(
 {required this.label, required this.selected, required this.onTap});
 final String label;
 final bool selected;
 final VoidCallback onTap;

 @override
 Widget build(BuildContext context) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(10),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
 decoration: BoxDecoration(
 color: selected ? _kBrandYellow : Colors.transparent,
 borderRadius: BorderRadius.circular(10),
 ),
 child: Text(
 label,
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: selected ? Colors.white : const Color(0xFF374151),
 ),
 ),
 ),
 );
 }
}

class _SectionCard extends StatelessWidget {
 const _SectionCard({
 required this.title,
 required this.child,
 this.subtitle,
 this.trailing,
 });
 final String title;
 final String? subtitle;
 final Widget child;
 final Widget? trailing;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(22),
 margin: const EdgeInsets.only(bottom: 20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0A0F172A), blurRadius: 16, offset: Offset(0, 8)),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(title,
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827))),
 if (subtitle != null) ...[
 const SizedBox(height: 4),
 Text(subtitle!,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF6B7280))),
 ],
 ],
 ),
 ),
 if (trailing != null) trailing!,
 ],
 ),
 const SizedBox(height: 18),
 child,
 ],
 ),
 );
 }
}

class _StatCard extends StatelessWidget {
 const _StatCard({
 required this.value,
 required this.label,
 required this.color,
 this.supporting = '',
 });
 final String value;
 final String label;
 final Color color;
 final String supporting;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(value,
 style: TextStyle(
 fontSize: 20, fontWeight: FontWeight.w700, color: color)),
 const SizedBox(height: 4),
 Text(label,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFF6B7280))),
 if (supporting.isNotEmpty)
 Text(supporting,
 style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
 ],
 ),
 );
 }
}

class _EmptyPanel extends StatelessWidget {
 const _EmptyPanel(this.message);
 final String message;

 @override
 Widget build(BuildContext context) {
 return Center(
 child: Padding(
 padding: const EdgeInsets.symmetric(vertical: 32),
 child: Text(message,
 style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
 ),
 );
 }
}

class _StatusChip extends StatelessWidget {
 const _StatusChip({required this.label, required this.color});
 final String label;
 final Color color;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: color.withValues(alpha: 0.12),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: color.withValues(alpha: 0.26)),
 ),
 child: Text(label,
 style: TextStyle(
 fontSize: 11, fontWeight: FontWeight.w600, color: color)),
 );
 }
}

// ─── OVERVIEW TAB ────────────────────────────────────────────────────────────

class _OverviewTab extends StatefulWidget {
  const _OverviewTab({this.onOpenContractLog});

  /// Jumps to the Contracts tab, where the log and the per-contract strategy
  /// live. Null when the overview is rendered outside the tab strip.
  final VoidCallback? onOpenContractLog;

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  static const _tabNoteKey = 'planning_contract_plan';

  @override
  Widget build(BuildContext context) {
    final projectData = ProjectDataHelper.getData(context);
    final projectId = projectData.projectId;

    return StreamBuilder<List<ContractModel>>(
      stream: projectId != null && projectId.isNotEmpty
          ? ContractService.streamContracts(projectId)
          : Stream.value(const []),
      builder: (context, snap) {
        final contracts = snap.data ?? const [];
        final totalValue =
            contracts.fold<double>(0.0, (t, c) => t + c.estimatedValue);
        final withoutCycle =
            contracts.where((c) => c.rfpCycle == null).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatCard(
                  value: contracts.length.toString(),
                  label: 'Contracts',
                  color: _kBrandYellow,
                  supporting: 'Pre-award list'),
                _StatCard(
                  value: contracts.isEmpty
                      ? 'TBD'
                      : '\$${_formatCurrency(totalValue)}',
                  label: 'Total Estimated',
                  color: const Color(0xFF059669),
                  supporting: 'Budget alignment'),
                _StatCard(
                  value: strategySummaryLabel(contracts),
                  label: 'Award Strategies',
                  color: const Color(0xFFF59E0B),
                  supporting: 'Set per contract'),
                _StatCard(
                  value: contracts.isEmpty
                      ? 'TBD'
                      : (withoutCycle == 0
                          ? 'All set'
                          : '$withoutCycle to set'),
                  label: 'RFP Cycles',
                  color: const Color(0xFFB8860B),
                  supporting: 'Set per contract'),
              ],
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Contract Strategy',
              subtitle:
                  'The award strategy, contract type and RFP cycle are set on each '
                  'contract, not for the project as a whole.',
              trailing: widget.onOpenContractLog == null
                  ? null
                  : TextButton.icon(
                      onPressed: widget.onOpenContractLog,
                      icon: const Icon(Icons.table_chart_outlined, size: 16),
                      label: const Text('Open the contract log'),
                      style: TextButton.styleFrom(
                          foregroundColor: _kBrandYellow),
                    ),
              child: _ContractStrategySummary(contracts: contracts),
            ),
            _SectionCard(
 title: 'Contract Planning Narrative',
 subtitle:
 'AI drafts the planning narrative using initiation inputs and planning context. Edit it to match your package strategy.',
 child: AiSuggestingTextField(
 fieldLabel: 'Contract Planning Narrative',
 hintText:
 'Outline package strategy, delivery model, commercial terms, evaluation approach, milestones, vendor roles, and approval gates.',
 sectionLabel: 'Contract Planning Narrative',
 autoGenerate: true,
 autoGenerateSection: 'Contract Planning Narrative',
 initialText: projectData.planningNotes[_tabNoteKey],
 onChanged: (value) async {
 final trimmed = value.trim();
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'contracts',
 dataUpdater: (data) => data.copyWith(
 planningNotes: {...data.planningNotes, _tabNoteKey: trimmed},
 ),
 showSnackbar: false,
 );
 },
 onAutoGenerated: (value) async {
 final trimmed = value.trim();
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'contracts',
 dataUpdater: (data) => data.copyWith(
 planningNotes: {...data.planningNotes, _tabNoteKey: trimmed},
 ),
 showSnackbar: false,
 );
 },
 ),
 ),            const _SectionCard(
              title: 'Approval Gates',
              subtitle:
                  'Every contract must complete PM review before sponsor approval and handoff.',
              child: _ApprovalGateSummary(),
            ),
            const SizedBox(height: 60),
          ],
        );
      },
    );
  }
}

/// The per-contract strategies at a glance: what each contract is going to
/// market with, and whether its RFP cycle is set yet. Read-only — the values are
/// edited on the contract itself (Lusaka 27: "the contract price is going to be
/// by contract basis … we can't have one story for the entire project").
class _ContractStrategySummary extends StatelessWidget {
  const _ContractStrategySummary({required this.contracts});

  final List<ContractModel> contracts;

  @override
  Widget build(BuildContext context) {
    if (contracts.isEmpty) {
      return const _EmptyPanel(
          'No contracts yet. Add a contract to set its strategy and RFP cycle.');
    }
    return Column(
      children: [
        for (final contract in contracts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(contract.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                      (contract.awardStrategy ?? '').trim().isEmpty
                          ? 'Not set'
                          : contract.awardStrategy!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF4B5563))),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                      contract.contractType.trim().isEmpty
                          ? 'Not set'
                          : contract.contractType,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF4B5563))),
                ),
                Expanded(
                  flex: 4,
                  child: _StatusChip(
                    label: contract.rfpCycle == null
                        ? 'RFP cycle not set'
                        : contract.rfpCycle!.summary,
                    color: contract.rfpCycle == null
                        ? const Color(0xFF64748B)
                        : _kBrandYellow,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// `2 in use` / `Not set` — how many distinct award strategies the contracts
/// use, for the overview stat card.
String strategySummaryLabel(List<ContractModel> contracts) {
  final strategies = contracts
      .map((c) => (c.awardStrategy ?? '').trim())
      .where((s) => s.isNotEmpty && s != 'Not Sure')
      .toSet();
  if (strategies.isEmpty) return 'Not set';
  return '${strategies.length} in use';
}

class _ApprovalGateSummary extends StatelessWidget {
 const _ApprovalGateSummary();

 @override
 Widget build(BuildContext context) {
 return const Wrap(
 spacing: 12,
 runSpacing: 12,
 children: [
 _InlineInfoCard(
 title: 'PM Review',
 detail: 'Required for every package before sponsor approval.',
 color: _kBrandYellow,
 ),
 _InlineInfoCard(
 title: 'Sponsor Approval',
 detail: 'Required for every package before execution handoff.',
 color: Color(0xFFB8860B),
 ),
 _InlineInfoCard(
 title: 'Schedule Sync',
 detail: 'Approved milestones should create schedule entries automatically.',
 color: Color(0xFF059669),
 ),
 ],
 );
 }
}

class _InlineInfoCard extends StatelessWidget {
 const _InlineInfoCard({
 required this.title,
 required this.detail,
 required this.color,
 });

 final String title;
 final String detail;
 final Color color;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: 260,
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: color.withValues(alpha: 0.08),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: color.withValues(alpha: 0.22)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(title,
 style: TextStyle(
 fontSize: 13, fontWeight: FontWeight.w700, color: color)),
 const SizedBox(height: 6),
 Text(detail,
 style:
 const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
 ],
 ),
 );
 }
}class _PackagePlanningCard extends StatelessWidget {
 const _PackagePlanningCard({required this.contract});
 final ContractModel contract;

 @override
 Widget build(BuildContext context) {
 return Container(
 margin: const EdgeInsets.only(bottom: 14),
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(contract.name,
 style: const TextStyle(
 fontSize: 14, fontWeight: FontWeight.w700)),
 const SizedBox(height: 4),
 Text(
 contract.packageSummary?.isNotEmpty == true
 ? contract.packageSummary!
 : (contract.description.isNotEmpty
 ? contract.description
 : 'No package summary yet.'),
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 TextButton.icon(
 onPressed: () => _showEditPackageDialog(context, contract),
 icon: const Icon(Icons.edit_outlined, size: 16),
 label: const Text('Edit Package'),
 style:
 TextButton.styleFrom(foregroundColor: _kBrandYellow),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Wrap(
 spacing: 10,
 runSpacing: 10,
 children: [
 _PackageMetricChip(
 label: 'FEP Scope',
 value: contract.linkedFepScopeId ?? 'Not linked',
 ),
 _PackageMetricChip(
 label: 'Engineer Estimate',
 value: contract.engineerEstimate != null
 ? '\$${_formatCurrency(contract.engineerEstimate!)}'
 : 'TBD',
 ),
 _PackageMetricChip(
 label: 'Target Award',
 value: _formatDateLabel(contract.targetAwardDate),
 ),
 _PackageMetricChip(
 label: 'Execution Start',
 value: _formatDateLabel(contract.plannedExecutionStart),
 ),
 _PackageMetricChip(
 label: 'Award Strategy',
 value: contract.awardStrategy ?? 'Not set',
 ),
 _PackageMetricChip(
 label: 'Contract Type',
 value: contract.contractType.isNotEmpty
 ? contract.contractType
 : 'Not set',
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: Text('\$${_formatCurrency(contract.estimatedValue)}',
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF059669))),
 ),
 _StatusChip(
 label: contract.status,
 color: _statusColor(contract.status),
 ),
 ],
 ),
 ],
 ),
 );
 }
}

class _PackageMetricChip extends StatelessWidget {
 const _PackageMetricChip({required this.label, required this.value});

 final String label;
 final String value;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: RichText(
 text: TextSpan(
 style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 children: [
 TextSpan(
 text: '$label: ',
 style: const TextStyle(fontWeight: FontWeight.w700),
 ),
 TextSpan(
 text: value,
 style: const TextStyle(color: Color(0xFF111827)),
 ),
 ],
 ),
 ),
 );
 }
}

String _formatDateLabel(DateTime? date) {
 if (date == null) return 'TBD';
 return DateFormat('MMM dd, yyyy').format(date);
}

String _scheduleMilestoneId(String contractId, String suffix) =>
 'cp_${contractId}_$suffix';

String _dateToScheduleText(DateTime date) =>
 DateTime(date.year, date.month, date.day).toIso8601String();

ScheduleActivity _buildContractPlanningMilestone({
 required String id,
 required String title,
 required DateTime date,
 List<String> predecessorIds = const [],
}) {
 return ScheduleActivity(
 id: id,
 wbsId: id,
 title: title,
 durationDays: 0,
 predecessorIds: predecessorIds,
 isMilestone: true,
 status: 'pending',
 priority: 'high',
 assignee: 'Contract Planning',
 discipline: 'Contract Planning',
 progress: 0,
 startDate: _dateToScheduleText(date),
 dueDate: _dateToScheduleText(date),
 estimatedHours: 0,
 milestone: title,
 );
}

Future<void> _upsertScheduleMilestoneActivity({
 required BuildContext context,
 required String milestoneId,
 required String title,
 required DateTime? date,
 List<String> predecessorIds = const [],
}) async {
 final data = ProjectDataHelper.getData(context);
 final activities = List<ScheduleActivity>.from(data.scheduleActivities);
 activities.removeWhere((activity) => activity.id == milestoneId);
 if (date != null) {
 activities.add(_buildContractPlanningMilestone(
 id: milestoneId,
 title: title,
 date: date,
 predecessorIds: predecessorIds,
 ));
 }

 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'contracts',
 dataUpdater: (project) => project.copyWith(scheduleActivities: activities),
 showSnackbar: false,
 );
}

List<String> _mergeMilestoneIds(
 List<String>? existing,
 Iterable<String> additions,
) {
 final merged = <String>{...(existing ?? const <String>[])};
 merged.addAll(additions.where((id) => id.trim().isNotEmpty));
 return merged.toList()..sort();
}

Color _statusColor(String status) {
 final s = status.toLowerCase();
 if (s.contains('award') || s.contains('complete') || s.contains('approved')) {
 return const Color(0xFF22C55E);
 }
 if (s.contains('behind') || s.contains('risk') || s.contains('blocked')) {
 return const Color(0xFFEF4444);
 }
 if (s.contains('review') ||
 s.contains('pending') ||
 s.contains('shortlist')) {
 return const Color(0xFFF59E0B);
 }
 if (s.contains('progress') ||
 s.contains('active') ||
 s.contains('identified')) {
 return _kBrandYellow;
 }
 return const Color(0xFF64748B);
}

void _showCreateContractDialog(BuildContext context, String? projectId) {
 if (projectId == null || projectId.isEmpty) return;
 final nameCtrl = SpellCheckTextEditingController();
 final descCtrl = SpellCheckTextEditingController();
 final valueCtrl = SpellCheckTextEditingController();
 final scopeCtrl = SpellCheckTextEditingController();
 final disciplineCtrl = SpellCheckTextEditingController();
 final contractorCtrl = SpellCheckTextEditingController();
 String contractType = 'Not Sure';
 String paymentType = 'TBD';
 String contractStartPhase = 'Not Sure';
 bool isSaving = false;
 String? valueError;

 showDialog(
 context: context,
 builder: (dCtx) => StatefulBuilder(
 builder: (dCtx, setDialog) => AlertDialog(
 title: const Text('Create Contract'),
 content: SizedBox(
 width: MediaQuery.of(dCtx).size.width > 600 ? 560 : null,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: nameCtrl,
 decoration: const InputDecoration(
 labelText: 'Contract Name *',
 border: OutlineInputBorder())),
 const SizedBox(height: 14),
 VoiceTextField(
 controller: descCtrl,
 maxLines: 2,
 decoration: const InputDecoration(
 labelText: 'Description',
 border: OutlineInputBorder())),
 const SizedBox(height: 14),
 VoiceTextField(
 controller: contractorCtrl,
 decoration: const InputDecoration(
 labelText: 'Contractor (optional)',
 hintText: 'Leave blank if not yet identified',
 border: OutlineInputBorder())),
 const SizedBox(height: 14),
 VoiceTextField(
 controller: valueCtrl,
 keyboardType: TextInputType.number,
 decoration: InputDecoration(
 labelText: 'Estimated Value *',
 prefixText: '\$',
 hintText: 'Required in planning phase',
 border: const OutlineInputBorder(),
 errorText: valueError)),
 const SizedBox(height: 14),
 // Phase for Contract Start — indicates which project phase the
 // contract is expected to kick off in. In planning, this should be
 // confirmed after the bid process.
 DropdownButtonFormField<String>(
 initialValue: contractStartPhase,
 items: const [
 'Not Sure',
 'Initiation',
 'Planning',
 'Design',
 'Execution',
 'Launch',
 'Post-Launch'
 ]
 .map((v) => DropdownMenuItem(
 value: v,
 child: Text(v,
 style: const TextStyle(fontSize: 13))))
 .toList(),
 onChanged: (v) =>
 setDialog(() => contractStartPhase = v ?? 'Not Sure'),
 decoration: const InputDecoration(
 labelText: 'Phase for Contract Start',
 border: OutlineInputBorder()),
 ),
 const SizedBox(height: 14),
 Row(
 children: [
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue: contractType,
 items: [
 'Not Sure',
 'Lump Sum (Fixed Price)',
 'Reimbursable (Time & Materials)'
 ]
 .map((v) => DropdownMenuItem(
 value: v,
 child: Text(v,
 style: const TextStyle(fontSize: 13))))
 .toList(),
 onChanged: (v) =>
 setDialog(() => contractType = v ?? 'Not Sure'),
 decoration: const InputDecoration(
 labelText: 'Contract Type',
 border: OutlineInputBorder()),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue: paymentType,
 items: ['TBD', 'Monthly', 'Milestone-Based', 'Upfront']
 .map((v) => DropdownMenuItem(
 value: v,
 child: Text(v,
 style: const TextStyle(fontSize: 13))))
 .toList(),
 onChanged: (v) =>
 setDialog(() => paymentType = v ?? 'TBD'),
 decoration: const InputDecoration(
 labelText: 'Payment Type',
 border: OutlineInputBorder()),
 ),
 ),
 ],
 ),
 const SizedBox(height: 14),
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: scopeCtrl,
 decoration: const InputDecoration(
 labelText: 'Scope',
 border: OutlineInputBorder())),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextField(
 controller: disciplineCtrl,
 decoration: const InputDecoration(
 labelText: 'Discipline',
 border: OutlineInputBorder())),
 ),
 ],
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(dCtx),
 child: const Text('Cancel')),
 ElevatedButton(
 onPressed: () async {
 if (isSaving) return;
 if (nameCtrl.text.trim().isEmpty) return;

 // In planning phase, the bid process has been executed so the
 // contract value is required.
 final valueText = valueCtrl.text.trim();
 final parsedValue = double.tryParse(valueText);
 if (parsedValue == null || parsedValue <= 0) {
 setDialog(() => valueError =
 'A positive contract value is required in planning phase.');
 return;
 }
 setDialog(() => valueError = null);

 setDialog(() => isSaving = true);
 try {
 final user = FirebaseAuth.instance.currentUser;
 await ContractService.createContract(
 projectId: projectId,
 name: nameCtrl.text.trim(),
 description: descCtrl.text.trim(),
 contractType: contractType,
 paymentType: paymentType,
 status: 'Not Started',
 estimatedValue: parsedValue,
 scope: scopeCtrl.text.trim(),
 discipline: disciplineCtrl.text.trim(),
 contractorName: contractorCtrl.text.trim(),
 contractStartPhase: contractStartPhase,
 createdById: user?.uid ?? '',
 createdByEmail: user?.email ?? '',
 createdByName: user?.displayName ?? '',
 );
 if (dCtx.mounted) Navigator.pop(dCtx);
 if (context.mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Contract created successfully.'),
 backgroundColor: Color(0xFF16A34A),
 ),
 );
 }
 } catch (e) {
 if (dCtx.mounted) {
 setDialog(() => isSaving = false);
 ScaffoldMessenger.of(dCtx).showSnackBar(
 SnackBar(
 content: Text('Unable to create contract: $e'),
 backgroundColor: Colors.red,
 ),
 );
 }
 }
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: _kFabYellow, foregroundColor: _kFabOnYellow),
 child: isSaving
 ? const SizedBox(
 width: 20,
 height: 20,
 child: CircularProgressIndicator(strokeWidth: 2, color: _kFabOnYellow))
 : const Text('Create',
 style: TextStyle(fontWeight: FontWeight.w600)),
 ),
 ],
 ),
 ),
 );
}

Future<void> _showEditPackageDialog(
 BuildContext context, ContractModel contract) async {
 final projectData = ProjectDataHelper.getData(context);
 final scopeOptions = _planningScopeOptionsFromData(projectData);
 final summaryCtrl =
 SpellCheckTextEditingController(text: contract.packageSummary ?? contract.description);
 final engineerEstimateCtrl = SpellCheckTextEditingController(
 text: contract.engineerEstimate?.toStringAsFixed(0) ?? '');
 final plannedValueCtrl =
 SpellCheckTextEditingController(text: contract.estimatedValue.toStringAsFixed(0));
 String selectedAwardStrategy = contract.awardStrategy ?? 'Sole Source';
 String selectedContractType =
 contract.contractType.isNotEmpty ? contract.contractType : 'Not Sure';
 String? selectedScopeId = contract.linkedFepScopeId;
 DateTime? targetAwardDate = contract.targetAwardDate;
 DateTime? plannedExecutionStart = contract.plannedExecutionStart;

 Future<DateTime?> pickDate(DateTime? current) {
 return showDatePicker(
 context: context,
 initialDate: current ?? DateTime.now(),
 firstDate: DateTime(2000),
 lastDate: DateTime(2100),
 );
 }

 await showDialog<void>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (dialogContext, setDialog) {
 final isNarrow = MediaQuery.of(dialogContext).size.width < 760;
 return AlertDialog(
 insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
 title: Text('Edit Package: ${contract.name}'),
 content: SizedBox(
 width: MediaQuery.of(dialogContext).size.width > 720 ? 620 : double.maxFinite,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DropdownButtonFormField<String?>(
 initialValue: scopeOptions.any((item) => item.id == selectedScopeId)
 ? selectedScopeId
 : null,
 isExpanded: true,
 items: <DropdownMenuItem<String?>>[
 const DropdownMenuItem<String?>(
 value: null,
 child: Text('Not linked'),
 ),
 ...scopeOptions.map((scope) => DropdownMenuItem<String?>(
 value: scope.id,
 child:
 Text(scope.label, overflow: TextOverflow.ellipsis),
 )),
 ],
 onChanged: (value) => setDialog(() => selectedScopeId = value),
 decoration: const InputDecoration(
 labelText: 'Linked FEP Scope',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 14),
 VoiceTextField(
 controller: summaryCtrl,
 maxLines: 3,
 decoration: const InputDecoration(
 labelText: 'Package Summary',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 14),
 if (isNarrow)
 Column(
 children: [
 VoiceTextField(
 controller: engineerEstimateCtrl,
 keyboardType: TextInputType.number,
 decoration: const InputDecoration(
 labelText: 'Engineer Estimate',
 prefixText: '\$',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: plannedValueCtrl,
 keyboardType: TextInputType.number,
 decoration: const InputDecoration(
 labelText: 'Planned Award Value',
 prefixText: '\$',
 border: OutlineInputBorder(),
 ),
 ),
 ],
 )
 else
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: engineerEstimateCtrl,
 keyboardType: TextInputType.number,
 decoration: const InputDecoration(
 labelText: 'Engineer Estimate',
 prefixText: '\$',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextField(
 controller: plannedValueCtrl,
 keyboardType: TextInputType.number,
 decoration: const InputDecoration(
 labelText: 'Planned Award Value',
 prefixText: '\$',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 14),
 if (isNarrow)
 Column(
 children: [
 DropdownButtonFormField<String>(
 initialValue: selectedAwardStrategy,
 isExpanded: true,
 items: const [
 DropdownMenuItem(
 value: 'Sole Source', child: Text('Sole Source')),
 DropdownMenuItem(
 value: 'Competitive Bidding',
 child: Text('Competitive Bidding')),
 DropdownMenuItem(
 value: 'Not Sure', child: Text('Not Sure')),
 ],
 onChanged: (value) => setDialog(
 () => selectedAwardStrategy = value ?? 'Not Sure'),
 decoration: const InputDecoration(
 labelText: 'Award Strategy',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 initialValue: selectedContractType,
 isExpanded: true,
 items: const [
 DropdownMenuItem(
 value: 'Not Sure', child: Text('Not Sure')),
 DropdownMenuItem(
 value: 'Lump Sum (Fixed Price)',
 child: Text('Lump Sum (Fixed Price)')),
 DropdownMenuItem(
 value: 'Reimbursable (Time & Materials)',
 child: Text('Reimbursable (Time & Materials)')),
 ],
 onChanged: (value) => setDialog(() =>
 selectedContractType = value ?? 'Not Sure'),
 decoration: const InputDecoration(
 labelText: 'Contract Type',
 border: OutlineInputBorder(),
 ),
 ),
 ],
 )
 else
 Row(
 children: [
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue: selectedAwardStrategy,
 isExpanded: true,
 items: const [
 DropdownMenuItem(
 value: 'Sole Source', child: Text('Sole Source')),
 DropdownMenuItem(
 value: 'Competitive Bidding',
 child: Text('Competitive Bidding')),
 DropdownMenuItem(
 value: 'Not Sure', child: Text('Not Sure')),
 ],
 onChanged: (value) => setDialog(
 () => selectedAwardStrategy = value ?? 'Not Sure'),
 decoration: const InputDecoration(
 labelText: 'Award Strategy',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue: selectedContractType,
 isExpanded: true,
 items: const [
 DropdownMenuItem(
 value: 'Not Sure', child: Text('Not Sure')),
 DropdownMenuItem(
 value: 'Lump Sum (Fixed Price)',
 child: Text('Lump Sum (Fixed Price)')),
 DropdownMenuItem(
 value: 'Reimbursable (Time & Materials)',
 child: Text('Reimbursable (Time & Materials)')),
 ],
 onChanged: (value) => setDialog(() =>
 selectedContractType = value ?? 'Not Sure'),
 decoration: const InputDecoration(
 labelText: 'Contract Type',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 14),
 Wrap(
 spacing: 12,
 runSpacing: 12,
 children: [
 SizedBox(
 width: isNarrow ? double.infinity : 280,
 child: OutlinedButton.icon(
 onPressed: () async {
 final picked = await pickDate(targetAwardDate);
 if (picked != null) {
 setDialog(() => targetAwardDate = picked);
 }
 },
 icon: const Icon(Icons.event_outlined, size: 16),
 label: Text(
 'Target Award: ${_formatDateLabel(targetAwardDate)}'),
 ),
 ),
 SizedBox(
 width: isNarrow ? double.infinity : 280,
 child: OutlinedButton.icon(
 onPressed: () async {
 final picked = await pickDate(plannedExecutionStart);
 if (picked != null) {
 setDialog(() => plannedExecutionStart = picked);
 }
 },
 icon: const Icon(Icons.calendar_month_outlined, size: 16),
 label: Text(
 'Execution Start: ${_formatDateLabel(plannedExecutionStart)}'),
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 child: const Text('Cancel')),
 ElevatedButton(
 onPressed: () async {
 await ContractService.updateContract(
 projectId: contract.projectId,
 contractId: contract.id,
 contractType: selectedContractType,
 estimatedValue: double.tryParse(plannedValueCtrl.text.trim()),
 );
 await ContractService.updatePlanningFields(
 projectId: contract.projectId,
 contractId: contract.id,
 linkedFepScopeId: selectedScopeId ?? '',
 packageSummary: summaryCtrl.text.trim(),
 engineerEstimate:
 double.tryParse(engineerEstimateCtrl.text.trim()),
 targetAwardDate: targetAwardDate,
 plannedExecutionStart: plannedExecutionStart,
 awardStrategy: selectedAwardStrategy,
 linkedScheduleMilestoneIds: _mergeMilestoneIds(
 contract.linkedScheduleMilestoneIds,
 [
 _scheduleMilestoneId(contract.id, 'award'),
 _scheduleMilestoneId(contract.id, 'execution_start'),
 ],
 ),
 );
 await _upsertScheduleMilestoneActivity(
 context: context,
 milestoneId: _scheduleMilestoneId(contract.id, 'award'),
 title: '${contract.name} Award',
 date: targetAwardDate,
 );
 await _upsertScheduleMilestoneActivity(
 context: context,
 milestoneId: _scheduleMilestoneId(contract.id, 'execution_start'),
 title: '${contract.name} Execution Start',
 date: plannedExecutionStart,
 predecessorIds: targetAwardDate != null
 ? [_scheduleMilestoneId(contract.id, 'award')]
 : const [],
 );
 if (dialogContext.mounted) {
 Navigator.of(dialogContext).pop();
 }
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Saved package updates for ${contract.name}.'),
 backgroundColor: const Color(0xFF16A34A),
 ),
 );
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: _kBrandYellow,
 foregroundColor: Colors.white),
 child: const Text('Save Package'),
 ),
 ],
 );
 },
 ),
 );
}/// The Contracts tab: the contract log first, package cards second
/// (Lusaka 27).
///
/// The old "FEP Scope Inputs" card is gone — "FEP scope input, that does not
/// make sense to me. So if you have like the contract, and the contract name,
/// the scope, the potential value … then you can do it there" — and the FEP
/// scopes are now an action: *Add from FEP* pre-fills one contract per
/// unlinked initiation scope.
class _ContractsTab extends StatefulWidget {
  const _ContractsTab();

  @override
  State<_ContractsTab> createState() => _ContractsTabState();
}

class _ContractsTabState extends State<_ContractsTab> {
  @override
  Widget build(BuildContext context) {
    final projectId = ProjectDataHelper.getData(context).projectId;
    return StreamBuilder<List<ContractModel>>(
      stream: projectId != null && projectId.isNotEmpty
          ? ContractService.streamContracts(projectId)
          : Stream.value(const []),
      builder: (context, snap) {
        final contracts = snap.data ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ContractLogSection(
              projectId: projectId,
              contracts: contracts,
              onAddFromFep: () => _showAddFromFepDialog(context, projectId),
              onImportContractors: () =>
                  _showContractorImportDialog(context, projectId),
            ),
          ],
        );
      },
    );
  }
}

/// The contract log: numbered rows, table first, cards as the secondary view,
/// expandable to full screen. Rows carry the per-contract strategy, type and
/// RFP cycle.
class _ContractLogSection extends StatelessWidget {
  const _ContractLogSection({
    required this.projectId,
    required this.contracts,
    required this.onAddFromFep,
    required this.onImportContractors,
  });

  final String? projectId;
  final List<ContractModel> contracts;
  final VoidCallback onAddFromFep;
  final VoidCallback onImportContractors;

  List<ContractLogRow> get _rows => <ContractLogRow>[
        for (var i = 0; i < contracts.length; i++)
          ContractLogRow.fromContract(contracts[i], number: i + 1),
      ];

  static bool _matches(dynamic item, String query) {
    if (item is! ContractLogRow) return false;
    return item.matches(query);
  }

  List<ContractLogRow> _matching(String query) {
    if (query.trim().isEmpty) return _rows;
    return _rows.where((row) => row.matches(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (projectId == null || projectId!.isEmpty) {
      return const _EmptyPanel('No project selected.');
    }
    if (contracts.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
              alignment: Alignment.centerRight,
              child: _headerActions(context)),
          const _SectionCard(
            title: 'Contract Log',
            subtitle: 'Every contract, its scope, potential value, strategy and '
                'RFP cycle.',
            child: const _EmptyPanel(
                'No contracts yet. Add a contract, pull one from a FEP scope, or import your contractor list.'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
            alignment: Alignment.centerRight, child: _headerActions(context)),
        SearchableTableSection(
          title: 'Contract Log',
          subtitle: 'Every contract, its scope, potential value, strategy and '
              'RFP cycle. Strategy, type and cycle are set on each contract — '
              'tap a contract or its cycle to edit.',
          items: _rows,
          searchHint: 'Search the contract log...',
          searchFilter: _matches,
          tableBuilder: (context, query) =>
              _buildTable(context, _matching(query)),
          cardBuilder: (context, query) =>
              _buildCards(context, _matching(query)),
        ),
      ],
    );
  }

  Widget _headerActions(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        TextButton.icon(
          onPressed: () => _showCreateContractDialog(context, projectId),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Contract',
              style: TextStyle(fontWeight: FontWeight.w600)),
          style: TextButton.styleFrom(foregroundColor: _kBrandYellow),
        ),
        TextButton.icon(
          onPressed: onAddFromFep,
          icon: const Icon(Icons.sync_alt, size: 16),
          label: const Text('Add from FEP'),
          style: TextButton.styleFrom(foregroundColor: _kBrandYellow),
        ),
        TextButton.icon(
          onPressed: onImportContractors,
          icon: const Icon(Icons.upload_file_outlined, size: 16),
          label: const Text('Import contractors'),
          style: TextButton.styleFrom(foregroundColor: _kBrandYellow),
        ),
      ],
    );
  }

  Widget _buildTable(BuildContext context, List<ContractLogRow> visible) {
    if (visible.isEmpty) {
      return buildNduTableEmptyState(context,
          message: 'No contracts match this search.');
    }
    return buildNduTableWithExpand(
      context: context,
      title: 'Contract Log',
      minWidth: 1500,
      columnSpacing: 16,
      columns: <DataColumn>[
        for (final column in contractLogColumns)
          DataColumn(label: Text(column.label)),
      ],
      rows: <DataRow>[
        for (final row in visible)
          DataRow(cells: <DataCell>[
            for (final column in contractLogColumns)
              DataCell(_cell(context, column.key, row)),
          ]),
      ],
    );
  }

  Widget _cell(BuildContext context, String key, ContractLogRow row) {
    final value = row.valueFor(key);
    final contract = _contractFor(row.id);
    switch (key) {
      case 'name':
        return InkWell(
          onTap: contract == null
              ? null
              : () => _showEditPackageDialog(context, contract),
          child: WrappedText(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D4ED8),
            ),
          ),
        );
      case 'scope':
        return WrappedText(value,
            maxLines: 3, overflow: TextOverflow.ellipsis);
      case 'value':
        return Text(value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF059669)));
      case 'cycle':
        // One tappable cell rather than a chip plus a button: a DataCell must
        // never need more width than its column.
        return Tooltip(
          message: row.hasRfpCycle
              ? 'Tap to edit the RFP cycle'
              : 'Tap to set the RFP cycle',
          child: InkWell(
            onTap: contract == null
                ? null
                : () => _showRfpCycleDialog(context, contract),
            child: WrappedText(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: row.hasRfpCycle
                    ? const Color(0xFF92400E)
                    : const Color(0xFF6B7280),
              ),
            ),
          ),
        );
      case 'status':
        return _StatusChip(label: value, color: _statusColor(value));
      default:
        return WrappedText(value, maxLines: 2, overflow: TextOverflow.ellipsis);
    }
  }

  ContractModel? _contractFor(String id) {
    for (final contract in contracts) {
      if (contract.id == id) return contract;
    }
    return null;
  }

  Widget _buildCards(BuildContext context, List<ContractLogRow> visible) {
    if (visible.isEmpty) {
      return buildNduTableEmptyState(context,
          message: 'No contracts match this search.');
    }
    return Column(
      children: <Widget>[
        for (final row in visible)
          if (_contractFor(row.id) != null)
            _PackagePlanningCard(contract: _contractFor(row.id)!),
      ],
    );
  }
}

/// "if you already have a list of contractors, they can just import it and
/// utilize it" — pulls the initiation contractor list into the contract log.
Future<void> _showContractorImportDialog(
    BuildContext context, String? projectId) async {
  if (projectId == null || projectId.isEmpty) return;
  final data = ProjectDataHelper.getData(context);
  final contractors = data.contractors
      .where((c) => c.name.trim().isNotEmpty || c.service.trim().isNotEmpty)
      .toList();
  if (contractors.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'No contractors are on the initiation contractor list yet.'),
        backgroundColor: Color(0xFFB45309),
      ),
    );
    return;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dCtx) => AlertDialog(
      title: const Text('Import contractors'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${contractors.length} contractor'
              '${contractors.length == 1 ? '' : 's'} from the initiation list will '
              'become contracts in this log. Contractors already in the log are '
              'left alone.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            for (final contractor in contractors.take(8))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  '· ${contractor.name.trim().isEmpty ? contractor.service : contractor.name}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF4B5563)),
                ),
              ),
            if (contractors.length > 8)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('· +${contractors.length - 8} more',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280))),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dCtx).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dCtx).pop(true),
          style: ElevatedButton.styleFrom(
              backgroundColor: _kBrandYellow,
              foregroundColor: Colors.white),
          child: const Text('Import'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final imported = await _importContractorsAsContracts(context, projectId);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(imported == 0
          ? 'Every listed contractor is already in the contract log.'
          : 'Imported $imported contractor${imported == 1 ? '' : 's'} into the contract log.'),
      backgroundColor: const Color(0xFF16A34A),
    ),
  );
}

/// Creates one contract per contractor on the initiation list that is not in
/// the log yet. Returns how many were created.
Future<int> _importContractorsAsContracts(
    BuildContext context, String projectId) async {
  final data = ProjectDataHelper.getData(context);
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return 0;
  final contractors = data.contractors
      .where((c) => c.name.trim().isNotEmpty || c.service.trim().isNotEmpty)
      .toList();
  final existing = await ContractService.streamContracts(projectId).first;
  final existingNames = existing
      .map((c) => c.contractorName.trim().toLowerCase())
      .where((name) => name.isNotEmpty)
      .toSet();
  final now = DateTime.now();
  var created = 0;
  for (final contractor in contractors) {
    final name = contractor.name.trim().isNotEmpty
        ? contractor.name.trim()
        : contractor.service.trim();
    if (name.isEmpty || existingNames.contains(name.toLowerCase())) continue;
    final service = contractor.service.trim();
    await ContractService.createContract(
      projectId: projectId,
      name: name,
      description: service.isNotEmpty ? service : 'Imported from initiation',
      contractType: 'Not Sure',
      paymentType: 'TBD',
      status: contractor.status.trim().isNotEmpty
          ? contractor.status.trim()
          : 'Not Started',
      estimatedValue: contractor.estimatedCost,
      startDate: now,
      endDate: now.add(const Duration(days: 30)),
      scope: service,
      discipline: service.isNotEmpty ? service : 'General',
      contractorName: name,
      notes: 'Imported from the initiation contractor list.',
      createdById: user.uid,
      createdByEmail: user.email ?? '',
      createdByName: user.displayName ?? '',
    );
    created++;
  }
  return created;
}

/// "then you can do it there" — one contract per unlinked FEP scope.
Future<void> _showAddFromFepDialog(
    BuildContext context, String? projectId) async {
  if (projectId == null || projectId.isEmpty) return;
  final options = _planningScopeOptionsFromData(ProjectDataHelper.getData(context));
  final existing = await ContractService.streamContracts(projectId).first;
  final linked = existing
      .map((c) => (c.linkedFepScopeId ?? '').trim())
      .where((id) => id.isNotEmpty)
      .toSet();
  final available =
      options.where((option) => !linked.contains(option.id)).toList();
  if (!context.mounted) return;
  if (available.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Every FEP scope already has a contract in the log. Add a scope in Initiation, or create the contract manually.'),
        backgroundColor: Color(0xFFB45309),
      ),
    );
    return;
  }
  final selected = <String>{};
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dCtx) => StatefulBuilder(
      builder: (dCtx, setDialog) => AlertDialog(
        title: const Text('Add contracts from FEP scopes'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Each selected scope becomes a contract pre-filled with the '
                  'scope name, the scope of work and the potential value.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
                ),
                const SizedBox(height: 12),
                for (final option in available)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: selected.contains(option.id),
                    activeColor: _kBrandYellow,
                    onChanged: (value) => setDialog(() {
                      if (value == true) {
                        selected.add(option.id);
                      } else {
                        selected.remove(option.id);
                      }
                    }),
                    title: Text(option.label,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                      '${option.type} · '
                      '${option.value > 0 ? '\$${_formatCurrency(option.value)}' : 'TBD'} · ${option.status}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: selected.isEmpty
                ? null
                : () => Navigator.of(dCtx).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _kBrandYellow,
                foregroundColor: Colors.white),
            child: Text('Add ${selected.length}'),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await _createContractsFromFepScopes(context, projectId,
      available.where((option) => selected.contains(option.id)).toList());
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
          'Added ${selected.length} contract${selected.length == 1 ? '' : 's'} from FEP scopes.'),
      backgroundColor: const Color(0xFF16A34A),
    ),
  );
}

Future<void> _createContractsFromFepScopes(
  BuildContext context,
  String projectId,
  List<_PlanningScopeOption> options,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final now = DateTime.now();
  for (final option in options) {
    await ContractService.createContract(
      projectId: projectId,
      name: option.label,
      description: 'Carried over from the FEP scope: ${option.label}',
      contractType: 'Not Sure',
      paymentType: 'TBD',
      status: 'Not Started',
      estimatedValue: option.value,
      startDate: now,
      endDate: now.add(const Duration(days: 30)),
      scope: option.label,
      discipline: option.type,
      contractorName: option.type == 'Contractor Scope' ? option.label : '',
      notes: 'Created from the FEP scope ${option.id}.',
      createdById: user.uid,
      createdByEmail: user.email ?? '',
      createdByName: user.displayName ?? '',
    );
  }
}

/// The per-contract RFP cycle popup: "a button where you click on it and it can
/// pop up and it can show you where the cycle [is] and you can choose which is
/// going to be where you are going to send out the [RFP]".
Future<void> _showRfpCycleDialog(
    BuildContext context, ContractModel contract) async {
  final projectId = ProjectDataHelper.getData(context).projectId;
  if (projectId == null || projectId.isEmpty) return;
  var cycle = contract.rfpCycle ??
      (contract.targetAwardDate != null
          ? ContractRfpCycle.backPlanFromAwardDate(contract.targetAwardDate!)
          : ContractRfpCycle.withDefaults(DateTime.now()));
  var isSaving = false;

  Future<DateTime?> pickDate(DateTime current) => showDatePicker(
        context: context,
        initialDate: current,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialog) {
        final isSkipped = cycle.isSkipped;
        return AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Text('RFP Cycle: ${contract.name}'),
          content: SizedBox(
            width: MediaQuery.of(dialogContext).size.width > 720
                ? 640
                : double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<bool>(
                    segments: const <ButtonSegment<bool>>[
                      ButtonSegment<bool>(
                          value: false, label: Text('Full RFP cycle')),
                      ButtonSegment<bool>(
                          value: true, label: Text('Skip the cycle')),
                    ],
                    selected: <bool>{isSkipped},
                    onSelectionChanged: (selection) => setDialog(() {
                      cycle = selection.first
                          ? cycle.asSkipped(
                              cycle.skipReason.trim().isEmpty
                                  ? kRfpCycleSkipReasons.first
                                  : cycle.skipReason)
                          : cycle.asCompetitive();
                    }),
                  ),
                  const SizedBox(height: 16),
                  if (isSkipped) ...[
                    const Text(
                      'A small contract can be awarded without running the whole '
                      'process — say sole source or award.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: kRfpCycleSkipReasons
                              .contains(cycle.skipReason)
                          ? cycle.skipReason
                          : kRfpCycleSkipReasons.first,
                      isExpanded: true,
                      items: kRfpCycleSkipReasons
                          .map((reason) => DropdownMenuItem<String>(
                              value: reason, child: Text(reason)))
                          .toList(),
                      onChanged: (value) => setDialog(() => cycle =
                          cycle.asSkipped(value ?? kRfpCycleSkipReasons.first)),
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _CycleDateRow(
                      label: 'Direct award date',
                      date: cycle.awardDate,
                      onPick: () async {
                        final picked = await pickDate(cycle.awardDate);
                        if (picked != null) {
                          setDialog(
                              () => cycle = cycle.withStartDate(picked));
                        }
                      },
                    ),
                  ] else ...[
                    _CycleDateRow(
                      label: 'Scope out to bidders',
                      date: cycle.startDate,
                      onPick: () async {
                        final picked = await pickDate(cycle.startDate);
                        if (picked != null) {
                          setDialog(
                              () => cycle = cycle.withStartDate(picked));
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text('Stage durations',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    for (final stage in ContractRfpCycle.adjustableStages)
                      _CycleWeeksRow(
                        stage: stage,
                        weeks: cycle.weeksFor(stage),
                        onChanged: (weeks) => setDialog(() =>
                            cycle = cycle.withStageWeeks(stage, weeks)),
                      ),
                    const SizedBox(height: 14),
                    const Text('The cycle',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    for (final window in cycle.windows())
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(window.stage.label,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                window.isMilestone
                                    ? formatCycleDate(window.start)
                                    : '${formatCycleDate(window.start)} → '
                                        '${formatCycleDate(window.end)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF4B5563)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    _StatusChip(
                      label: 'Award ${formatCycleDate(cycle.awardDate)}',
                      color: _kBrandYellow,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                : () async {
                    final error = cycle.validate();
                    final messenger = ScaffoldMessenger.of(context);
                    if (error != null) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(error),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    setDialog(() => isSaving = true);
                    final awardDate = cycle.awardDate;
                    await ContractService.updatePlanningFields(
                      projectId: projectId,
                      contractId: contract.id,
                      rfpCycle: cycle,
                      targetAwardDate: awardDate,
                    );
                    if (!dialogContext.mounted) return;
                    await _upsertScheduleMilestoneActivity(
                      context: dialogContext,
                      milestoneId:
                          _scheduleMilestoneId(contract.id, 'award'),
                      title: '${contract.name} Award',
                      date: awardDate,
                    );
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                            'Saved the RFP cycle for ${contract.name}.'),
                        backgroundColor: const Color(0xFF16A34A),
                      ),
                    );
                  },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kBrandYellow,
                  foregroundColor: Colors.white),
              child: const Text('Save Cycle'),
            ),
          ],
        );
      },
    ),
  );
}

class _CycleDateRow extends StatelessWidget {
  const _CycleDateRow({
    required this.label,
    required this.date,
    required this.onPick,
  });

  final String label;
  final DateTime date;
  final Future<void> Function() onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        OutlinedButton.icon(
          onPressed: () => onPick(),
          icon: const Icon(Icons.event, size: 16),
          label: Text(formatCycleDate(date)),
          style: OutlinedButton.styleFrom(foregroundColor: _kBrandYellow),
        ),
      ],
    );
  }
}

class _CycleWeeksRow extends StatelessWidget {
  const _CycleWeeksRow({
    required this.stage,
    required this.weeks,
    required this.onChanged,
  });

  final RfpCycleStage stage;
  final int weeks;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(stage.label,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF4B5563))),
          ),
          IconButton(
            onPressed: weeks > 0 ? () => onChanged(weeks - 1) : null,
            icon: const Icon(Icons.remove_circle_outline, size: 18),
            tooltip: 'One week less',
          ),
          SizedBox(
            width: 60,
            child: Text('$weeks wk',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          IconButton(
            onPressed: weeks < 52 ? () => onChanged(weeks + 1) : null,
            icon: const Icon(Icons.add_circle_outline, size: 18),
            tooltip: 'One week more',
          ),
        ],
      ),
    );
  }
}

class _TenderSetupTab extends StatelessWidget {
 const _TenderSetupTab();

 @override
 Widget build(BuildContext context) {
 final initialText =
 ProjectDataHelper.getData(context).planningNotes['planning_tender_setup'];
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _SectionCard(
 title: 'Tender Setup Guidance',
 subtitle:
 'Prepare package-linked RFPs, invited bidders, bid dates, and evaluation setup before procurement takes over.',
 child: AiSuggestingTextField(
 fieldLabel: 'Tender Setup Guidance',
 hintText:
 'Describe bidder strategy, technical/commercial split, submission timelines, and clarification approach.',
 sectionLabel: 'Tender Setup Guidance',
 autoGenerate: true,
 autoGenerateSection: 'Tender Setup Guidance',
 initialText: initialText,
 onChanged: (value) async {
 final trimmed = value.trim();
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'contracts',
 dataUpdater: (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 'planning_tender_setup': trimmed,
 },
 ),
 showSnackbar: false,
 );
 },
 onAutoGenerated: (value) async {
 final trimmed = value.trim();
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'contracts',
 dataUpdater: (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 'planning_tender_setup': trimmed,
 },
 ),
 showSnackbar: false,
 );
 },
 ),
 ),
 const _RfpTab(),
 ],
 );
 }
}

class _CommercialForecastTab extends StatelessWidget {
 const _CommercialForecastTab();

 @override
 Widget build(BuildContext context) {
 return const Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _PaymentsTab(),
 _BudgetTab(),
 ],
 );
 }
}

class _HandoffTab extends StatelessWidget {
 const _HandoffTab();

 @override
 Widget build(BuildContext context) {
 final projectId = ProjectDataHelper.getData(context).projectId;
 if (projectId == null || projectId.isEmpty) {
 return const _EmptyPanel('No project selected.');
 }

 return StreamBuilder<List<ContractModel>>(
 stream: ContractService.streamContracts(projectId),
 builder: (context, snap) {
 final contracts = snap.data ?? const [];
 final packageCount = contracts.length;
 final plannedValue =
 contracts.fold<double>(0.0, (t, c) => t + c.estimatedValue);
 final readyContracts = contracts
 .where((contract) => _isReadyForExecutionHandoff(contract))
 .toList();
 final procurementIssuedContracts = contracts
 .where((contract) =>
 (contract.procurementHandoffStatus ?? '').toLowerCase() ==
 'issued to procurement')
 .toList();
 final procurementIssuedValue = procurementIssuedContracts.fold<double>(
 0.0,
 (total, contract) =>
 total + (contract.recommendedAwardValue ?? contract.estimatedValue));

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Wrap(
 spacing: 12,
 runSpacing: 12,
 children: [
 _StatCard(
 value: packageCount.toString(),
 label: 'Packages',
 color: _kBrandYellow,
 supporting: 'Planning records prepared'),
 _StatCard(
 value: packageCount == 0
 ? 'TBD'
 : '\$${_formatCurrency(plannedValue)}',
 label: 'Approved Value Target',
 color: const Color(0xFF059669),
 supporting: 'Will flow to execution'),
 _StatCard(
 value: '${readyContracts.length}/$packageCount',
 label: 'Ready For Execution',
 color: const Color(0xFFF59E0B),
 supporting: 'Sponsor approval required'),
 _StatCard(
 value: procurementIssuedContracts.isEmpty
 ? 'TBD'
 : '\$${_formatCurrency(procurementIssuedValue)}',
 label: 'Issued To Procurement',
 color: const Color(0xFFB8860B),
 supporting: '${procurementIssuedContracts.length} packages'),
 ],
 ),
 const SizedBox(height: 20),
 const _SectionCard(
 title: 'Execution Handoff Rules',
 subtitle:
 'Contract planning hands off only approved packages with finalized commercial and administration settings.',
 child: _HandoffChecklist(),
 ),
 const SizedBox(height: 20),
 _SectionCard(
 title: 'Package Handoff Readiness',
 subtitle:
 'Each package must pass PM review and sponsor approval before it can feed execution.',
 child: contracts.isEmpty
 ? const _EmptyPanel(
 'Add contract packages first to prepare execution handoff.')
 : Column(
 children: contracts
 .map((contract) =>
 _HandoffReadinessCard(contract: contract))
 .toList(),
 ),
 ),
 ],
 );
 },
 );
 }
}

bool _isReadyForExecutionHandoff(ContractModel contract) {
 final sponsorApproved =
 (contract.sponsorApprovalStatus ?? '').toLowerCase() == 'approved';
 final pmApproved = (contract.pmReviewStatus ?? '').toLowerCase() == 'approved';
 final hasVendor = (contract.recommendedVendor ?? '').trim().isNotEmpty;
 final hasScope = (contract.linkedFepScopeId ?? '').trim().isNotEmpty;
 final hasAwardValue =
 (contract.recommendedAwardValue ?? contract.estimatedValue) > 0;
 return sponsorApproved && pmApproved && hasVendor && hasScope && hasAwardValue;
}

bool _isReadyForProcurementHandoff(ContractModel contract) {
 final sponsorApproved =
 (contract.sponsorApprovalStatus ?? '').toLowerCase() == 'approved';
 final pmApproved = (contract.pmReviewStatus ?? '').toLowerCase() == 'approved';
 final hasLinkedTender = (contract.linkedRfqId ?? '').trim().isNotEmpty;
 return sponsorApproved && pmApproved && hasLinkedTender;
}

procurement_models.RfqStatus _mapPlanningRfqStatusToProcurement(
 String status,
) {
 final normalized = status.trim().toLowerCase();
 switch (normalized) {
 case 'published':
 return procurement_models.RfqStatus.inMarket;
 case 'evaluation':
 return procurement_models.RfqStatus.evaluation;
 case 'awarded':
 return procurement_models.RfqStatus.awarded;
 default:
 return procurement_models.RfqStatus.draft;
 }
}

Future<void> _issuePackageToProcurement(
 BuildContext context,
 ContractModel contract,
) async {
 final rfqs =
 await PlanningContractingService.streamRfqs(contract.projectId).first;
 PlanningRfq? planningRfq;
 for (final rfq in rfqs) {
 if (rfq.id == contract.linkedRfqId) {
 planningRfq = rfq;
 break;
 }
 }
 planningRfq ??= rfqs.where((rfq) => rfq.linkedScopeId == contract.id).firstOrNull;
 if (planningRfq == null) {
 return;
 }

 final now = DateTime.now();
 final procurementRfq = procurement_models.RfqModel(
 id: contract.procurementRfqId ?? '',
 projectId: contract.projectId,
 title: planningRfq.title,
 category: contract.discipline.isEmpty ? 'Contract Package' : contract.discipline,
 owner: contract.contractManagerName ?? contract.owner,
 dueDate: planningRfq.submissionDeadline ??
 contract.targetAwardDate ??
 now.add(const Duration(days: 14)),
 invitedCount: planningRfq.invitedContractors.length,
 responseCount: 0,
 budget: contract.recommendedAwardValue ?? contract.estimatedValue,
 status: _mapPlanningRfqStatusToProcurement(planningRfq.status),
 priority: procurement_models.ProcurementPriority.high,
 createdAt: now,
 );

 String procurementRfqId = contract.procurementRfqId ?? '';
 if (procurementRfqId.isEmpty) {
 procurementRfqId = await ProcurementService.createRfq(procurementRfq);
 } else {
 await ProcurementService.updateRfq(
 contract.projectId,
 procurementRfqId,
 {
 'title': procurementRfq.title,
 'category': procurementRfq.category,
 'owner': procurementRfq.owner,
 'dueDate': Timestamp.fromDate(procurementRfq.dueDate),
 'invitedCount': procurementRfq.invitedCount,
 'budget': procurementRfq.budget,
 'status': procurementRfq.status.name,
 'priority': procurementRfq.priority.name,
 },
 );
 }

 await ContractService.updatePlanningFields(
 projectId: contract.projectId,
 contractId: contract.id,
 procurementHandoffStatus: 'Issued to Procurement',
 procurementIssuedAt: now,
 procurementRfqId: procurementRfqId,
 );
}/// Pre-award compliance items, in Admin Controls.
///
/// Lusaka 27: "warranty has to be included in one of those in admin controls
/// where you had your legal registration … instead before contract award".
const List<String> _defaultComplianceChecklist = [
  'Legal Registration',
  'Warranty',
  'Key Dates',
  'Tax Clearance',
  'Insurance',
  'Bond / Guarantee',
  'Signed Forms',
  'HSE Documentation',
];

/// Pre-award warranty periods, in months.
const List<int> _warrantyMonthOptions = <int>[0, 6, 12, 24, 36];

/// "add warranty/key dates/taxes as evaluation factors" — the default criteria
/// for a new RFP, still summing to 100.
final List<EvaluationCriteria> _defaultEvaluationCriteria = <EvaluationCriteria>[
  EvaluationCriteria(name: 'Technical Compliance', weight: 30, category: 'Technical'),
  EvaluationCriteria(name: 'Commercial Offer', weight: 25, category: 'Commercial'),
  EvaluationCriteria(name: 'Delivery Plan', weight: 15, category: 'Commercial'),
  EvaluationCriteria(name: 'Warranty Terms', weight: 15, category: 'Commercial'),
  EvaluationCriteria(name: 'Key Dates', weight: 10, category: 'Schedule'),
  EvaluationCriteria(name: 'Taxes & Duties', weight: 5, category: 'Commercial'),
];

class _HandoffChecklist extends StatelessWidget {
 const _HandoffChecklist();

 @override
 Widget build(BuildContext context) {
 const items = [
 'Package linked to an initiation scope',
 'Recommended vendor and award value captured',
 'PM review completed',
 'Sponsor approval completed',
 'Commercial plan drafted with milestones, retention, taxes, and forecast',
 'Administration controls defined',
 'Schedule milestones generated automatically for key contract dates',
 ];

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: items
 .map((item) => Padding(
 padding: const EdgeInsets.symmetric(vertical: 6),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Padding(
 padding: EdgeInsets.only(top: 2),
 child: Icon(Icons.check_circle_outline,
 size: 16, color: _kBrandYellow),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Text(item,
 style: const TextStyle(
 fontSize: 13, color: Color(0xFF374151))),
 ),
 ],
 ),
 ))
 .toList(),
 );
 }
}

class _HandoffReadinessCard extends StatelessWidget {
 const _HandoffReadinessCard({required this.contract});

 final ContractModel contract;

 @override
 Widget build(BuildContext context) {
 final missingReasons = <String>[
 if ((contract.linkedFepScopeId ?? '').trim().isEmpty)
 'Link this package to an initiation/FEP scope.',
 if ((contract.recommendedVendor ?? '').trim().isEmpty)
 'Select a recommended vendor in Evaluation.',
 if ((contract.recommendedAwardValue ?? contract.estimatedValue) <= 0)
 'Enter a recommended award value.',
 if ((contract.pmReviewStatus ?? '').toLowerCase() != 'approved')
 'PM review must be approved.',
 if ((contract.sponsorApprovalStatus ?? '').toLowerCase() != 'approved')
 'Sponsor approval must be approved.',
 if ((contract.linkedScheduleMilestoneIds ?? const []).isEmpty)
 'Save package/evaluation dates to generate milestones.',
 ];
 final readinessChecks = <MapEntry<String, bool>>[
 MapEntry('Initiation scope linked',
 (contract.linkedFepScopeId ?? '').trim().isNotEmpty),
 MapEntry('Recommended vendor selected',
 (contract.recommendedVendor ?? '').trim().isNotEmpty),
 MapEntry('Recommended award value captured',
 (contract.recommendedAwardValue ?? contract.estimatedValue) > 0),
 MapEntry('PM review approved',
 (contract.pmReviewStatus ?? '').toLowerCase() == 'approved'),
 MapEntry('Sponsor approval approved',
 (contract.sponsorApprovalStatus ?? '').toLowerCase() == 'approved'),
 MapEntry('Schedule milestones generated',
 (contract.linkedScheduleMilestoneIds ?? const []).isNotEmpty),
 ];
 final ready = _isReadyForExecutionHandoff(contract);
 final readyForProcurement = _isReadyForProcurementHandoff(contract);
 final awardValue = contract.recommendedAwardValue ?? contract.estimatedValue;
 final alreadySent =
 (contract.handoffStatus ?? '').toLowerCase() == 'sent to execution';
 final procurementIssued =
 (contract.procurementHandoffStatus ?? '').toLowerCase() ==
 'issued to procurement';

 return Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(contract.name,
 style: const TextStyle(
 fontSize: 15, fontWeight: FontWeight.w700)),
 const SizedBox(height: 4),
 Text(
 ready
 ? 'Ready to hand off after sponsor approval.'
 : missingReasons.first,
 style: TextStyle(
 fontSize: 12,
 color: ready
 ? const Color(0xFF059669)
 : const Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 ),
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: ready
 ? const Color(0xFFDCFCE7)
 : const Color(0xFFFEF3C7),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 ready ? 'Ready for Execution' : 'Blocked',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: ready
 ? const Color(0xFF166534)
 : const Color(0xFF92400E),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Wrap(
 spacing: 10,
 runSpacing: 10,
 children: [
 _PackageMetricChip(
 label: 'Vendor',
 value: (contract.recommendedVendor ?? '').trim().isEmpty
 ? 'Pending'
 : contract.recommendedVendor!,
 ),
 _PackageMetricChip(
 label: 'Award Value',
 value: awardValue > 0
 ? '\$${_formatCurrency(awardValue)}'
 : 'Pending',
 ),
 _PackageMetricChip(
 label: 'PM Review',
 value: contract.pmReviewStatus ?? 'Pending',
 ),
 _PackageMetricChip(
 label: 'Sponsor',
 value: contract.sponsorApprovalStatus ?? 'Pending',
 ),
 _PackageMetricChip(
 label: 'Procurement',
 value: contract.procurementHandoffStatus ?? 'Not issued',
 ),
 ],
 ),
 const SizedBox(height: 12),
 if (!ready)
 Container(
 width: double.infinity,
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: const Color(0xFFFFFBEB),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFFDE68A)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: missingReasons
 .map((reason) => Padding(
 padding: const EdgeInsets.only(bottom: 6),
 child: Text(
 '• $reason',
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF92400E)),
 ),
 ))
 .toList(),
 ),
 ),
 Column(
 children: readinessChecks
 .map((check) => Padding(
 padding: const EdgeInsets.only(bottom: 8),
 child: Row(
 children: [
 Icon(
 check.value
 ? Icons.check_circle
 : Icons.radio_button_unchecked,
 size: 16,
 color: check.value
 ? const Color(0xFF059669)
 : const Color(0xFF9CA3AF),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 check.key,
 style: const TextStyle(
 fontSize: 13, color: Color(0xFF374151)),
 ),
 ),
 ],
 ),
 ))
 .toList(),
 ),
 const SizedBox(height: 8),
 Row(
 mainAxisAlignment: MainAxisAlignment.end,
 children: [
 if (!ready &&
 ((contract.linkedFepScopeId ?? '').trim().isEmpty))
 TextButton(
 onPressed: () => _showEditPackageDialog(context, contract),
 child: const Text('Fix Package'),
 ),
 if (!ready &&
 (((contract.recommendedVendor ?? '').trim().isEmpty) ||
 (contract.pmReviewStatus ?? '').toLowerCase() !=
 'approved' ||
 (contract.sponsorApprovalStatus ?? '').toLowerCase() !=
 'approved'))
 TextButton(
 onPressed: () async {
 final rfqs = await PlanningContractingService.streamRfqs(
 contract.projectId,
 ).first;
 if (!context.mounted) return;
 await _showEvaluationDialog(
 context,
 contract,
 rfqs.where((rfq) => rfq.linkedScopeId == contract.id).toList(),
 );
 },
 child: const Text('Open Evaluation'),
 ),
 OutlinedButton.icon(
 onPressed: readyForProcurement
 ? () async {
 await _issuePackageToProcurement(context, contract);
 }
 : null,
 icon: const Icon(Icons.assignment_turned_in_outlined, size: 16),
 label: Text(
 procurementIssued
 ? 'Update Procurement Handoff'
 : 'Issue to Procurement',
 ),
 ),
 const SizedBox(width: 10),
 ElevatedButton.icon(
 onPressed: ready && !alreadySent
 ? () async {
 await ContractService.updatePlanningFields(
 projectId: contract.projectId,
 contractId: contract.id,
 handoffStatus: 'Sent to Execution',
 handoffReadyAt: DateTime.now(),
 );
 }
 : null,
 icon: const Icon(Icons.send_outlined, size: 16),
 label:
 Text(alreadySent ? 'Sent to Execution' : 'Send to Execution'),
 style: ElevatedButton.styleFrom(
 backgroundColor: _kBrandYellow,
 foregroundColor: Colors.white,
 disabledBackgroundColor: const Color(0xFFE5E7EB),
 disabledForegroundColor: const Color(0xFF9CA3AF),
 ),
 ),
 ],
 ),
 ],
 ),
 );
 }
}

// ─── RFP TAB ─────────────────────────────────────────────────────────────────

class _RfpTab extends StatefulWidget {
 const _RfpTab();
 @override
 State<_RfpTab> createState() => _RfpTabState();
}

class _RfpTabState extends State<_RfpTab> {
 @override
 Widget build(BuildContext context) {
 final projectId = ProjectDataHelper.getData(context).projectId;
 if (projectId == null || projectId.isEmpty) {
 return const _EmptyPanel('No project selected.');
 }
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.end,
 children: [
 ElevatedButton.icon(
 onPressed: () => _showRfpDialog(context, projectId),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Create RFP',
 style: TextStyle(fontWeight: FontWeight.w600)),
 style: ElevatedButton.styleFrom(
 backgroundColor: _kBrandYellow,
 foregroundColor: Colors.white,
 padding:
 const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 elevation: 0,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 StreamBuilder<List<PlanningRfq>>(
 stream: PlanningContractingService.streamRfqs(projectId),
 builder: (context, snap) {
 final rfqs = snap.data ?? const [];
 return StreamBuilder<List<ContractModel>>(
 stream: ContractService.streamContracts(projectId),
 builder: (context, packageSnap) {
 final packages = packageSnap.data ?? const [];
 if (rfqs.isEmpty) {
 return const _SectionCard(
 title: 'Requests for Proposal',
 subtitle:
 'Create RFPs linked to FEP scopes and invite contractors',
 child: _EmptyPanel(
 'No RFPs created yet. Click "Create RFP" to start.'),
 );
 }
 return _SectionCard(
 title: 'Requests for Proposal',
 subtitle: '${rfqs.length} RFP(s) created',
 child: Column(
 children: rfqs
 .map((rfq) => _RfqRow(
 rfq: rfq,
 projectId: projectId,
 packages: packages,
 ))
 .toList(),
 ),
 );
 },
 );
 },
 ),
 ],
 );
 }
}

class _RfqRow extends StatelessWidget {
 const _RfqRow({
 required this.rfq,
 required this.projectId,
 required this.packages,
 });
 final PlanningRfq rfq;
 final String projectId;
 final List<ContractModel> packages;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.symmetric(vertical: 8),
 child: Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Text(rfq.title,
 style: const TextStyle(
 fontSize: 13, fontWeight: FontWeight.w700))),
 // The RFP package, downloaded to send out (Lusaka 27 follow-up:
 // "that page could be downloaded where you can download it and send
 // it out to the folks. You could just email from here").
 IconButton(
 onPressed: () => _exportRfpPackage(context, rfq),
 icon: const Icon(Icons.download_outlined, size: 18),
 tooltip: 'Download RFP package (PDF)',
 ),
 IconButton(
 onPressed: () =>
 _showRfpDialog(context, projectId, existingRfq: rfq),
 icon: const Icon(Icons.edit_outlined, size: 18),
 tooltip: 'Edit RFP',
 ),
 _StatusChip(
 label: rfq.status,
 color: _rfqStatusColor(rfq.status),
 ),
 ],
 ),
 const SizedBox(height: 8),
 if (rfq.scopeOfWork.isNotEmpty)
 Text(rfq.scopeOfWork,
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 style:
 const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
 const SizedBox(height: 10),
 Wrap(
 spacing: 10,
 runSpacing: 10,
 children: [
 _PackageMetricChip(
 label: 'Linked Package',
 value: _packageLabelForRfq(rfq, packages),
 ),
 _PackageMetricChip(
 label: 'Bid Due',
 value: rfq.submissionDeadline != null
 ? DateFormat('MMM dd, yyyy').format(rfq.submissionDeadline!)
 : 'No deadline',
 ),
 _PackageMetricChip(
 label: 'Pre-Bid',
 value: rfq.prebidMeetingDate != null
 ? DateFormat('MMM dd, yyyy').format(rfq.prebidMeetingDate!)
 : 'Not set',
 ),
 _PackageMetricChip(
 label: 'Bidders',
 value: '${rfq.invitedContractors.length}',
 ),
 _PackageMetricChip(
 label: 'Criteria',
 value: '${rfq.evaluationCriteria.length}',
 ),
 ],
 ),
 ],
 ),
 ),
 );
 }
}

/// The RFP package as one downloadable PDF (Lusaka 27 follow-up).
///
/// The owner's framing: the package carries "this is the RFP, this is all the
/// details, this is all the code and technology it has to meet, and this is
/// the scope of work" — scope, the requirements mapped to codes/standards for
/// the linked scope, invited bidders, evaluation criteria and the key dates —
/// so it can be saved and emailed to bidders without retyping anything.
Future<void> _exportRfpPackage(BuildContext context, PlanningRfq rfq) async {
 final data = ProjectDataHelper.getData(context);
 final project = data.projectName.isEmpty ? 'Project' : data.projectName;

 // Requirements + codes/standards: the design-phase requirement rows whose
 // mapped scope matches the RFP's linked scope; when the RFP has no linked
 // scope, every mapped requirement (the owner: "whatever that scope is, all
 // requirements associated with that scope needs to be here").
 final requirements = <RequirementRow>[];
 try {
 final impl = await DesignPhaseService.instance
 .loadRequirementsImplementation(rfq.projectId);
 final rows = (impl['requirements'] as List?)
 ?.map((e) =>
 RequirementRow.fromMap(Map<String, dynamic>.from(e as Map)))
 .toList() ??
 const <RequirementRow>[];
 final linked = rfq.linkedScopeId.trim().toLowerCase();
 for (final row in rows) {
 final mapped = row.validationStatus.toLowerCase() != 'unmapped';
 if (!mapped) continue;
 if (linked.isEmpty ||
 (row.designArtifactLabel.toLowerCase().contains(linked)) ||
 row.title.toLowerCase().contains(linked)) {
 requirements.add(row);
 }
 }
 } catch (e) {
 debugPrint('RFP package requirement load failed: $e');
 }

 final dateFormat = DateFormat('MMM dd, yyyy');
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'RFP Package — ${rfq.title}',
 filenamePrefix: 'rfp_package',
 sections: [
 PdfSection.keyValue('RFP Details', [
 {'RFP': rfq.title},
 {'Status': rfq.status},
 {'Project': project},
 {
 'Scope of Work':
 rfq.scopeOfWork.isEmpty ? 'Not recorded.' : rfq.scopeOfWork
 },
 ]),
 PdfSection.keyValue('Key Dates', [
 {
 'Submissions Due': rfq.submissionDeadline == null
 ? 'No deadline'
 : dateFormat.format(rfq.submissionDeadline!),
 },
 {
 'Pre-Bid Meeting': rfq.prebidMeetingDate == null
 ? 'Not set'
 : dateFormat.format(rfq.prebidMeetingDate!),
 },
 ]),
 PdfSection.keyValue('Invited Bidders', [
 for (final bidder in rfq.invitedContractors) {'Bidder': bidder},
 if (rfq.invitedContractors.isEmpty) {'Bidders': 'None invited yet.'},
 ]),
 if (requirements.isNotEmpty)
 PdfSection.table(
 'Requirements & Codes/Standards',
 headers: const ['ID', 'Requirement', 'Type', 'Codes/Standards'],
 rows: [
 for (final row in requirements)
 [
 row.requirementId.isEmpty ? row.id : row.requirementId,
 row.title,
 row.requirementType,
 row.sourceDocument.isEmpty
 ? row.designArtifactLabel
 : row.sourceDocument,
 ],
 ],
 ),
 if (rfq.evaluationCriteria.isNotEmpty)
 PdfSection.table(
 'Evaluation Criteria',
 headers: const ['Criterion', 'Weight'],
 rows: [
 for (final criteria in rfq.evaluationCriteria)
 [criteria.name, '${criteria.weight}'],
 ],
 ),
 PdfSection.text(
 'Notes',
 rfq.notes.isEmpty ? 'No notes recorded.' : rfq.notes),
 ],
 );
}

Color _rfqStatusColor(String s) {
 final l = s.toLowerCase();
 if (l.contains('award') || l.contains('complete')) {
 return const Color(0xFF22C55E);
 }
 if (l.contains('publish') || l.contains('active')) {
 return const Color(0xFFFFC812);
 }
 if (l.contains('evaluat')) return const Color(0xFFF59E0B);
 return const Color(0xFF64748B);
}

void _showRfpDialog(
 BuildContext context,
 String projectId, {
 PlanningRfq? existingRfq,
}) {
 final titleCtrl = SpellCheckTextEditingController(text: existingRfq?.title ?? '');
 final scopeCtrl =
 SpellCheckTextEditingController(text: existingRfq?.scopeOfWork ?? '');
 final notesCtrl = SpellCheckTextEditingController(text: existingRfq?.notes ?? '');
 final vendorsCtrl = SpellCheckTextEditingController(
 text: (existingRfq?.invitedContractors ?? const []).join(', '));
 String linkedPackageId = existingRfq?.linkedScopeId ?? '';
 String rfqStatus = existingRfq?.status ?? 'Draft';
 DateTime? submissionDeadline = existingRfq?.submissionDeadline;
 DateTime? preBidMeetingDate = existingRfq?.prebidMeetingDate;  List<EvaluationCriteria> criteria = existingRfq != null
      ? List<EvaluationCriteria>.from(existingRfq.evaluationCriteria)
      : List<EvaluationCriteria>.from(_defaultEvaluationCriteria);

 bool isSaving = false;

 showDialog(
 context: context,
 builder: (dCtx) => StatefulBuilder(
 builder: (dCtx, setDialog) => AlertDialog(
 title: Text(existingRfq == null ? 'Create RFP' : 'Edit RFP'),
 content: SizedBox(
 width: MediaQuery.of(dCtx).size.width > 600 ? 620 : null,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 FutureBuilder<List<ContractModel>>(
 future: ContractService.streamContracts(projectId).first,
 builder: (context, snap) {
 final packages = snap.data ?? const [];
 return DropdownButtonFormField<String>(
 initialValue: linkedPackageId.isNotEmpty ? linkedPackageId : null,
 isExpanded: true,
 items: packages
 .map((pkg) => DropdownMenuItem(
 value: pkg.id, child: Text(pkg.name)))
 .toList(),
 onChanged: (value) => setDialog(() => linkedPackageId = value ?? ''),
 decoration: const InputDecoration(
 labelText: 'Linked Package',
 border: OutlineInputBorder(),
 ),
 );
 },
 ),
 const SizedBox(height: 14),
 VoiceTextField(
 controller: titleCtrl,
 decoration: const InputDecoration(
 labelText: 'RFP Title *', border: OutlineInputBorder())),
 const SizedBox(height: 14),
 VoiceTextField(
 controller: scopeCtrl,
 maxLines: 4,
 decoration: const InputDecoration(
 labelText: 'Scope of Work',
 border: OutlineInputBorder())),
 const SizedBox(height: 14),
 DropdownButtonFormField<String>(
 initialValue: rfqStatus,
 isExpanded: true,
 items: const [
 DropdownMenuItem(value: 'Draft', child: Text('Draft')),
 DropdownMenuItem(
 value: 'Published', child: Text('Published')),
 DropdownMenuItem(
 value: 'Evaluation', child: Text('Evaluation')),
 DropdownMenuItem(value: 'Awarded', child: Text('Awarded')),
 ],
 onChanged: (value) =>
 setDialog(() => rfqStatus = value ?? 'Draft'),
 decoration: const InputDecoration(
 labelText: 'RFP Status',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 14),
 VoiceTextField(
 controller: vendorsCtrl,
 maxLines: 2,
 decoration: const InputDecoration(
 labelText: 'Invited Bidders',
 hintText: 'Comma-separated vendor names',
 border: OutlineInputBorder())),
 const SizedBox(height: 14),
 _EvaluationCriteriaBuilder(
 criteria: criteria,
 onCriteriaChanged: (newCriteria) {
 setDialog(() => criteria = newCriteria);
 },
 ),
 const SizedBox(height: 14),
 Row(
 children: [
 Expanded(
 child: OutlinedButton.icon(
 onPressed: () async {
 final picked = await showDatePicker(
 context: dCtx,
 initialDate: submissionDeadline ?? DateTime.now(),
 firstDate: DateTime(2000),
 lastDate: DateTime(2100),
 );
 if (picked != null) {
 setDialog(() => submissionDeadline = picked);
 }
 },
 icon: const Icon(Icons.schedule_outlined, size: 16),
 label: Text(
 'Bid Due: ${_formatDateLabel(submissionDeadline)}',
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: OutlinedButton.icon(
 onPressed: () async {
 final picked = await showDatePicker(
 context: dCtx,
 initialDate: preBidMeetingDate ?? DateTime.now(),
 firstDate: DateTime(2000),
 lastDate: DateTime(2100),
 );
 if (picked != null) {
 setDialog(() => preBidMeetingDate = picked);
 }
 },
 icon: const Icon(Icons.groups_outlined, size: 16),
 label: Text(
 'Pre-Bid: ${_formatDateLabel(preBidMeetingDate)}',
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 14),
 VoiceTextField(
 controller: notesCtrl,
 maxLines: 2,
 decoration: const InputDecoration(
 labelText: 'Notes', border: OutlineInputBorder())),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
 if (existingRfq != null)
 TextButton(
 onPressed: () async {
 await PlanningContractingService.deleteRfq(
 projectId,
 existingRfq.id,
 );
 if (dCtx.mounted) Navigator.pop(dCtx);
 },
 child: const Text('Delete'),
 ),
 ElevatedButton(
 onPressed: () async {
 if (titleCtrl.text.trim().isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('RFP title is required.')),
 );
 return;
 }
 if (isSaving) return;
 setDialog(() => isSaving = true);
 try {
 final now = DateTime.now();
 final invited = vendorsCtrl.text
 .split(',')
 .map((name) => name.trim())
 .where((name) => name.isNotEmpty)
 .toList();

 if (existingRfq == null) {
 await PlanningContractingService.createRfq(PlanningRfq(
 id: '',
 projectId: projectId,
 title: titleCtrl.text.trim(),
 scopeOfWork: scopeCtrl.text.trim(),
 linkedScopeId: linkedPackageId,
 invitedContractors: invited,
 evaluationCriteria: criteria,
 submissionDeadline: submissionDeadline,
 prebidMeetingDate: preBidMeetingDate,
 status: rfqStatus,
 notes: notesCtrl.text.trim(),
 createdAt: now,
 updatedAt: now,
 ));
 } else {
 await PlanningContractingService.updateRfq(
 projectId,
 existingRfq.id,
 {
 'title': titleCtrl.text.trim(),
 'scopeOfWork': scopeCtrl.text.trim(),
 'linkedScopeId': linkedPackageId,
 'invitedContractors': invited,
 'evaluationCriteria':
 criteria.map((item) => item.toMap()).toList(),
 'submissionDeadline': submissionDeadline != null
 ? Timestamp.fromDate(submissionDeadline!)
 : null,
 'prebidMeetingDate': preBidMeetingDate != null
 ? Timestamp.fromDate(preBidMeetingDate!)
 : null,
 'status': rfqStatus,
 'notes': notesCtrl.text.trim(),
 },
 );
 }
 if (linkedPackageId.isNotEmpty) {
 final linkedContract = await ContractService.getContract(
 projectId: projectId,
 contractId: linkedPackageId,
 );
 await ContractService.updatePlanningFields(
 projectId: projectId,
 contractId: linkedPackageId,
 linkedScheduleMilestoneIds: _mergeMilestoneIds(
 linkedContract?.linkedScheduleMilestoneIds,
 [
 _scheduleMilestoneId(linkedPackageId, 'pre_bid_meeting'),
 _scheduleMilestoneId(linkedPackageId, 'bid_due'),
 ],
 ),
 );
 await _upsertScheduleMilestoneActivity(
 context: context,
 milestoneId:
 _scheduleMilestoneId(linkedPackageId, 'pre_bid_meeting'),
 title: '${titleCtrl.text.trim()} Pre-Bid Meeting',
 date: preBidMeetingDate,
 );
 await _upsertScheduleMilestoneActivity(
 context: context,
 milestoneId: _scheduleMilestoneId(linkedPackageId, 'bid_due'),
 title: '${titleCtrl.text.trim()} Bid Due',
 date: submissionDeadline,
 predecessorIds: preBidMeetingDate != null
 ? [
 _scheduleMilestoneId(
 linkedPackageId, 'pre_bid_meeting')
 ]
 : const [],
 );
 }
 if (dCtx.mounted) {
 Navigator.pop(dCtx);
 }
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(existingRfq == null
 ? 'RFP created successfully.'
 : 'RFP updated successfully.'),
 backgroundColor: const Color(0xFF16A34A),
 ),
 );
 } catch (e) {
 if (dCtx.mounted) setDialog(() => isSaving = false);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Unable to save RFP: $e'),
 backgroundColor: Colors.red,
 ),
 );
 }
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: _kBrandYellow,
 foregroundColor: Colors.white),
 child: isSaving
 ? const SizedBox(
 width: 20,
 height: 20,
 child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
 : Text(existingRfq == null ? 'Create' : 'Save',
 style: const TextStyle(fontWeight: FontWeight.w600)),
 ),
 ],
 ),
 ),
 );
}

// ─── EVALUATION TAB ──────────────────────────────────────────────────────────

class _EvaluationTab extends StatefulWidget {
 const _EvaluationTab();
 @override
 State<_EvaluationTab> createState() => _EvaluationTabState();
}

class _EvaluationTabState extends State<_EvaluationTab> {
 @override
 Widget build(BuildContext context) {
 final projectId = ProjectDataHelper.getData(context).projectId;
 if (projectId == null || projectId.isEmpty) {
 return const _EmptyPanel('No project selected.');
 }
 return StreamBuilder<List<ContractModel>>(
 stream: ContractService.streamContracts(projectId),
 builder: (context, contractSnap) {
 final contracts = contractSnap.data ?? const [];
 if (contracts.isEmpty) {
 return const _SectionCard(
 title: 'Bid Evaluation Matrix',
 subtitle: 'Score vendor responses against weighted criteria',
 child: _EmptyPanel('Add contracts first to set up evaluations.'),
 );
 }
 return StreamBuilder<List<PlanningRfq>>(
 stream: PlanningContractingService.streamRfqs(projectId),
 builder: (context, rfqSnap) {
 final rfqs = rfqSnap.data ?? const [];
 return _SectionCard(
 title: 'Bid Evaluation Matrix',
 subtitle:
 'Score vendor responses against weighted criteria per contract',
 child: Column(
 children: contracts
 .map((c) => _EvaluationContractRow(
 contract: c,
 rfqs: rfqs
 .where((rfq) => rfq.linkedScopeId == c.id)
 .toList(),
 ))
 .toList(),
 ),
 );
 },
 );
 },
 );
 }
}

PlanningRfq? _selectedRfqForContract(
 ContractModel contract,
 List<PlanningRfq> rfqs,
) {
 if (rfqs.isEmpty) return null;
 final linkedRfqId = contract.linkedRfqId ?? '';
 for (final rfq in rfqs) {
 if (rfq.id == linkedRfqId) return rfq;
 }
 return rfqs.first;
}

String _packageLabelForRfq(PlanningRfq rfq, List<ContractModel> packages) {
 if (rfq.linkedScopeId.isEmpty) return 'Not linked';
 for (final package in packages) {
 if (package.id == rfq.linkedScopeId) {
 return package.name;
 }
 }
 return rfq.linkedScopeId;
}

String _formatCriteriaEditor(List<EvaluationCriteria> criteria) {
 return criteria
 .map((item) => '${item.name}:${item.weight.toStringAsFixed(0)}:${item.category}')
 .join('\n');
}

List<EvaluationCriteria> _parseCriteriaEditor(String rawText) {
 return rawText
 .split('\n')
 .map((line) => line.trim())
 .where((line) => line.isNotEmpty)
 .map((line) {
 final parts = line.split(':');
 final name = parts[0].trim();
 final weight =
 parts.length > 1 ? double.tryParse(parts[1].trim()) ?? 0.0 : 0.0;
 final category =
 parts.length > 2 && parts[2].trim().isNotEmpty
 ? parts[2].trim()
 : 'Technical';
 return EvaluationCriteria(
 id: name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
 name: name,
 weight: weight,
 category: category,
 );
 })
 .toList();
}

List<String> _vendorCandidatesForEvaluation(
 ContractModel contract,
 PlanningRfq? rfq,
) {
 final vendors = <String>{
 ...?rfq?.invitedContractors,
 ...(contract.evaluationScores ?? const [])
 .map((score) => score.vendorName)
 .where((name) => name.trim().isNotEmpty),
 ...(contract.technicalScreenings ?? const [])
 .map((item) => item.vendorName)
 .where((name) => name.trim().isNotEmpty),
 if ((contract.recommendedVendor ?? '').trim().isNotEmpty)
 contract.recommendedVendor!.trim(),
 };
 final list = vendors.toList()..sort();
 return list;
}

Map<String, VendorTechnicalScreening> _technicalScreeningMap(
 ContractModel contract,
) {
 return {
 for (final item in contract.technicalScreenings ?? const [])
 item.vendorName: item,
 };
}

double _weightedVendorScore(
 String vendor,
 List<EvaluationCriteria> criteria,
 List<EvaluationScore> scores,
) {
 var total = 0.0;
 for (final criterion in criteria) {
 final matchingScore = scores.where((score) {
 return score.vendorName == vendor && score.criteriaId == criterion.id;
 }).toList();
 if (matchingScore.isEmpty) continue;
 total += matchingScore.last.score * (criterion.weight / 100);
 }
 return total;
}

List<MapEntry<String, double>> _rankVendors(
 List<String> vendors,
 List<EvaluationCriteria> criteria,
 List<EvaluationScore> scores,
) {
 final ranking = vendors
 .map((vendor) => MapEntry(
 vendor,
 _weightedVendorScore(vendor, criteria, scores),
 ))
 .toList();
 ranking.sort((a, b) => b.value.compareTo(a.value));
 return ranking;
}

class _EvaluationContractRow extends StatelessWidget {
 const _EvaluationContractRow({
 required this.contract,
 required this.rfqs,
 });
 final ContractModel contract;
 final List<PlanningRfq> rfqs;

 @override
 Widget build(BuildContext context) {
 final scores = contract.evaluationScores ?? [];
 final selectedRfq = _selectedRfqForContract(contract, rfqs);
 final criteria = selectedRfq?.evaluationCriteria ?? const <EvaluationCriteria>[];
 final vendors = _vendorCandidatesForEvaluation(contract, selectedRfq);
 final technicalScreenings = _technicalScreeningMap(contract);
 final passedVendors = vendors
 .where((vendor) =>
 (technicalScreenings[vendor]?.status ?? 'Pending').toLowerCase() ==
 'passed')
 .toList();
 final ranking = _rankVendors(passedVendors, criteria, scores);
 return ExpansionTile(
 tilePadding: EdgeInsets.zero,
 title: Row(
 children: [
 Expanded(
 child: Text(contract.name,
 style:
 const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
 ),
 _StatusChip(
 label: scores.isEmpty ? 'No Scores' : '${scores.length} scores',
 color: scores.isEmpty
 ? const Color(0xFF64748B)
 : _kBrandYellow,
 ),
 const SizedBox(width: 8),
 TextButton.icon(
 onPressed: () => _showEvaluationDialog(context, contract, rfqs),
 icon: const Icon(Icons.tune, size: 16),
 label: const Text('Edit'),
 style:
 TextButton.styleFrom(foregroundColor: _kBrandYellow),
 ),
 ],
 ),
 children: [
 Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: Wrap(
 spacing: 10,
 runSpacing: 10,
 children: [
 _PackageMetricChip(
 label: 'Technical Gate',
 value: contract.technicalGateStatus ?? 'Not set',
 ),
 _PackageMetricChip(
 label: 'Linked RFP',
 value: selectedRfq?.title ?? 'Not linked',
 ),
 _PackageMetricChip(
 label: 'Criteria',
 value: criteria.isEmpty ? '0' : '${criteria.length}',
 ),
 _PackageMetricChip(
 label: 'Technically Passed',
 value: '${passedVendors.length}',
 ),
 _PackageMetricChip(
 label: 'Recommended Vendor',
 value: contract.recommendedVendor ?? 'TBD',
 ),
 _PackageMetricChip(
 label: 'Award Value',
 value: contract.recommendedAwardValue != null
 ? '\$${_formatCurrency(contract.recommendedAwardValue!)}'
 : 'TBD',
 ),
 _PackageMetricChip(
 label: 'PM Review',
 value: contract.pmReviewStatus ?? 'Pending',
 ),
 _PackageMetricChip(
 label: 'Sponsor Approval',
 value: contract.sponsorApprovalStatus ?? 'Pending',
 ),
 ],
 ),
 ),
 if (contract.vendorComparisonSummary?.isNotEmpty == true)
 Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: Align(
 alignment: Alignment.centerLeft,
 child: Text(contract.vendorComparisonSummary!,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF4B5563), height: 1.4)),
 ),
 ),
 if (scores.isEmpty)
 const Padding(
 padding: EdgeInsets.symmetric(vertical: 12),
 child: Text('No evaluation scores recorded yet.',
 style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
 ),
 if (scores.isNotEmpty && criteria.isNotEmpty && ranking.isNotEmpty)
 Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: FullScreenTableWrapper(
 title: 'Vendor Comparison Sheet',
 child: _VendorComparisonTable(
 ranking: ranking,
 criteria: criteria,
 ),
 tableBuilder: (fsContext) => _VendorComparisonTable(
 ranking: ranking,
 criteria: criteria,
 ),
 ),
 ),
 if (scores.isNotEmpty)
 FullScreenTableWrapper(
 title: 'Vendor Evaluation Scores',
 child: _ScoreTable(
 scores: scores,
 criteria: criteria,
 ),
 tableBuilder: (fsContext) => _ScoreTable(
 scores: scores,
 criteria: criteria,
 ),
 ),
 ],
 );
 }
}

Future<void> _showEvaluationDialog(
 BuildContext context,
 ContractModel contract,
 List<PlanningRfq> rfqs,
) async {
 final vendorCtrl =
 SpellCheckTextEditingController(text: contract.recommendedVendor ?? '');
 final awardValueCtrl = SpellCheckTextEditingController(
 text: contract.recommendedAwardValue?.toStringAsFixed(0) ?? '');
 final comparisonCtrl =
 SpellCheckTextEditingController(text: contract.vendorComparisonSummary ?? '');
 final technicalNotesCtrl =
 SpellCheckTextEditingController(text: contract.technicalGateNotes ?? '');
 String selectedRfqId =
 _selectedRfqForContract(contract, rfqs)?.id ?? '';
 final initialCriteria = _selectedRfqForContract(contract, rfqs)?.evaluationCriteria ??
 const <EvaluationCriteria>[];
 final criteriaCtrl = SpellCheckTextEditingController(
 text: _formatCriteriaEditor(initialCriteria),
 );
 final vendorListCtrl = SpellCheckTextEditingController(
 text: _vendorCandidatesForEvaluation(
 contract,
 _selectedRfqForContract(contract, rfqs),
 ).join(', '),
 );
 String technicalGate = contract.technicalGateStatus ?? 'Pending Technical';
 String pmReview = contract.pmReviewStatus ?? 'Pending';
 String sponsorApproval = contract.sponsorApprovalStatus ?? 'Pending';
 final scoreMap = <String, String>{
 for (final score in contract.evaluationScores ?? const [])
 '${score.vendorName}::${score.criteriaId}': score.score == 0
 ? ''
 : score.score.toStringAsFixed(score.score % 1 == 0 ? 0 : 1),
 };
 final screeningMap = <String, VendorTechnicalScreening>{
 for (final item in contract.technicalScreenings ?? const [])
 item.vendorName: item,
 };

 PlanningRfq? selectedRfq() {
 for (final rfq in rfqs) {
 if (rfq.id == selectedRfqId) return rfq;
 }
 return null;
 }

 await showDialog<void>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (dialogContext, setDialog) => AlertDialog(
 title: Text('Evaluation & Approvals: ${contract.name}'),
 content: SizedBox(
 width: MediaQuery.of(dialogContext).size.width > 720 ? 620 : null,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 if (rfqs.isNotEmpty)
 DropdownButtonFormField<String>(
 initialValue: selectedRfqId.isNotEmpty ? selectedRfqId : null,
 items: rfqs
 .map((rfq) => DropdownMenuItem(
 value: rfq.id,
 child: Text(rfq.title),
 ))
 .toList(),
 onChanged: (value) {
 setDialog(() {
 selectedRfqId = value ?? '';
 final nextRfq = selectedRfq();
 criteriaCtrl.text = _formatCriteriaEditor(
 nextRfq?.evaluationCriteria ?? const [],
 );
 vendorListCtrl.text = _vendorCandidatesForEvaluation(
 contract,
 nextRfq,
 ).join(', ');
 });
 },
 decoration: const InputDecoration(
 labelText: 'Linked Tender / RFP',
 border: OutlineInputBorder(),
 ),
 ),
 if (rfqs.isNotEmpty) const SizedBox(height: 14),
 Row(
 children: [
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue: technicalGate,
 items: const [
 DropdownMenuItem(
 value: 'Pending Technical',
 child: Text('Pending Technical')),
 DropdownMenuItem(
 value: 'Passed Technical',
 child: Text('Passed Technical')),
 DropdownMenuItem(
 value: 'Failed Technical',
 child: Text('Failed Technical')),
 ],
 onChanged: (value) => setDialog(() =>
 technicalGate = value ?? 'Pending Technical'),
 decoration: const InputDecoration(
 labelText: 'Technical Gate',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextField(
 controller: awardValueCtrl,
 keyboardType: TextInputType.number,
 decoration: const InputDecoration(
 labelText: 'Recommended Award Value',
 prefixText: '\$',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 14),
 VoiceTextField(
 controller: criteriaCtrl,
 maxLines: 4,
 decoration: const InputDecoration(
 labelText: 'Weighted Criteria',
 hintText: 'One per line. Format: Name:Weight:Category',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 14),
 VoiceTextField(
 controller: vendorListCtrl,
 maxLines: 2,
 decoration: const InputDecoration(
 labelText: 'Vendors In Comparison',
 hintText: 'Comma-separated vendor names',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 14),
 _EvaluationScoreEditor(
 criteria: _parseCriteriaEditor(criteriaCtrl.text),
 vendors: vendorListCtrl.text
 .split(',')
 .map((name) => name.trim())
 .where((name) => name.isNotEmpty)
 .toList(),
 screeningMap: screeningMap,
 scoreMap: scoreMap,
 enabled: technicalGate == 'Passed Technical',
 onScoreChanged: (key, value) {
 setDialog(() => scoreMap[key] = value);
 },
 onTechnicalChanged: (vendor, status, notes) {
 setDialog(() {
 screeningMap[vendor] = VendorTechnicalScreening(
 vendorName: vendor,
 status: status,
 notes: notes,
 );
 });
 },
 ),
 const SizedBox(height: 14),
 VoiceTextField(
 controller: vendorCtrl,
 decoration: const InputDecoration(
 labelText: 'Recommended Vendor',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 14),
 VoiceTextField(
 controller: comparisonCtrl,
 maxLines: 3,
 decoration: const InputDecoration(
 labelText: 'Vendor Comparison Summary',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 14),
 VoiceTextField(
 controller: technicalNotesCtrl,
 maxLines: 2,
 decoration: const InputDecoration(
 labelText: 'Technical Notes',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 14),
 Row(
 children: [
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue: pmReview,
 items: const [
 DropdownMenuItem(
 value: 'Pending', child: Text('Pending')),
 DropdownMenuItem(
 value: 'Approved', child: Text('Approved')),
 DropdownMenuItem(
 value: 'Rejected', child: Text('Rejected')),
 ],
 onChanged: (value) =>
 setDialog(() => pmReview = value ?? 'Pending'),
 decoration: const InputDecoration(
 labelText: 'PM Review',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue: sponsorApproval,
 items: const [
 DropdownMenuItem(
 value: 'Pending', child: Text('Pending')),
 DropdownMenuItem(
 value: 'Approved', child: Text('Approved')),
 DropdownMenuItem(
 value: 'Rejected', child: Text('Rejected')),
 ],
 onChanged: (value) => setDialog(() =>
 sponsorApproval = value ?? 'Pending'),
 decoration: const InputDecoration(
 labelText: 'Sponsor Approval',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 child: const Text('Cancel')),
 ElevatedButton(
 onPressed: () async {
 final now = DateTime.now();
 final parsedCriteria = _parseCriteriaEditor(criteriaCtrl.text);
 final vendors = vendorListCtrl.text
 .split(',')
 .map((name) => name.trim())
 .where((name) => name.isNotEmpty)
 .toList();
 final technicalScreenings = vendors
 .map((vendor) =>
 screeningMap[vendor] ??
 VendorTechnicalScreening(vendorName: vendor))
 .toList();
 final passedVendors = technicalScreenings
 .where((item) => item.status.toLowerCase() == 'passed')
 .map((item) => item.vendorName)
 .toList();
 final evaluationScores = <EvaluationScore>[
 for (final vendor in vendors)
 if (passedVendors.contains(vendor))
 for (final criterion in parsedCriteria)
 if ((scoreMap['$vendor::${criterion.id}'] ?? '')
 .trim()
 .isNotEmpty)
 EvaluationScore(
 vendorName: vendor,
 criteriaId: criterion.id,
 score: double.tryParse(
 scoreMap['$vendor::${criterion.id}']!.trim(),
 ) ??
 0.0,
 notes: '',
 ),
 ];
 final ranking =
 _rankVendors(passedVendors, parsedCriteria, evaluationScores);
 final autoRecommendedVendor = technicalGate == 'Passed Technical' &&
 vendorCtrl.text.trim().isEmpty &&
 ranking.isNotEmpty
 ? ranking.first.key
 : vendorCtrl.text.trim();
 final autoComparison = technicalGate == 'Passed Technical' &&
 comparisonCtrl.text.trim().isEmpty &&
 ranking.isNotEmpty
 ? ranking
 .take(3)
 .map((entry) =>
 '${entry.key} ${entry.value.toStringAsFixed(1)}')
 .join(' | ')
 : comparisonCtrl.text.trim();
 final normalizedPmReview =
 pmReview == 'Approved' && technicalGate != 'Passed Technical'
 ? 'Pending'
 : pmReview;
 final normalizedSponsorApproval =
 sponsorApproval == 'Approved' &&
 (technicalGate != 'Passed Technical' ||
 normalizedPmReview != 'Approved')
 ? 'Pending'
 : sponsorApproval;

 if (selectedRfqId.isNotEmpty) {
 await PlanningContractingService.updateRfq(
 contract.projectId,
 selectedRfqId,
 {
 'evaluationCriteria':
 parsedCriteria.map((item) => item.toMap()).toList(),
 },
 );
 }
 await ContractService.updatePlanningFields(
 projectId: contract.projectId,
 contractId: contract.id,
 linkedRfqId: selectedRfqId,
 evaluationScores: evaluationScores,
 technicalScreenings: technicalScreenings,
 technicalGateStatus: technicalGate,
 technicalGateNotes: technicalNotesCtrl.text.trim(),
 recommendedVendor: autoRecommendedVendor,
 recommendedAwardValue:
 double.tryParse(awardValueCtrl.text.trim()),
 vendorComparisonSummary: autoComparison,
 pmReviewStatus: normalizedPmReview,
 pmReviewDate: normalizedPmReview == 'Approved' ? now : null,
 sponsorApprovalStatus: normalizedSponsorApproval,
 sponsorApprovalDate:
 normalizedSponsorApproval == 'Approved' ? now : null,
 handoffStatus: normalizedSponsorApproval == 'Approved'
 ? 'Ready for Handoff'
 : 'Draft',
 handoffReadyAt:
 normalizedSponsorApproval == 'Approved' ? now : null,
 linkedScheduleMilestoneIds: _mergeMilestoneIds(
 contract.linkedScheduleMilestoneIds,
 [
 _scheduleMilestoneId(contract.id, 'pm_review'),
 _scheduleMilestoneId(contract.id, 'sponsor_approval'),
 ],
 ),
 );
 await _upsertScheduleMilestoneActivity(
 context: context,
 milestoneId: _scheduleMilestoneId(contract.id, 'pm_review'),
 title: '${contract.name} PM Review',
 date: normalizedPmReview == 'Approved' ? now : null,
 predecessorIds: const [],
 );
 await _upsertScheduleMilestoneActivity(
 context: context,
 milestoneId:
 _scheduleMilestoneId(contract.id, 'sponsor_approval'),
 title: '${contract.name} Sponsor Approval',
 date: normalizedSponsorApproval == 'Approved' ? now : null,
 predecessorIds: normalizedPmReview == 'Approved'
 ? [_scheduleMilestoneId(contract.id, 'pm_review')]
 : const [],
 );
 if (dialogContext.mounted) {
 Navigator.of(dialogContext).pop();
 }
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Saved evaluation updates for ${contract.name}.'),
 backgroundColor: const Color(0xFF16A34A),
 ),
 );
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: _kBrandYellow,
 foregroundColor: Colors.white),
 child: const Text('Save Evaluation'),
 ),
 ],
 ),
 ),
 );
}

class _ScoreTable extends StatelessWidget {
 const _ScoreTable({
 required this.scores,
 required this.criteria,
 });
 final List<EvaluationScore> scores;
 final List<EvaluationCriteria> criteria;

 @override
 Widget build(BuildContext context) {
 return Table(
 columnWidths: const {
 0: FlexColumnWidth(2),
 1: FlexColumnWidth(2),
 2: FlexColumnWidth(1),
 3: FlexColumnWidth(2),
 },
 children: [
 TableRow(
 decoration: BoxDecoration(color: Colors.grey[100]),
 children: const [
 _TableHeaderCell('Vendor'),
 _TableHeaderCell('Criteria'),
 _TableHeaderCell('Score'),
 _TableHeaderCell('Notes'),
 ],
 ),
 ...scores.map((s) => TableRow(children: [
 _TableCell(
 WrappedText(s.vendorName, style: const TextStyle(fontSize: 12))),
 _TableCell(
 WrappedText(
 criteria
 .where((criterion) => criterion.id == s.criteriaId)
 .map((criterion) => criterion.name)
 .firstOrNull ??
 s.criteriaId,
 style: const TextStyle(fontSize: 12),
 )),
 _TableCell(WrappedText(s.score.toStringAsFixed(1),
 style: const TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600))),
 _TableCell(WrappedText(s.notes,
 style:
 const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
 ])),
 ],
 );
 }
}

class _VendorComparisonTable extends StatelessWidget {
 const _VendorComparisonTable({
 required this.ranking,
 required this.criteria,
 });

 final List<MapEntry<String, double>> ranking;
 final List<EvaluationCriteria> criteria;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Vendor Comparison Sheet',
 style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
 ),
 const SizedBox(height: 6),
 Text(
 'Weighted against ${criteria.length} criteria.',
 style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 10),
 Table(
 columnWidths: const {
 0: FlexColumnWidth(2),
 1: FlexColumnWidth(1),
 },
 children: [
 TableRow(
 decoration: BoxDecoration(color: Colors.grey[100]),
 children: const [
 _TableHeaderCell('Vendor'),
 _TableHeaderCell('Weighted Score'),
 ],
 ),
 ...ranking.map((entry) => TableRow(children: [
 _TableCell(WrappedText(entry.key,
 style: const TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600))),
 _TableCell(WrappedText(entry.value.toStringAsFixed(1),
 style: const TextStyle(fontSize: 12))),
 ])),
 ],
 ),
 ],
 ),
 );
 }
}

class _EvaluationScoreEditor extends StatelessWidget {
 const _EvaluationScoreEditor({
 required this.criteria,
 required this.vendors,
 required this.screeningMap,
 required this.scoreMap,
 required this.enabled,
 required this.onScoreChanged,
 required this.onTechnicalChanged,
 });

 final List<EvaluationCriteria> criteria;
 final List<String> vendors;
 final Map<String, VendorTechnicalScreening> screeningMap;
 final Map<String, String> scoreMap;
 final bool enabled;
 final void Function(String key, String value) onScoreChanged;
 final void Function(String vendor, String status, String notes)
 onTechnicalChanged;

 @override
 Widget build(BuildContext context) {
 if (criteria.isEmpty || vendors.isEmpty) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: const Text(
 'Add weighted criteria and vendors to capture a comparison sheet.',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 );
 }

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Text(
 'Technical Screening And Weighted Score Matrix',
 style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
 ),
 const SizedBox(width: 8),
 if (!enabled)
 const Expanded(
 child: Text(
 'Commercial comparison is locked until technical review passes.',
 style: TextStyle(fontSize: 12, color: Color(0xFFF59E0B)),
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 ...vendors.map((vendor) {
 final screening =
 screeningMap[vendor] ?? VendorTechnicalScreening(vendorName: vendor);
 return Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Text(
 vendor,
 style: const TextStyle(
 fontSize: 13, fontWeight: FontWeight.w700),
 ),
 ),
 SizedBox(
 width: 170,
 child: DropdownButtonFormField<String>(
 initialValue: screening.status,
 items: const [
 DropdownMenuItem(
 value: 'Pending', child: Text('Pending')),
 DropdownMenuItem(
 value: 'Passed', child: Text('Passed')),
 DropdownMenuItem(
 value: 'Failed', child: Text('Failed')),
 ],
 onChanged: (value) => onTechnicalChanged(
 vendor,
 value ?? 'Pending',
 screening.notes,
 ),
 decoration: const InputDecoration(
 labelText: 'Technical Status',
 border: OutlineInputBorder(),
 isDense: true,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 VoiceTextFormField(
 initialValue: screening.notes,
 onChanged: (value) =>
 onTechnicalChanged(vendor, screening.status, value),
 decoration: const InputDecoration(
 labelText: 'Technical Notes',
 border: OutlineInputBorder(),
 isDense: true,
 ),
 ),
 ],
 ),
 );
 }),
 ...criteria.map((criterion) => Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 '${criterion.name} (${criterion.weight.toStringAsFixed(0)}%)',
 style: const TextStyle(
 fontSize: 13, fontWeight: FontWeight.w700),
 ),
 const SizedBox(height: 2),
 Text(
 criterion.category,
 style:
 const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 10),
 ...vendors.map((vendor) {
 final key = '$vendor::${criterion.id}';
 final technicalStatus =
 screeningMap[vendor]?.status ?? 'Pending';
 return Padding(
 padding: const EdgeInsets.only(bottom: 10),
 child: Row(
 children: [
 Expanded(
 child: Text(vendor,
 style: const TextStyle(fontSize: 12)),
 ),
 const SizedBox(width: 12),
 SizedBox(
 width: 120,
 child: VoiceTextFormField(
 initialValue: scoreMap[key] ?? '',
 enabled: enabled &&
 technicalStatus.toLowerCase() == 'passed',
 keyboardType:
 const TextInputType.numberWithOptions(decimal: true),
 decoration: const InputDecoration(
 labelText: 'Score',
 border: OutlineInputBorder(),
 isDense: true,
 ),
 onChanged: (value) => onScoreChanged(key, value),
 ),
 ),
 ],
 ),
 );
 }),
 ],
 ),
 )),
 ],
 );
 }
}

class _TableHeaderCell extends StatelessWidget {
 const _TableHeaderCell(this.text);
 final String text;
 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.all(8),
 child: Text(text,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFF6B7280))),
 );
 }
}

class _TableCell extends StatelessWidget {
 const _TableCell(this.child);
 final Widget child;
 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
 child: child);
 }
}

// ─── PAYMENTS TAB ────────────────────────────────────────────────────────────

class _PaymentsTab extends StatefulWidget {
 const _PaymentsTab();
 @override
 State<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<_PaymentsTab> {
 @override
 Widget build(BuildContext context) {
 final projectId = ProjectDataHelper.getData(context).projectId;
 if (projectId == null || projectId.isEmpty) {
 return const _EmptyPanel('No project selected.');
 }
 return StreamBuilder<List<ContractModel>>(
 stream: ContractService.streamContracts(projectId),
 builder: (context, snap) {
 final contracts = snap.data ?? const [];
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _PaymentSummaryCards(contracts: contracts),
 const SizedBox(height: 20),
 _SectionCard(
 title: 'Payment Milestones',
 subtitle: 'Define and track payment milestones per contract',
 child: contracts.isEmpty
 ? const _EmptyPanel(
 'Add contracts first to set up payment milestones.')
 : Column(
 children: contracts
 .where((c) =>
 (c.paymentMilestones ?? []).isNotEmpty ||
 c.estimatedValue > 0)
 .map((c) => _PaymentContractExpansion(contract: c))
 .toList(),
 ),
 ),
 ],
 );
 },
 );
 }
}

class _PaymentSummaryCards extends StatelessWidget {
 const _PaymentSummaryCards({required this.contracts});
 final List<ContractModel> contracts;

 @override
 Widget build(BuildContext context) {
 final totalValue =
 contracts.fold<double>(0.0, (t, c) => t + c.estimatedValue);
 final allMilestones = contracts
 .expand((c) => c.paymentMilestones ?? <PaymentMilestone>[])
 .toList();
 final totalPlanned =
 allMilestones.fold<double>(0.0, (t, m) => t + m.amount);
 final paidCount = allMilestones.where((m) => m.status == 'Paid').length;

 return Wrap(
 spacing: 12,
 runSpacing: 12,
 children: [
 _StatCard(
 value: '\$${_formatCurrency(totalValue)}',
 label: 'Total Contract Value',
 color: _kBrandYellow),
 _StatCard(
 value: '\$${_formatCurrency(totalPlanned)}',
 label: 'Milestones Planned',
 color: const Color(0xFF059669)),
 _StatCard(
 value: '\$${_formatCurrency(totalValue - totalPlanned)}',
 label: 'Unplanned',
 color: const Color(0xFFF59E0B)),
 _StatCard(
 value: '$paidCount/${allMilestones.length}',
 label: 'Paid Milestones',
 color: const Color(0xFFB8860B)),
 ],
 );
 }
}

class _PaymentContractExpansion extends StatelessWidget {
 const _PaymentContractExpansion({required this.contract});
 final ContractModel contract;

 @override
 Widget build(BuildContext context) {
 final milestones = contract.paymentMilestones ?? [];
 return ExpansionTile(
 tilePadding: EdgeInsets.zero,
 title: Row(
 children: [
 Expanded(
 child: Text(contract.name,
 style:
 const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
 ),
 Text('\$${_formatCurrency(contract.estimatedValue)}',
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF059669))),
 ],
 ),
 children: [
 if (milestones.isEmpty)
 const Padding(
 padding: EdgeInsets.symmetric(vertical: 12),
 child: Text('No payment milestones defined.',
 style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
 )
 else
 Table(
 columnWidths: const {
 0: FlexColumnWidth(2),
 1: FlexColumnWidth(1.2),
 2: FlexColumnWidth(1),
 3: FlexColumnWidth(1),
 4: FlexColumnWidth(1.2),
 },
 children: [
 TableRow(
 decoration: BoxDecoration(color: Colors.grey[100]),
 children: const [
 _TableHeaderCell('Milestone'),
 _TableHeaderCell('Amount'),
 _TableHeaderCell('% of Total'),
 _TableHeaderCell('Retention'),
 _TableHeaderCell('Status'),
 ],
 ),
 ...milestones.map((m) => TableRow(children: [
 _TableCell(WrappedText(m.name,
 style: const TextStyle(
 fontSize: 12, fontWeight: FontWeight.w500))),
 _TableCell(WrappedText('\$${_formatCurrency(m.amount)}',
 style: const TextStyle(fontSize: 12))),
 _TableCell(WrappedText(
 '${m.percentOfContract.toStringAsFixed(0)}%',
 style: const TextStyle(fontSize: 12))),
 _TableCell(WrappedText('${m.retentionPercent.toStringAsFixed(0)}%',
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF6B7280)))),
 _TableCell(_StatusChip(
 label: m.status, color: _paymentStatusColor(m.status))),
 ])),
 ],
 ),
 ],
 );
 }
}

Color _paymentStatusColor(String s) {
 final l = s.toLowerCase();
 if (l == 'paid') return const Color(0xFF22C55E);
 if (l == 'approved') return const Color(0xFFB8860B);
 if (l == 'submitted') return _kBrandYellow;
 if (l == 'due') return const Color(0xFFF59E0B);
 return const Color(0xFF64748B);
}

// ─── ADMIN TAB ───────────────────────────────────────────────────────────────

class _AdminTab extends StatefulWidget {
 const _AdminTab();
 @override
 State<_AdminTab> createState() => _AdminTabState();
}

class _AdminTabState extends State<_AdminTab> {
 @override
 Widget build(BuildContext context) {
 final projectId = ProjectDataHelper.getData(context).projectId;
 if (projectId == null || projectId.isEmpty) {
 return const _EmptyPanel('No project selected.');
 }
 return StreamBuilder<List<ContractModel>>(
 stream: ContractService.streamContracts(projectId),
 builder: (context, snap) {
 final contracts = snap.data ?? const [];
 if (contracts.isEmpty) {
 return const _SectionCard(
 title: 'Contract Administration',
 subtitle:
 'Assign managers, define change order procedures, dispute resolution, and reporting',
 child:
 _EmptyPanel('Add contracts first to configure administration.'),
 );
 }
 return Column(
 children:
 contracts.map((c) => _AdminContractCard(contract: c)).toList(),
 );
 },
 );
 }
}

class _AdminContractCard extends StatefulWidget {
 const _AdminContractCard({required this.contract});
 final ContractModel contract;

 @override
 State<_AdminContractCard> createState() => _AdminContractCardState();
}

class _AdminContractCardState extends State<_AdminContractCard> {
 @override
 Widget build(BuildContext context) {
 final c = widget.contract;
 final completedCompliance =
 Set<String>.from(c.complianceChecklist ?? const <String>[]);
 return _SectionCard(
 title: c.name,
 subtitle: c.contractorName.isEmpty
 ? 'No contractor assigned'
 : c.contractorName,
 child: Column(
 children: [
 _AdminField(
 label: 'Contract Manager',
 value: c.contractManagerName ?? 'Unassigned',
 options: const ['Unassigned', 'PM', 'Sponsor', 'Contract Manager'],
 onChanged: (v) =>
 _updateField(contractManagerName: v == 'Unassigned' ? '' : v),
 ),
 const SizedBox(height: 14),
 _AdminField(
 label: 'Change Order Procedure',
 value: c.changeOrderProcedure ?? 'Not Set',
 options: const ['Standard', 'Formal Review', 'Custom', 'Not Set'],
 onChanged: (v) => _updateField(changeOrderProcedure: v),
 ),
 const SizedBox(height: 14),
 _AdminField(
 label: 'Dispute Resolution',
 value: c.disputeResolution ?? 'Not Set',
 options: const [
 'Negotiation',
 'Mediation',
 'Arbitration',
 'Litigation',
 'Not Set'
 ],
 onChanged: (v) => _updateField(disputeResolution: v),
 ),
 const SizedBox(height: 14),
 _AdminField(
 label: 'Reporting Frequency',
 value: c.reportingFrequency ?? 'Not Set',
 options: const ['Weekly', 'Bi-weekly', 'Monthly', 'Not Set'],
 onChanged: (v) => _updateField(reportingFrequency: v),
 ),            const SizedBox(height: 18),
            _WarrantyBlock(
              contract: c,
              onChanged: ({warrantyMonths, warrantyExpiryDate, keyDatesNotes}) =>
                  _updateField(
                    warrantyMonths: warrantyMonths,
                    warrantyExpiryDate: warrantyExpiryDate,
                    keyDatesNotes: keyDatesNotes,
                  ),
            ),
            const SizedBox(height: 18),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Pre-Award Compliance Checklist',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            const SizedBox(height: 10),
 Wrap(
 spacing: 12,
 runSpacing: 12,
 children: _defaultComplianceChecklist
 .map(
 (item) => _ComplianceToggle(
 label: item,
 checked: completedCompliance.contains(item),
 onChanged: (checked) async {
 final next = {...completedCompliance};
 if (checked) {
 next.add(item);
 } else {
 next.remove(item);
 }
 await _updateField(
 complianceChecklist: next.toList()..sort(),
 );
 },
 ),
 )
 .toList(),
 ),
 ],
 ),
 );
 }  Future<void> _updateField({
    String? contractManagerName,
    String? changeOrderProcedure,
    String? disputeResolution,
    String? reportingFrequency,
    List<String>? complianceChecklist,
    int? warrantyMonths,
    DateTime? warrantyExpiryDate,
    String? keyDatesNotes,
  }) async {
    final projectId = ProjectDataHelper.getData(context).projectId;
    if (projectId == null) return;
    await ContractService.updatePlanningFields(
      projectId: projectId,
      contractId: widget.contract.id,
      contractManagerName: contractManagerName,
      changeOrderProcedure: changeOrderProcedure,
      disputeResolution: disputeResolution,
      reportingFrequency: reportingFrequency,
      complianceChecklist: complianceChecklist,
      warrantyMonths: warrantyMonths,
      warrantyExpiryDate: warrantyExpiryDate,
      keyDatesNotes: keyDatesNotes,
    );
  }
}

/// Warranty and key dates, captured in Admin Controls **before** award so the
/// terms are known when bids are scored against the warranty/key-date factors.
class _WarrantyBlock extends StatefulWidget {
  const _WarrantyBlock({required this.contract, required this.onChanged});

  final ContractModel contract;
  final Future<void> Function({
    int? warrantyMonths,
    DateTime? warrantyExpiryDate,
    String? keyDatesNotes,
  }) onChanged;

  @override
  State<_WarrantyBlock> createState() => _WarrantyBlockState();
}

class _WarrantyBlockState extends State<_WarrantyBlock> {
  late final TextEditingController _keyDatesController =
      SpellCheckTextEditingController(text: widget.contract.keyDatesNotes ?? '');

  @override
  void dispose() {
    _keyDatesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final months = widget.contract.warrantyMonths ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Warranty & Key Dates (before award)',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Set the warranty period and the dates a bidder must commit to '
            'before the contract is awarded.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(
                width: 180,
                child: Text('Warranty period',
                    style: TextStyle(
                        fontSize: 13, color: Color(0xFF374151))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AdminDropdown<int>(
                  value: months,
                  options: _warrantyMonthOptions,
                  labelFor: (value) =>
                      value == 0 ? 'No warranty' : '$value months',
                  onChanged: (value) => widget.onChanged(
                    warrantyMonths: value,
                    warrantyExpiryDate: _expiryFor(
                        value, widget.contract.targetAwardDate),
                    keyDatesNotes: _keyDatesController.text.trim(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(
                width: 180,
                child: Text('Warranty expires',
                    style: TextStyle(
                        fontSize: 13, color: Color(0xFF374151))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  months == 0 || widget.contract.warrantyExpiryDate == null
                      ? (months == 0
                          ? 'No warranty recorded'
                          : 'Set the award date to derive this')
                      : DateFormat('MMM dd, yyyy')
                          .format(widget.contract.warrantyExpiryDate!),
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF111827)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          VoiceTextField(
            controller: _keyDatesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Key dates',
              hintText:
                  'Milestones and dates a bidder must commit to (mobilisation, '
                  'delivery, handover)',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => widget.onChanged(
              keyDatesNotes: value.trim(),
              warrantyMonths: months,
            ),
          ),
        ],
      ),
    );
  }

  /// The warranty end date, derived from the award date plus the period.
  static DateTime? _expiryFor(int months, DateTime? awardDate) {
    if (months <= 0) return null;
    final anchor = awardDate ?? DateTime.now();
    return DateTime(anchor.year, anchor.month + months, anchor.day);
  }
}

/// A small typed dropdown used by the admin controls.
class _AdminDropdown<T> extends StatelessWidget {
  const _AdminDropdown({
    required this.value,
    required this.options,
    required this.labelFor,
    required this.onChanged,
  });

  final T value;
  final List<T> options;
  final String Function(T value) labelFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButton<T>(
        value: options.contains(value) ? value : options.first,
        items: options
            .map((option) => DropdownMenuItem<T>(
                value: option, child: Text(labelFor(option))))
            .toList(),
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
        underline: const SizedBox.shrink(),
        isDense: true,
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
      ),
    );
  }
}

class _ComplianceToggle extends StatelessWidget {
 const _ComplianceToggle({
 required this.label,
 required this.checked,
 required this.onChanged,
 });

 final String label;
 final bool checked;
 final ValueChanged<bool> onChanged;

 @override
 Widget build(BuildContext context) {
 return InkWell(
 onTap: () => onChanged(!checked),
 borderRadius: BorderRadius.circular(12),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: checked ? const Color(0xFFECFDF5) : const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(
 color: checked ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
 ),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(
 checked ? Icons.check_circle : Icons.radio_button_unchecked,
 size: 16,
 color:
 checked ? const Color(0xFF059669) : const Color(0xFF9CA3AF),
 ),
 const SizedBox(width: 8),
 Text(
 label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF374151),
 ),
 ),
 ],
 ),
 ),
 );
 }
}

class _AdminField extends StatelessWidget {
 const _AdminField({
 required this.label,
 required this.value,
 required this.options,
 required this.onChanged,
 });
 final String label;
 final String value;
 final List<String> options;
 final ValueChanged<String> onChanged;

 @override
 Widget build(BuildContext context) {
 return Row(
 children: [
 SizedBox(
 width: 180,
 child: Text(label,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: Color(0xFF374151))),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: DropdownButton<String>(
 value: options.contains(value) ? value : options.last,
 items: options
 .map((o) => DropdownMenuItem(
 value: o,
 child: Text(o, style: const TextStyle(fontSize: 13))))
 .toList(),
 onChanged: (v) {
 if (v != null) onChanged(v);
 },
 underline: const SizedBox.shrink(),
 isDense: true,
 icon: const Icon(Icons.keyboard_arrow_down, size: 18),
 ),
 ),
 ),
 ],
 );
 }
}

// ─── NEGOTIATION TAB ─────────────────────────────────────────────────────────

class _NegotiationTab extends StatefulWidget {
 const _NegotiationTab();
 @override
 State<_NegotiationTab> createState() => _NegotiationTabState();
}

class _NegotiationTabState extends State<_NegotiationTab> {
 @override
 Widget build(BuildContext context) {
 final projectId = ProjectDataHelper.getData(context).projectId;
 if (projectId == null || projectId.isEmpty) {
 return const _EmptyPanel('No project selected.');
 }
 return StreamBuilder<List<ContractModel>>(
 stream: ContractService.streamContracts(projectId),
 builder: (context, snap) {
 final contracts = snap.data ?? const [];
 if (contracts.isEmpty) {
 return const _SectionCard(
 title: 'Negotiation Planner',
 subtitle:
 'Prepare negotiation objectives, key items, BATNA, and authority levels',
 child: _EmptyPanel('Add contracts first to plan negotiations.'),
 );
 }
 return Column(
 children: contracts
 .map((c) => _NegotiationContractCard(contract: c))
 .toList(),
 );
 },
 );
 }
}

class _NegotiationContractCard extends StatelessWidget {
 const _NegotiationContractCard({required this.contract});
 final ContractModel contract;

 @override
 Widget build(BuildContext context) {
 final items = contract.negotiationItems ?? [];
 return _SectionCard(
 title: contract.name,
 subtitle:
 'Status: ${contract.negotiationStatus ?? "Not Started"} | Authority: ${contract.negotiationAuthority ?? "Not Set"}',
 trailing: TextButton.icon(
 onPressed: () => _showNegotiationDialog(context, contract),
 icon: const Icon(Icons.edit_outlined, size: 16),
 label: Text(items.isEmpty ? 'Add Plan' : 'Edit Plan'),
 style: TextButton.styleFrom(
 foregroundColor: _kBrandYellow,
 ),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (contract.negotiationObjectives != null &&
 contract.negotiationObjectives!.isNotEmpty)
 Padding(
 padding: const EdgeInsets.only(bottom: 14),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('Objectives',
 style:
 TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
 const SizedBox(height: 6),
 Text(contract.negotiationObjectives!,
 style: const TextStyle(
 fontSize: 13, color: Color(0xFF4B5563))),
 ],
 ),
 ),
 if (items.isEmpty)
 const Text(
 'No negotiation items tracked. Use "Add Plan" to capture objectives, positions, and status.',
 style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)))
 else
 Table(
 columnWidths: const {
 0: FlexColumnWidth(1.5),
 1: FlexColumnWidth(1.5),
 2: FlexColumnWidth(1.5),
 3: FlexColumnWidth(1),
 },
 children: [
 TableRow(
 decoration: BoxDecoration(color: Colors.grey[100]),
 children: const [
 _TableHeaderCell('Item'),
 _TableHeaderCell('Our Position'),
 _TableHeaderCell('Their Position'),
 _TableHeaderCell('Status'),
 ],
 ),
 ...items.map((item) => TableRow(children: [
 _TableCell(WrappedText(item.item,
 style: const TextStyle(fontSize: 12))),
 _TableCell(WrappedText(item.ourPosition,
 style: const TextStyle(fontSize: 12))),
 _TableCell(WrappedText(item.theirPosition,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF6B7280)))),
 _TableCell(_StatusChip(
 label: item.status,
 color: _negoStatusColor(item.status))),
 ])),
 ],
 ),
 ],
 ),
 );
 }
}

Color _negoStatusColor(String s) {
 final l = s.toLowerCase();
 if (l == 'agreed' || l == 'won') return const Color(0xFF22C55E);
 if (l == 'compromised') return const Color(0xFFF59E0B);
 if (l == 'conceded') return const Color(0xFFEF4444);
 return const Color(0xFF64748B);
}

Future<void> _showNegotiationDialog(
 BuildContext context,
 ContractModel contract,
) async {
 final objectivesCtrl =
 SpellCheckTextEditingController(text: contract.negotiationObjectives ?? '');
 final itemsCtrl = SpellCheckTextEditingController(
 text: (contract.negotiationItems ?? const [])
 .map((item) =>
 '${item.item}|${item.ourPosition}|${item.theirPosition}|${item.status}')
 .join('\n'),
 );
 String authority = contract.negotiationAuthority ?? 'Not Set';
 String status = contract.negotiationStatus ?? 'Not Started';

 await showDialog<void>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (dialogContext, setDialog) => AlertDialog(
 title: Text('Negotiation Plan: ${contract.name}'),
 content: SizedBox(
 width: MediaQuery.of(dialogContext).size.width > 720 ? 620 : double.maxFinite,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: objectivesCtrl,
 maxLines: 3,
 decoration: const InputDecoration(
 labelText: 'Negotiation Objectives',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 14),
 Row(
 children: [
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue: authority,
 items: const [
 DropdownMenuItem(value: 'Not Set', child: Text('Not Set')),
 DropdownMenuItem(
 value: 'PM Approval', child: Text('PM Approval')),
 DropdownMenuItem(
 value: 'Sponsor Approval',
 child: Text('Sponsor Approval')),
 DropdownMenuItem(
 value: 'Contracts Lead',
 child: Text('Contracts Lead')),
 ],
 onChanged: (value) =>
 setDialog(() => authority = value ?? 'Not Set'),
 decoration: const InputDecoration(
 labelText: 'Authority',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue: status,
 items: const [
 DropdownMenuItem(
 value: 'Not Started', child: Text('Not Started')),
 DropdownMenuItem(
 value: 'In Progress', child: Text('In Progress')),
 DropdownMenuItem(value: 'Agreed', child: Text('Agreed')),
 DropdownMenuItem(value: 'Closed', child: Text('Closed')),
 ],
 onChanged: (value) =>
 setDialog(() => status = value ?? 'Not Started'),
 decoration: const InputDecoration(
 labelText: 'Negotiation Status',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 14),
 VoiceTextField(
 controller: itemsCtrl,
 maxLines: 8,
 decoration: const InputDecoration(
 labelText: 'Negotiation Items',
 hintText:
 'One per line. Format: Item|Our Position|Their Position|Status',
 border: OutlineInputBorder(),
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
 onPressed: () async {
 final items = itemsCtrl.text
 .split('\n')
 .map((line) => line.trim())
 .where((line) => line.isNotEmpty)
 .map((line) {
 final parts = line.split('|');
 final item = parts.isNotEmpty ? parts[0].trim() : '';
 final ourPosition = parts.length > 1 ? parts[1].trim() : '';
 final theirPosition = parts.length > 2 ? parts[2].trim() : '';
 final itemStatus =
 parts.length > 3 && parts[3].trim().isNotEmpty
 ? parts[3].trim()
 : 'Open';
 return NegotiationItem(
 id: item.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
 item: item,
 ourPosition: ourPosition,
 theirPosition: theirPosition,
 status: itemStatus,
 );
 }).where((item) => item.item.trim().isNotEmpty).toList();

 await ContractService.updatePlanningFields(
 projectId: contract.projectId,
 contractId: contract.id,
 negotiationObjectives: objectivesCtrl.text.trim(),
 negotiationAuthority: authority,
 negotiationStatus: status,
 negotiationItems: items,
 );
 if (dialogContext.mounted) {
 Navigator.of(dialogContext).pop();
 }
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content:
 Text('Saved negotiation plan for ${contract.name}.'),
 backgroundColor: const Color(0xFF16A34A),
 ),
 );
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: _kBrandYellow,
 foregroundColor: Colors.white,
 ),
 child: const Text('Save Negotiation'),
 ),
 ],
 ),
 ),
 );
}

// ─── BUDGET TAB ──────────────────────────────────────────────────────────────

class _BudgetTab extends StatefulWidget {
 const _BudgetTab();
 @override
 State<_BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<_BudgetTab> {
 final _searchQuery = '';
 final _saveDebouncer = _Debouncer();

 @override
 void dispose() {
 _saveDebouncer.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 final projectId = ProjectDataHelper.getData(context).projectId;
 if (projectId == null || projectId.isEmpty) {
 return const _EmptyPanel('No project selected.');
 }

 return StreamBuilder<List<ContractModel>>(
 stream: ContractService.streamContracts(projectId),
 builder: (context, snap) {
 final allContracts = snap.data ?? const [];

 final filteredContracts = _searchQuery.isEmpty
 ? allContracts
 : allContracts.where((c) {
 final q = _searchQuery.toLowerCase();
 return c.name.toLowerCase().contains(q);
 }).toList();

 final totalBase = allContracts.fold<double>(0.0, (t, c) => t + c.estimatedValue);
 final totalContingency = allContracts.fold<double>(
 0.0, (t, c) => t + (c.contingencyAmount ?? 0));
 final totalBudget = totalBase + totalContingency;

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Wrap(
 spacing: 12,
 runSpacing: 12,
 children: [
 _StatCard(
 value: '\$${_formatCurrency(totalBase)}',
 label: 'Base Contract Value',
 color: _kBrandYellow),
 _StatCard(
 value: '\$${_formatCurrency(totalContingency)}',
 label: 'Total Contingency',
 color: const Color(0xFFF59E0B)),
 _StatCard(
 value: '\$${_formatCurrency(totalBudget)}',
 label: 'Total Budget',
 color: const Color(0xFF059669)),
 _StatCard(
 value: allContracts.length.toString(),
 label: 'Contracts',
 color: const Color(0xFFB8860B)),
 ],
 ),
 const SizedBox(height: 20),
 _SectionCard(
 title: 'Budget Breakdown',
 subtitle:
 'Detailed contract budget with contingency and tracking',
 child: allContracts.isEmpty
 ? const _EmptyPanel('No contracts to show budget breakdown.')
 : Column(
 children: [
 _SearchField(
 hintText: 'Search contracts...',
 onChanged: (v) {},
 ),
 const SizedBox(height: 16),
 FullScreenTableWrapper(
 title: 'Contract Budget (Editable)',
 child: _BudgetEditableTable(
 contracts: filteredContracts,
 projectId: projectId,
 ),
 tableBuilder: (fsContext) => _BudgetEditableTable(
 contracts: filteredContracts,
 projectId: projectId,
 ),
 ),
 ],
 ),
 ),
 ],
 );
 },
 );
 }
}

void onChangedBaseValue(
 String projectId, String contractId, double estimatedValue) {
 ContractService.updateContract(
 projectId: projectId,
 contractId: contractId,
 estimatedValue: estimatedValue,
 );
}

void onChangedContingencyPercent(
 String projectId, String contractId, double baseValue, double contPct) {
 final contingencyAmount = baseValue * contPct / 100;
 ContractService.updatePlanningFields(
 projectId: projectId,
 contractId: contractId,
 contingencyPercent: contPct,
 contingencyAmount: contingencyAmount,
 );
}

class _SearchField extends StatelessWidget {
 const _SearchField({
 required this.hintText,
 required this.onChanged,
 });

 final String hintText;
 final ValueChanged<String> onChanged;

 @override
 Widget build(BuildContext context) {
 return SizedBox(
 width: 280,
 child: VoiceTextField(
 onChanged: onChanged,
 decoration: InputDecoration(
 hintText: hintText,
 prefixIcon: const Icon(Icons.search, size: 20),
 isDense: true,
 contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(8),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(8),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 ),
 ),
 );
 }
}

class _BudgetEditableTable extends StatelessWidget {
 const _BudgetEditableTable({
 required this.contracts,
 required this.projectId,
 });

 final List<ContractModel> contracts;
 final String projectId;

 void _showEditModal(BuildContext context, ContractModel contract) {
 final baseController = SpellCheckTextEditingController(
 text: contract.estimatedValue.toStringAsFixed(0));
 final pctController = SpellCheckTextEditingController(
 text: (contract.contingencyPercent ?? 0).toStringAsFixed(0));

 showDialog(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (ctx, setDialogState) {
 final base = double.tryParse(baseController.text) ?? 0;
 final pct = double.tryParse(pctController.text) ?? 0;
 final contAmt = base * pct / 100;
 final total = base + contAmt;

 return AlertDialog(
 title: Text('Edit: ${contract.name}'),
 content: SizedBox(
 width: 420,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 TextField(
 controller: baseController,
 keyboardType: TextInputType.number,
 decoration: const InputDecoration(
 labelText: 'Base Value (\$)',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 onChanged: (_) => setDialogState(() {}),
 ),
 const SizedBox(height: 12),
 TextField(
 controller: pctController,
 keyboardType: TextInputType.number,
 decoration: const InputDecoration(
 labelText: 'Contingency (%)',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 onChanged: (_) => setDialogState(() {}),
 ),
 const SizedBox(height: 16),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text('Contingency: \$${contAmt.toStringAsFixed(0)}',
 style: const TextStyle(fontSize: 13, color: Color(0xFFF59E0B))),
 Text('Total: \$${total.toStringAsFixed(0)}',
 style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
 ],
 ),
 ],
 ),
 ),
 actions: [
 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
 ElevatedButton(
 onPressed: () {
 final newBase = double.tryParse(baseController.text) ?? 0;
 final newPct = (double.tryParse(pctController.text) ?? 0).clamp(0.0, 100.0);
 onChangedBaseValue(projectId, contract.id, newBase);
 onChangedContingencyPercent(projectId, contract.id, newBase, newPct);
 Navigator.pop(ctx);
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFD97706),
 foregroundColor: Colors.white,
 ),
 child: const Text('Save'),
 ),
 ],
 );
 },
 ),
 );
 }

 void _showAddModal(BuildContext context) {
 final nameController = SpellCheckTextEditingController();
 final baseController = SpellCheckTextEditingController(text: '0');
 final pctController = SpellCheckTextEditingController(text: '0');

 showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Add Contract Budget'),
 content: SizedBox(
 width: 420,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 TextField(
 controller: nameController,
 decoration: const InputDecoration(
 labelText: 'Contract Name *',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 TextField(
 controller: baseController,
 keyboardType: TextInputType.number,
 decoration: const InputDecoration(
 labelText: 'Base Value (\$)',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 TextField(
 controller: pctController,
 keyboardType: TextInputType.number,
 decoration: const InputDecoration(
 labelText: 'Contingency (%)',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
 ElevatedButton(
 onPressed: () async {
 if (nameController.text.trim().isEmpty) return;
 final base = double.tryParse(baseController.text) ?? 0;
 final pct = (double.tryParse(pctController.text) ?? 0).clamp(0.0, 100.0);
 final contAmt = base * pct / 100;
 await ContractService.createContract(
 projectId: projectId,
 name: nameController.text.trim(),
 description: '',
 contractType: 'fixed_price',
 paymentType: 'milestone',
 status: 'draft',
 estimatedValue: base,
 scope: '',
 discipline: '',
 createdById: '',
 createdByEmail: '',
 createdByName: '',
 );
 Navigator.pop(ctx);
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFD97706),
 foregroundColor: Colors.white,
 ),
 child: const Text('Add'),
 ),
 ],
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 final columns = [
 const _TableColumnDef('#', 50),
 const _TableColumnDef('Contract', 200),
 const _TableColumnDef('Base Value', 120),
 const _TableColumnDef('Contingency %', 100),
 const _TableColumnDef('Contingency', 110),
 const _TableColumnDef('Total', 110),
 const _TableColumnDef('', 60),
 ];

 return Column(
 children: [
 // Add button
 Align(
 alignment: Alignment.centerRight,
 child: Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: OutlinedButton.icon(
 onPressed: () => _showAddModal(context),
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add Contract', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF475569),
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ),
 ),
 _EditableTable(
 columns: columns,
 rows: [
 for (int index = 0; index < contracts.length; index++)
 _BudgetEditableRow(
 key: ValueKey(contracts[index].id),
 columns: columns,
 contract: contracts[index],
 index: index,
 onEdit: () => _showEditModal(context, contracts[index]),
 ),
 ],
 ),
 ],
 );
 }
}

class _BudgetEditableRow extends StatelessWidget {
 const _BudgetEditableRow({
 super.key,
 required this.columns,
 required this.contract,
 required this.index,
 this.onEdit,
 });

 final List<_TableColumnDef> columns;
 final ContractModel contract;
 final int index;
 final VoidCallback? onEdit;

 String get projectId => contract.projectId;

 @override
 Widget build(BuildContext context) {
 final base = contract.estimatedValue;
 final contPct = contract.contingencyPercent ?? 0;
 final contAmt = contract.contingencyAmount ?? (base * contPct / 100);
 final total = base + contAmt;

 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 SizedBox(
 width: columns[0].width,
 child: _TableFieldShell(
 child: Center(
 child: Text(
 '${index + 1}',
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF6B7280),
 ),
 ),
 ),
 ),
 ),
 SizedBox(
 width: columns[1].width,
 child: _TableFieldShell(
 child: Text(
 contract.name,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 ),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ),
 SizedBox(
 width: columns[2].width,
 child: _TableFieldShell(
 child: Text(
 '\$${_formatCurrency(base)}',
 style: const TextStyle(fontSize: 12),
 ),
 ),
 ),
 SizedBox(
 width: columns[3].width,
 child: _TableFieldShell(
 child: Text(
 '${contPct.toStringAsFixed(0)}%',
 style: const TextStyle(fontSize: 12),
 ),
 ),
 ),
 SizedBox(
 width: columns[4].width,
 child: _TableFieldShell(
 child: Text(
 '\$${_formatCurrency(contAmt)}',
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFFF59E0B),
 ),
 ),
 ),
 ),
 SizedBox(
 width: columns[5].width,
 child: _TableFieldShell(
 child: Text(
 '\$${_formatCurrency(total)}',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF059669),
 ),
 ),
 ),
 ),
 SizedBox(
 width: columns[6].width,
 child: _TableFieldShell(
 child: IconButton(
 icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF9CA3AF)),
 onPressed: onEdit,
 tooltip: 'Edit budget',
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(),
 ),
 ),
 ),
 ],
 );
 }
}

class _NumberInputCell extends StatefulWidget {
 const _NumberInputCell({
 required this.value,
 required this.fieldKey,
 required this.onChanged,
 }) : prefix = null, suffix = null;

 final double value;
 final String fieldKey;
 final ValueChanged<double> onChanged;
 final String? prefix;
 final String? suffix;

 @override
 State<_NumberInputCell> createState() => _NumberInputCellState();
}

class _NumberInputCellState extends State<_NumberInputCell> {
 late TextEditingController _controller;

 @override
 void initState() {
 super.initState();
 _controller = SpellCheckTextEditingController(text: widget.value.toStringAsFixed(0));
 }

 @override
 void didUpdateWidget(_NumberInputCell oldWidget) {
 super.didUpdateWidget(oldWidget);
 if (oldWidget.value != widget.value) {
 _controller.text = widget.value.toStringAsFixed(0);
 }
 }

 @override
 void dispose() {
 _controller.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 return VoiceTextField(
 controller: _controller,
 keyboardType: TextInputType.number,
 style: const TextStyle(fontSize: 12),
 decoration: InputDecoration(
 prefixText: widget.prefix,
 suffixText: widget.suffix,
 isDense: true,
 contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(6),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(6),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 ),
 onSubmitted: (text) {
 final parsed = double.tryParse(text) ?? 0;
 widget.onChanged(parsed);
 },
 onChanged: (text) {
 final parsed = double.tryParse(text);
 if (parsed != null) {
 widget.onChanged(parsed);
 }
 },
 );
 }
}

class _Debouncer {
 final _duration = const Duration(milliseconds: 800);
 Timer? _timer;

 void run(VoidCallback action) {
 _timer?.cancel();
 _timer = Timer(_duration, action);
 }

 void dispose() {
 _timer?.cancel();
 }
}

class _TableColumnDef {
 const _TableColumnDef(this.label, this.width);

 final String label;
 final double width;
}

class _EditableTable extends StatelessWidget {
 const _EditableTable({required this.columns, required this.rows});

 final List<_TableColumnDef> columns;
 final List<Widget> rows;

 @override
 Widget build(BuildContext context) {
 const horizontalPadding = 16.0;
 final contentWidth =
 columns.fold<double>(0, (total, column) => total + column.width);
 final minTableWidth = contentWidth + (horizontalPadding * 2);

 return Container(
 width: double.infinity,
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 color: Colors.white,
 ),
 child: LayoutBuilder(
 builder: (context, constraints) {
 final tableWidth = constraints.maxWidth > minTableWidth
 ? constraints.maxWidth
 : minTableWidth;
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SizedBox(
 width: tableWidth,
 child: Column(
 children: [
 Container(
 width: tableWidth,
 padding: const EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 14),
 decoration: const BoxDecoration(
 color: Color(0xFFF3F4F6),
 borderRadius: BorderRadius.only(
 topLeft: Radius.circular(18),
 topRight: Radius.circular(18)),
 ),
 child: Row(
 children: columns
 .map((column) => SizedBox(
 width: column.width,
 child: Center(
 child: Text(
 column.label.toUpperCase(),
 textAlign: TextAlign.center,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 letterSpacing: 0.8,
 color: Color(0xFF6B7280)),
 ),
 ),
 ))
 .toList(),
 ),
 ),
 for (int i = 0; i < rows.length; i++)
 Container(
 width: tableWidth,
 padding: const EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 12),
 decoration: BoxDecoration(
 color:
 i.isEven ? Colors.white : const Color(0xFFF9FAFB),
 border: Border(
 top: BorderSide(
 color: const Color(0xFFE5E7EB),
 width: i == 0 ? 1 : 0.5),
 ),
 ),
 child: rows[i],
 ),
 ],
 ),
 ),
 );
 },
 ),
 );
 }
}

class _TableFieldShell extends StatelessWidget {
 const _TableFieldShell({required this.child});

 final Widget child;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
 child: child,
 );
 }
}

class _EvaluationCriteriaBuilder extends StatelessWidget {
 const _EvaluationCriteriaBuilder({
 required this.criteria,
 required this.onCriteriaChanged,
 });

 final List<EvaluationCriteria> criteria;
 final ValueChanged<List<EvaluationCriteria>> onCriteriaChanged;

 static const _categories = ['Technical', 'Commercial', 'Project Management'];

 @override
 Widget build(BuildContext context) {
 return Container(
 decoration: BoxDecoration(
 border: Border.all(color: const Color(0xFFE5E7EB)),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: const BoxDecoration(
 color: Color(0xFFF3F4F6),
 borderRadius: BorderRadius.only(
 topLeft: Radius.circular(7),
 topRight: Radius.circular(7),
 ),
 ),
 child: Row(
 children: [
 const Text(
 'EVALUATION CRITERIA',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 letterSpacing: 0.8,
 color: Color(0xFF6B7280),
 ),
 ),
 const Spacer(),
 Text(
 'Total: ${_sumWeights(criteria).toStringAsFixed(0)}%',
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 ),
 Padding(
 padding: const EdgeInsets.all(12),
 child: Column(
 children: [
 for (int i = 0; i < criteria.length; i++)
 _CriteriaRow(
 key: ValueKey(criteria[i].id),
 criterion: criteria[i],
 categories: _categories,
 onChanged: (updated) {
 final newList = List<EvaluationCriteria>.from(criteria);
 newList[i] = updated;
 onCriteriaChanged(newList);
 },
 onDelete: () {
 final newList = List<EvaluationCriteria>.from(criteria);
 newList.removeAt(i);
 onCriteriaChanged(newList);
 },
 ),
 const SizedBox(height: 8),
 SizedBox(
 width: double.infinity,
 child: OutlinedButton.icon(
 onPressed: () {
 final newList = List<EvaluationCriteria>.from(criteria);
 newList.add(EvaluationCriteria(
 name: '',
 weight: 0,
 category: 'Technical',
 ));
 onCriteriaChanged(newList);
 },
 icon: const Icon(Icons.add, size: 18),
 label: const Text('Add Criterion'),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 double _sumWeights(List<EvaluationCriteria> list) {
 return list.fold(0.0, (sum, c) => sum + c.weight);
 }
}

class _CriteriaRow extends StatefulWidget {
 const _CriteriaRow({
 super.key,
 required this.criterion,
 required this.categories,
 required this.onChanged,
 required this.onDelete,
 });

 final EvaluationCriteria criterion;
 final List<String> categories;
 final ValueChanged<EvaluationCriteria> onChanged;
 final VoidCallback onDelete;

 @override
 State<_CriteriaRow> createState() => _CriteriaRowState();
}

class _CriteriaRowState extends State<_CriteriaRow> {
 late TextEditingController _nameController;
 late TextEditingController _weightController;

 @override
 void initState() {
 super.initState();
 _nameController = SpellCheckTextEditingController(text: widget.criterion.name);
 _weightController = SpellCheckTextEditingController(
 text: widget.criterion.weight.toStringAsFixed(0));
 }

 @override
 void didUpdateWidget(_CriteriaRow oldWidget) {
 super.didUpdateWidget(oldWidget);
 if (oldWidget.criterion.id != widget.criterion.id) {
 _nameController.text = widget.criterion.name;
 _weightController.text = widget.criterion.weight.toStringAsFixed(0);
 }
 }

 @override
 void dispose() {
 _nameController.dispose();
 _weightController.dispose();
 super.dispose();
 }

 void _notify(EvaluationCriteria updated) {
 widget.onChanged(updated);
 }

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 8),
 child: Row(
 children: [
 Expanded(
 flex: 3,
 child: VoiceTextField(
 controller: _nameController,
 decoration: const InputDecoration(
 hintText: 'Criterion name',
 isDense: true,
 contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
 border: OutlineInputBorder(),
 ),
 onChanged: (v) => _notify(widget.criterion.copyWith(name: v)),
 ),
 ),
 const SizedBox(width: 8),
 SizedBox(
 width: 70,
 child: VoiceTextField(
 controller: _weightController,
 keyboardType: TextInputType.number,
 textAlign: TextAlign.center,
 decoration: const InputDecoration(
 hintText: '0',
 suffixText: '%',
 isDense: true,
 contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
 border: OutlineInputBorder(),
 ),
 onChanged: (v) {
 final w = double.tryParse(v) ?? 0;
 _notify(widget.criterion.copyWith(weight: w));
 },
 ),
 ),
 const SizedBox(width: 8),
 SizedBox(
 width: 120,
 child: DropdownButtonFormField<String>(
 initialValue: widget.criterion.category,
 isExpanded: true,
 isDense: true,
 decoration: const InputDecoration(
 isDense: true,
 contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
 border: OutlineInputBorder(),
 ),
 items: widget.categories
 .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
 .toList(),
 onChanged: (v) {
 if (v != null) _notify(widget.criterion.copyWith(category: v));
 },
 ),
 ),
 const SizedBox(width: 8),
 IconButton(
 onPressed: widget.onDelete,
 icon: const Icon(Icons.close, size: 18),
 color: const Color(0xFFDC2626),
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
 ),
 ],
 ),
 );
 }
}
