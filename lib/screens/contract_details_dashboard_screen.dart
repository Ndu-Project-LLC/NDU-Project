import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/contract_service.dart';
import 'package:ndu_project/screens/front_end_planning_contracts_screen.dart';

import '../theme.dart';
import '../widgets/responsive.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
class ContractDetailsDashboardScreen extends StatefulWidget {
 const ContractDetailsDashboardScreen({super.key});

 @override
 State<ContractDetailsDashboardScreen> createState() => _ContractDetailsDashboardScreenState();
}

class _ContractDetailsDashboardScreenState extends State<ContractDetailsDashboardScreen> {
 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 final provider = ProjectDataInherited.maybeOf(context);
 final projectId = provider?.projectData.projectId;
 final padding = EdgeInsets.fromLTRB(
 AppBreakpoints.pagePadding(context),
 AppBreakpoints.sectionGap(context) + 8,
 AppBreakpoints.pagePadding(context),
 AppBreakpoints.sectionGap(context) * 2,
 );

 return Scaffold(
 backgroundColor: Theme.of(context).colorScheme.surface,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Left navigation sidebar (draggable/collapsible)
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(activeItemLabel: 'Contract'),
 ),
 // Main content area
 Expanded(
 child: Center(
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 1280),
 child: SingleChildScrollView(
 padding: padding,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(title: 'Contract Details', onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 _Header(
 isMobile: isMobile,
 onAddContract: () {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const CreateContractScreen()),
 );
 },
 ),
 const SizedBox(height: 32),
 const _GroupsTabs(),
 const SizedBox(height: 32),
 if (projectId == null || projectId.isEmpty)
 _ContractList(
 isMobile: isMobile,
 contracts: const [],
 emptyMessage:
 'Open or create a project to view contracts.',
 )
 else
 StreamBuilder<List<ContractModel>>(
 stream: ContractService.streamContracts(projectId),
 builder: (context, snapshot) {
 if (snapshot.hasError) {
 return _ContractList(
 isMobile: isMobile,
 contracts: const [],
 emptyMessage:
 'Unable to load contracts right now.',
 );
 }
 final contracts =
 snapshot.data ?? const <ContractModel>[];
 return _ContractList(
 isMobile: isMobile, contracts: contracts);
 },
 ),
 ],
 ),
 ),
 ),
 ),
 ),
 ],
 ),
 ),
 );
 
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Contract Details Dashboard',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_contract_details_dashboard_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}


class _Header extends StatelessWidget {
 const _Header({required this.isMobile, required this.onAddContract});

 final bool isMobile;
 final VoidCallback onAddContract;

 @override
 Widget build(BuildContext context) {
 final theme = Theme.of(context);
 final title = Text(
 'Contract',
 style:
 theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
 );

 final navButtons = Row(
 children: [
 _CircularIconButton(
 icon: Icons.arrow_back_ios_new_rounded, onTap: () {}),
 const SizedBox(width: 12),
 _CircularIconButton(
 icon: Icons.arrow_forward_ios_rounded, onTap: () {}),
 ],
 );

 final primaryAction = FilledButton.icon(
 onPressed: onAddContract,
 icon: const Icon(Icons.add),
 label: const Text('Add New Contract'),
 style: FilledButton.styleFrom(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
 textStyle:
 theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
 ),
 );

 final user = FirebaseAuth.instance.currentUser;
 final displayName = user?.displayName?.trim() ?? '';
 final email = user?.email?.trim() ?? '';
 final subtitle = email.isNotEmpty ? email : 'Member';
 final userChip = _UserChip(
 name: displayName.isNotEmpty
 ? displayName
 : (email.isNotEmpty ? email : 'User'),
 subtitle: subtitle,
 );

 if (isMobile) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 navButtons,
 userChip,
 ],
 ),
 const SizedBox(height: 16),
 title,
 const SizedBox(height: 16),
 primaryAction,
 ],
 );
 }

 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 navButtons,
 const SizedBox(width: 24),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 title,
 const SizedBox(height: 12),
 Text(
 'Manage your contracts and track their progress',
 style: theme.textTheme.bodyMedium
 ?.copyWith(color: Colors.grey[600]),
 ),
 ],
 ),
 ),
 const SizedBox(width: 24),
 primaryAction,
 const SizedBox(width: 16),
 userChip,
 ],
 );
 }
}

class _CircularIconButton extends StatelessWidget {
 const _CircularIconButton({required this.icon, required this.onTap});

 final IconData icon;
 final VoidCallback onTap;

 @override
 Widget build(BuildContext context) {
 final theme = Theme.of(context);
 return Material(
 shape: const CircleBorder(),
 color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
 child: InkWell(
 customBorder: const CircleBorder(),
 onTap: onTap,
 child: SizedBox(
 height: 40,
 width: 40,
 child: Icon(icon, size: 18, color: theme.colorScheme.onSurface),
 ),
 ),
 );
 }
}

