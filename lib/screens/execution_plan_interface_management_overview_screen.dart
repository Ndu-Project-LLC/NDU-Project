import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/ai_suggesting_textfield.dart';
import 'package:ndu_project/widgets/ai_diagram_panel.dart';
import 'package:ndu_project/widgets/execution_plan_shared.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/screens/staff_team_screen.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';

class ExecutionPlanInterfaceManagementOverviewScreen extends StatelessWidget {
 const ExecutionPlanInterfaceManagementOverviewScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) =>
 const ExecutionPlanInterfaceManagementOverviewScreen()),
 );
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 20 : 40;

 return ResponsiveScaffold(
 activeItemLabel: 'Execution Interface Management Overview',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 32),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const PlanningPhaseHeader(title: 'Execution Plan'),
 const SizedBox(height: 16),
 const CrossReferenceNote(standalonePage: 'Interface Management'),
 const SizedBox(height: 24),
 const _ExecutionPlanDetailsSection(),
 const SizedBox(height: 32),
 const _InterfaceManagementSection(),
 const SizedBox(height: 48),
 Align(
 alignment: Alignment.centerRight,
 child: _DoneButton(
 onPressed: () {
 PlanningPhaseNavigation.goToNext(context, 'execution_plan_interface_management_overview');
 },
 ),
 ),
 const SizedBox(height: 56),
 ],
 ),
 ),
 );
 }
}

class _ExecutionPlanDetailsSection extends StatelessWidget {
 const _ExecutionPlanDetailsSection();

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Execution Plan Details',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w600,
 color: Colors.black87),
 ),
 const SizedBox(height: 8),
 Text(
 'Outline the strategy and actions for the implementation phase.',
 style: TextStyle(fontSize: 14, color: Colors.grey[600]),
 ),
 const SizedBox(height: 16),
 _OverviewAiEditor(),
 ],
 ),
 );
 }
}

class _InterfaceManagementSection extends StatelessWidget {
 const _InterfaceManagementSection();