class _UserChip extends StatelessWidget {
 _UserChip({required this.name, required this.subtitle});

 final String name;
 final String subtitle;

 @override
 Widget build(BuildContext context) {
 final theme = Theme.of(context);
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(999),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.05),
 blurRadius: 16,
 offset: const Offset(0, 8),
 ),
 ],
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CircleAvatar(
 radius: 20,
 backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
 child: Text(
 _initials(name),
 style: TextStyle(
 color: theme.colorScheme.primary,
 fontWeight: FontWeight.w700),
 ),
 ),
 const SizedBox(width: 12),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(name,
 style: theme.textTheme.labelLarge
 ?.copyWith(fontWeight: FontWeight.w600)),
 Text(
 subtitle,
 style: theme.textTheme.labelSmall
 ?.copyWith(color: Colors.grey[600]),
 ),
 ],
 ),
 ],
 ),
 );
 }

 String _initials(String value) {
 final trimmed = value.trim();
 if (trimmed.isEmpty) return 'U';
 final parts =
 trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
 if (parts.length == 1) return parts.first[0].toUpperCase();
 return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
 }
}

class _GroupsTabs extends StatelessWidget {
 const _GroupsTabs();

 @override
 Widget build(BuildContext context) {
 final theme = Theme.of(context);
 final tabTextStyle =
 theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Groups',
 style:
 theme.textTheme.titleMedium?.copyWith(color: Colors.grey[700])),
 const SizedBox(height: 12),
 Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(48),
 border: Border.all(color: AppSemanticColors.border),
 ),
 padding: const EdgeInsets.all(6),
 child: Row(
 children: [
 Expanded(
 child: Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(32),
 ),
 padding:
 const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
 child: Text('Contract Management',
 style: tabTextStyle?.copyWith(color: Colors.grey[600])),
 ),
 ),
 const SizedBox(width: 6),
 Expanded(
 child: Container(
 decoration: BoxDecoration(
 color:
 Theme.of(context).colorScheme.primary.withOpacity(0.08),
 borderRadius: BorderRadius.circular(32),
 border: Border.all(
 color: Theme.of(context).colorScheme.primary, width: 2),
 ),
 padding:
 const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
 child: Text(
 'Contract Details',
 style: tabTextStyle?.copyWith(
 color: Theme.of(context).colorScheme.primary),
 ),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 12),
 Text(
 'Manage your contracts and track their progress',
 style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
 ),
 ],
 );
 }
}

class _ContractList extends StatelessWidget {
 const _ContractList(
 {required this.isMobile, required this.contracts, this.emptyMessage});

 final bool isMobile;
 final List<ContractModel> contracts;
 final String? emptyMessage;

 @override
 Widget build(BuildContext context) {
 final theme = Theme.of(context);

 final header = Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Contract List',
 style: theme.textTheme.titleLarge
 ?.copyWith(fontWeight: FontWeight.w600)),
 const SizedBox(height: 4),
 Text(
 'View all expected contract scopes for the project',
 style: theme.textTheme.bodyMedium
 ?.copyWith(color: Colors.grey[600]),
 ),
 ],
 ),
 ),
 if (!isMobile) ...[
 _ControlButtons(),
 ],
 ],
 );

 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(24),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 24,
 offset: const Offset(0, 12),
 ),
 ],
 ),
 padding: EdgeInsets.all(isMobile ? 20 : 28),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 header,
 const SizedBox(height: 24),
 if (isMobile) ...[
 _ControlButtons(),
 const SizedBox(height: 16),
 ],
 _SearchField(isMobile: isMobile),
 const SizedBox(height: 16),
 _TableHeader(isMobile: isMobile),
 const SizedBox(height: 8),
 if (contracts.isEmpty)
 Padding(
 padding: const EdgeInsets.symmetric(vertical: 12),
 child: Text(
 emptyMessage ?? 'No contracts added yet.',
 style: theme.textTheme.bodySmall
 ?.copyWith(color: Colors.grey[600]),
 ),
 )
 else
 ...List.generate(contracts.length, (index) {
 final row = _ContractRow.fromContract(contracts[index]);
 return Padding(
 padding: EdgeInsets.only(
 bottom: index == contracts.length - 1 ? 8 : 20),
 child: _ContractRowTile(row: row, isMobile: isMobile),
 );
 }),
 const SizedBox(height: 16),
 Text(
 'A list of your contracts.',
 style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
 ),
 ],
 ),
 );
 }
}