 @override
 Widget build(BuildContext context) {
 final data = ProjectDataHelper.getDataListening(context);
 final entries = data.interfaceEntries;
 final extIntegrations = data.externalIntegrations;

 // Categorize entries by type
 final technical = entries.where((e) => e.interfaceType.toLowerCase().contains('tech') || e.interfaceType.isEmpty).toList();
 final contractual = entries.where((e) => e.interfaceType.toLowerCase().contains('contract')).toList();
 final organizational = entries.where((e) => e.interfaceType.toLowerCase().contains('org')).toList();
 final physical = entries.where((e) => e.interfaceType.toLowerCase().contains('physical')).toList();
 final procedural = entries.where((e) => e.interfaceType.toLowerCase().contains('procedural')).toList();

 // External integrations names
 final extNames = extIntegrations.map((e) => e['name']?.toString().trim() ?? '').where((n) => n.isNotEmpty).toList();

 // Type counts for summary
 final typeCounts = <String, int>{
 'Technical': technical.length,
 'Contractual': contractual.length,
 'Organizational': organizational.length,
 'Physical': physical.length,
 'Procedural': procedural.length,
 };

 final hasData = entries.isNotEmpty || extNames.isNotEmpty;

 return Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Interface management',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w600,
 color: Colors.black87),
 ),
 const SizedBox(height: 8),
 if (!hasData) ...[
 const Text(
 'No interface data yet. Define interfaces in the Interface Management section.',
 style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 24),
 ],
 if (hasData) ...[
 // Summary row with type counts
 Wrap(
 spacing: 12,
 runSpacing: 8,
 children: typeCounts.entries
 .where((e) => e.value > 0)
 .map((e) => Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: _typeColor(e.key).withOpacity(0.1),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: _typeColor(e.key).withOpacity(0.3)),
 ),
 child: Text(
 '${e.key}: ${e.value}',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: _typeColor(e.key),
 ),
 ),
 ))
 .toList(),
 ),
 const SizedBox(height: 24),
 ],
 const Text(
 'Interface Architecture Overview',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Colors.black87),
 ),
 const SizedBox(height: 24),

 // External Systems layer
 if (hasData && (extNames.isNotEmpty || contractual.isNotEmpty)) ...[
 _ExternalSystemsRow(
 title: 'External Systems',
 systems: [
 ...extNames.map((n) => _SystemCard(
 title: n,
 subtitle: 'External',
 color: const Color(0xFFFFE4CC))),
 ...contractual.map((e) => _SystemCard(
 title: e.boundary.trim().isNotEmpty ? e.boundary.trim() : 'Contract',
 subtitle: e.partyA.trim().isNotEmpty ? e.partyA.trim() : 'Third party',
 color: const Color(0xFFFFE4CC),
 )),
 ],
 ),
 const SizedBox(height: 24),
 ] else if (!hasData) ...[
 const _ExternalSystemsRow(
 title: 'External Systems',
 systems: [
 _SystemCard(
 title: 'Payment Gateway',
 subtitle: 'Third party',
 color: Color(0xFFFFE4CC)),
 _SystemCard(
 title: 'Identity Provider',
 subtitle: 'SSO Service',
 color: Color(0xFFFFE4CC)),
 _SystemCard(
 title: 'CRM System',
 subtitle: 'Legacy',
 color: Color(0xFFFFE4CC)),
 ],
 ),
 const SizedBox(height: 24),
 ],

 // API / Integration Layer
 if (hasData && technical.isNotEmpty) ...[
 _ExternalSystemsRow(
 title: 'API Layer',
 systems: technical.map((e) => _SystemCard(
 title: e.boundary.trim().isNotEmpty ? e.boundary.trim() : 'Interface',
 subtitle: e.protocol.trim().isNotEmpty ? e.protocol.trim() : 'API',
 color: const Color(0xFFD4E4FF),
 )).toList(),
 ),
 const SizedBox(height: 24),
 ] else if (!hasData) ...[
 const _ExternalSystemsRow(
 title: 'API Layer',
 systems: [
 _SystemCard(
 title: 'API Gateway',
 subtitle: 'Routing, Security, Monitoring',
 color: Color(0xFFD4E4FF),
 fullWidth: true),
 ],
 ),
 const SizedBox(height: 24),
 ],

 // Internal Systems layer
 if (hasData && organizational.isNotEmpty) ...[
 _ExternalSystemsRow(
 title: 'Internal Systems',
 systems: organizational.map((e) => _SystemCard(
 title: e.boundary.trim().isNotEmpty ? e.boundary.trim() : 'Interface',
 subtitle: '${e.partyA.trim().isNotEmpty ? e.partyA.trim() : "Party A"} ↔ ${e.partyB.trim().isNotEmpty ? e.partyB.trim() : "Party B"}',
 color: const Color(0xFFD4FFD4),
 )).toList(),
 ),
 ] else if (!hasData) ...[
 const _ExternalSystemsRow(
 title: 'Internal Systems',
 systems: [
 _SystemCard(
 title: 'Web Application',
 subtitle: 'Frontend',
 color: Color(0xFFD4FFD4)),
 _SystemCard(
 title: 'Business Logic',
 subtitle: 'Core Services',
 color: Color(0xFFD4FFD4)),
 _SystemCard(
 title: 'Data Storage',
 subtitle: 'Database',
 color: Color(0xFFD4FFD4)),
 ],
 ),
 ],

 // Physical Systems layer
 if (physical.isNotEmpty) ...[
 const SizedBox(height: 24),
 _ExternalSystemsRow(
 title: 'Physical Systems',
 systems: physical.map((e) => _SystemCard(
 title: e.boundary.trim().isNotEmpty ? e.boundary.trim() : 'Interface',
 subtitle: '${e.partyA.trim().isNotEmpty ? e.partyA.trim() : "Party A"} ↔ ${e.partyB.trim().isNotEmpty ? e.partyB.trim() : "Party B"}',
 color: const Color(0xFFE8D5F5),
 )).toList(),
 ),
 ],

 // Procedural Interfaces layer
 if (procedural.isNotEmpty) ...[
 const SizedBox(height: 24),
 _ExternalSystemsRow(
 title: 'Procedural Interfaces',
 systems: procedural.map((e) => _SystemCard(
 title: e.boundary.trim().isNotEmpty ? e.boundary.trim() : 'Interface',
 subtitle: '${e.partyA.trim().isNotEmpty ? e.partyA.trim() : "Party A"} ↔ ${e.partyB.trim().isNotEmpty ? e.partyB.trim() : "Party B"}',
 color: const Color(0xFFFFE0E6),
 )).toList(),
 ),
 ],
 ],
 ),
 );
 }

 Color _typeColor(String type) {
 switch (type) {
 case 'Technical':
 return const Color(0xFFD97706);
 case 'Contractual':
 return const Color(0xFFD97706);
 case 'Organizational':
 return const Color(0xFF10B981);
 case 'Physical':
 return const Color(0xFF7C3AED);
 case 'Procedural':
 return const Color(0xFFEC4899);
 default:
 return const Color(0xFF6B7280);
 }
 }
}

class _OverviewAiEditor extends StatefulWidget {
 @override
 State<_OverviewAiEditor> createState() => _OverviewAiEditorState();
}

class _OverviewAiEditorState extends State<_OverviewAiEditor> {
 String _current = '';
 Timer? _saveDebounce;
 DateTime? _lastSavedAt;

 @override
 void dispose() {
 _saveDebounce?.cancel();
 super.dispose();
 }

 void _handleChanged(String value) {
 _current = value;
 _saveDebounce?.cancel();
 _saveDebounce = Timer(const Duration(milliseconds: 700), () async {
 final trimmed = value.trim();
 final success = await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'execution_plan_interface_management_overview',
 dataUpdater: (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 'execution_plan_interface_overview': trimmed,
 },
 ),
 showSnackbar: false,
 );
 if (mounted && success) {
 setState(() => _lastSavedAt = DateTime.now());
 }
 });
 }

 @override
 Widget build(BuildContext context) {
 if (_current.isEmpty) {
 final saved = ProjectDataHelper.getData(context)
 .planningNotes['execution_plan_interface_overview'] ??
 '';
 if (saved.trim().isNotEmpty) {
 _current = saved;
 }
 }

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 AiSuggestingTextField(
 fieldLabel: 'Execution Plan Details',
 hintText: 'Input your notes here...',
 sectionLabel: 'Execution Interface Management Overview',
 showLabel: false,
 initialText: ProjectDataHelper.getData(context)
 .planningNotes['execution_plan_interface_overview'],
 autoGenerate: true,
 autoGenerateSection: 'Interface Management Overview',
 onChanged: _handleChanged,
 ),
 if (_lastSavedAt != null)
 Padding(
 padding: const EdgeInsets.only(top: 8),
 child: Text(
 'Saved ${TimeOfDay.fromDateTime(_lastSavedAt!).format(context)}',
 style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 ),
 const SizedBox(height: 8),
 AiDiagramPanel(
 sectionLabel: 'Interface Management Overview',
 currentTextProvider: () => _current,
 title: 'Generate Interface Management Diagram',
 ),
 ],
 );
 }
}

class _ExternalSystemsRow extends StatelessWidget {
 const _ExternalSystemsRow({required this.title, required this.systems});

 final String title;
 final List<_SystemCard> systems;

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
 ),
 const SizedBox(height: 12),
 if (systems.length == 1 && systems.first.fullWidth)
 systems.first
 else
 Wrap(
 spacing: 16,
 runSpacing: 16,
 children: systems,
 ),
 ],
 );
 }
}

class _SystemCard extends StatelessWidget {
 const _SystemCard({
 required this.title,
 required this.subtitle,
 required this.color,
 this.fullWidth = false,
 });

 final String title;
 final String subtitle;
 final Color color;
 final bool fullWidth;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: fullWidth ? double.infinity : null,
 constraints: fullWidth ? null : const BoxConstraints(minWidth: 160),
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
 decoration: BoxDecoration(
 color: color,
 borderRadius: BorderRadius.circular(12),
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 title,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: Colors.black87),
 textAlign: TextAlign.center,
 ),
 const SizedBox(height: 8),
 Text(
 subtitle,
 style: TextStyle(fontSize: 12, color: Colors.grey[700]),
 textAlign: TextAlign.center,
 ),
 ],
 ),
 );
 }
}

class _DoneButton extends StatelessWidget {
 const _DoneButton({required this.onPressed});

 final VoidCallback onPressed;

 @override
 Widget build(BuildContext context) {
 return ElevatedButton(
 onPressed: onPressed,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: Colors.black87,
 padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
 elevation: 0,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
 ),
 child: const Text('Done',
 style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
 );
 }
}