class _ControlButtons extends StatelessWidget {
 @override
 Widget build(BuildContext context) {
 final spacing = AppBreakpoints.isMobile(context) ? 12.0 : 16.0;
 return Wrap(
 spacing: spacing,
 runSpacing: 12,
 crossAxisAlignment: WrapCrossAlignment.center,
 children: [
 _GhostButton(
 icon: Icons.filter_list,
 label: 'Filter',
 onPressed: () {},
 ),
 _GhostButton(
 icon: Icons.people_outline,
 label: 'Compare Contractors',
 onPressed: () {},
 ),
 ],
 );
 }
}

class _GhostButton extends StatelessWidget {
 const _GhostButton({
 required this.icon,
 required this.label,
 required this.onPressed,
 });

 final IconData icon;
 final String label;
 final VoidCallback onPressed;

 @override
 Widget build(BuildContext context) {
 final theme = Theme.of(context);
 final foreground = theme.colorScheme.primary;
 return OutlinedButton.icon(
 onPressed: onPressed,
 icon: Icon(icon, size: 18, color: foreground),
 label: Text(label,
 style: theme.textTheme.labelLarge?.copyWith(color: foreground)),
 style: OutlinedButton.styleFrom(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
 side: BorderSide(color: AppSemanticColors.border),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 backgroundColor: theme.colorScheme.primary.withOpacity(0.04),
 ),
 );
 }
}

class _SearchField extends StatelessWidget {
 const _SearchField({required this.isMobile});

 final bool isMobile;

 @override
 Widget build(BuildContext context) {
 return VoiceTextField(
 decoration: InputDecoration(
 hintText: 'Search contracts...',
 prefixIcon: const Icon(Icons.search),
 fillColor: Colors.grey[50],
 filled: true,
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: BorderSide(color: AppSemanticColors.border),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: BorderSide(color: AppSemanticColors.border),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
 ),
 contentPadding:
 EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 12 : 16),
 ),
 );
 }
}

class _TableHeader extends StatelessWidget {
 const _TableHeader({required this.isMobile});

 final bool isMobile;

 @override
 Widget build(BuildContext context) {
 final headers = [
 'Name',
 'Type',
 'Payment',
 'Status',
 'Progress',
 'Value',
 'Actions'
 ];

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
 decoration: BoxDecoration(
 color: Colors.grey[50],
 borderRadius: BorderRadius.circular(12),
 ),
 child: isMobile
 ? Wrap(
 spacing: 16,
 runSpacing: 8,
 children: headers.map((h) => _HeaderLabel(title: h)).toList(),
 )
 : Row(
 children: [
 for (final title in headers)
 Expanded(
 flex: title == 'Name'
 ? 2
 : title == 'Progress'
 ? 2
 : 1,
 child: _HeaderLabel(title: title),
 ),
 ],
 ),
 );
 }
}

class _HeaderLabel extends StatelessWidget {
 const _HeaderLabel({required this.title});

 final String title;

 @override
 Widget build(BuildContext context) {
 return Text(
 title,
 style: Theme.of(context).textTheme.labelLarge?.copyWith(
 color: Colors.grey[600],
 fontWeight: FontWeight.w600,
 ),
 );
 }
}

class _ContractRowTile extends StatelessWidget {
 const _ContractRowTile({required this.row, required this.isMobile});

 final _ContractRow row;
 final bool isMobile;

 @override
 Widget build(BuildContext context) {
 final theme = Theme.of(context);

 Widget statusChip(String status) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: AppSemanticColors.warningSurface,
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 status,
 style: theme.textTheme.labelSmall?.copyWith(
 color: AppSemanticColors.warning,
 fontWeight: FontWeight.w600,
 letterSpacing: 0.3,
 ),
 ),
 );
 }

 final progressBar = Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 LinearProgressIndicator(
 value: row.progress == 0 ? 0.01 : row.progress / 100,
 minHeight: 8,
 borderRadius: BorderRadius.circular(20),
 color: theme.colorScheme.primary.withOpacity(0.8),
 backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
 ),
 const SizedBox(height: 6),
 Text('${row.progress}%',
 style:
 theme.textTheme.labelSmall?.copyWith(color: Colors.grey[600])),
 ],
 );

 final actions = Wrap(
 spacing: 10,
 children: const [
 _RoundIcon(icon: Icons.remove_red_eye_outlined),
 _RoundIcon(icon: Icons.edit_outlined),
 ],
 );

 final content = isMobile
 ? Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _RowLabelValue(label: 'Name', value: row.name),
 _RowLabelValue(label: 'Type', value: row.type),
 _RowLabelValue(label: 'Payment', value: row.payment),
 _RowLabelWidget(label: 'Status', child: statusChip(row.status)),
 _RowLabelWidget(label: 'Progress', child: progressBar),
 _RowLabelValue(label: 'Value', value: row.value),
 const SizedBox(height: 12),
 actions,
 ],
 )
 : Row(
 children: [
 Expanded(
 flex: 2,
 child: Text(row.name,
 style: theme.textTheme.bodyLarge
 ?.copyWith(fontWeight: FontWeight.w600))),
 Expanded(
 child: Text(row.type, style: theme.textTheme.bodyMedium)),
 Expanded(
 child: Text(row.payment, style: theme.textTheme.bodyMedium)),
 Expanded(child: statusChip(row.status)),
 Expanded(flex: 2, child: progressBar),
 Expanded(
 child: Text(row.value, style: theme.textTheme.bodyMedium)),
 SizedBox(width: 120, child: Center(child: actions)),
 ],
 );

 return DecoratedBox(
 decoration: BoxDecoration(
 border: Border.all(color: AppSemanticColors.border),
 borderRadius: BorderRadius.circular(16),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.03),
 blurRadius: 14,
 offset: const Offset(0, 6)),
 ],
 ),
 child: Column(
 children: [
 Container(
 height: 3,
 decoration: const BoxDecoration(
 color: AppSemanticColors.success,
 borderRadius: BorderRadius.only(
 topLeft: Radius.circular(16),
 topRight: Radius.circular(16),
 ),
 ),
 ),
 Padding(
 padding: EdgeInsets.symmetric(
 horizontal: isMobile ? 16 : 20, vertical: isMobile ? 16 : 18),
 child: content,
 ),
 ],
 ),
 );
 }
}

class _RowLabelValue extends StatelessWidget {
 const _RowLabelValue({required this.label, required this.value});

 final String label;
 final String value;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label,
 style: Theme.of(context)
 .textTheme
 .labelSmall
 ?.copyWith(color: Colors.grey[600], letterSpacing: 0.2)),
 const SizedBox(height: 4),
 Text(value,
 style: Theme.of(context)
 .textTheme
 .bodyMedium
 ?.copyWith(fontWeight: FontWeight.w600)),
 ],
 ),
 );
 }
}

class _RowLabelWidget extends StatelessWidget {
 const _RowLabelWidget({required this.label, required this.child});

 final String label;
 final Widget child;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label,
 style: Theme.of(context)
 .textTheme
 .labelSmall
 ?.copyWith(color: Colors.grey[600], letterSpacing: 0.2)),
 const SizedBox(height: 4),
 child,
 ],
 ),
 );
 }
}

class _RoundIcon extends StatelessWidget {
 const _RoundIcon({required this.icon});

 final IconData icon;

 @override
 Widget build(BuildContext context) {
 return Material(
 shape: const CircleBorder(),
 color: Colors.grey[50],
 child: InkWell(
 customBorder: const CircleBorder(),
 onTap: () {},
 child: SizedBox(
 height: 40,
 width: 40,
 child: Icon(icon,
 size: 18, color: Theme.of(context).colorScheme.primary),
 ),
 ),
 );
 }
}

class _ContractRow {
 const _ContractRow(this.name, this.type, this.payment, this.status,
 this.progress, this.value);

 final String name;
 final String type;
 final String payment;
 final String status;
 final int progress;
 final String value;

 factory _ContractRow.fromContract(ContractModel contract) {
 final status = contract.status.isNotEmpty ? contract.status : 'Pending';
 final lowerStatus = status.toLowerCase();
 // Expanded progress stages: Not Started → Started → In Progress → Almost Complete → Completed → Closed Out
 final int progress;
 if (lowerStatus.contains('closed') || lowerStatus.contains('terminated') || lowerStatus.contains('expired')) {
 progress = 100; // Closed out
 } else if (lowerStatus.contains('complete') || lowerStatus.contains('executed')) {
 progress = 100; // Completed
 } else if (lowerStatus.contains('almost') || lowerStatus.contains('final') || lowerStatus.contains('review')) {
 progress = 85; // Almost complete
 } else if (lowerStatus.contains('progress') || lowerStatus.contains('active') || lowerStatus.contains('started')) {
 progress = 60; // In Progress / Started
 } else if (lowerStatus.contains('approved') || lowerStatus.contains('pending')) {
 progress = 30; // Pending Review
 } else {
 progress = 0; // Not Started
 }
 final estimatedValue = contract.estimatedValue;
 final formattedValue =
 estimatedValue > 0 ? '\$${estimatedValue.toStringAsFixed(0)}' : 'TBD';
 return _ContractRow(
 contract.name.isNotEmpty ? contract.name : 'Untitled contract',
 contract.contractType.isNotEmpty ? contract.contractType : 'Not set',
 contract.paymentType.isNotEmpty ? contract.paymentType : 'Not set',
 status,
 progress,
 formattedValue,
 );
 }
}
