import 'package:flutter/material.dart';
import 'package:ndu_project/screens/front_end_planning_workspace_screen.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/content_text.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/project_navigation_service.dart';
import 'package:ndu_project/widgets/front_end_planning_header.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

class FrontEndPlanningScreen extends StatefulWidget {
 const FrontEndPlanningScreen({super.key});

 @override
 State<FrontEndPlanningScreen> createState() => _FrontEndPlanningScreenState();
}

class _FrontEndPlanningScreenState extends State<FrontEndPlanningScreen> {
 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) async {
 final provider = ProjectDataInherited.maybeOf(context);
 final pid = provider?.projectData.projectId;
 if (pid != null && pid.isNotEmpty) {
 // Save this page as the last visited page for the project
 await ProjectNavigationService.instance
 .saveLastPage(pid, 'front_end_planning');
 }
 });
 }

 
 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 final fep = projectData.frontEndPlanning;
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Project Summary',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', fep.requirementsNotes ?? 'No data recorded.'),
 ],
 );
 }
// ignore: unused_element
 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const FrontEndPlanningScreen()),
 );
 }

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 final padding = isMobile ? 16.0 : 24.0;

 return ResponsiveScaffold(
 activeItemLabel: 'Project Summary',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: Column(
 children: [
 FrontEndPlanningHeader(title: 'Project Summary', onExportPdf: _exportPdf),
 Expanded(
 child: Stack(
 children: [
 const Positioned.fill(child: _StripedBackdrop()),
 const AdminEditToggle(),
 Center(
 child: SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 vertical: isMobile ? 32 : 64, horizontal: padding),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 _TitleBlock(),
 SizedBox(height: 32),
 _ProjectCharterTable(),
 ],
 ),
 ),
 ),
 Positioned(
 right: padding,
 bottom: padding,
 child: ElevatedButton(
 onPressed: () {
 FrontEndPlanningWorkspaceScreen.open(context);
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: Colors.black,
 padding:
 const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(22)),
 elevation: 0,
 ),
 child: const Text('Next',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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

class _StripedBackdrop extends StatelessWidget {
 const _StripedBackdrop();

 @override
 Widget build(BuildContext context) {
 return Stack(
 fit: StackFit.expand,
 children: [
 ColoredBox(color: Color(0xFFF3F5F9)),
 CustomPaint(painter: _StripedBackgroundPainter()),
 ],
 );
 }
}

class _StripedBackgroundPainter extends CustomPainter {
 const _StripedBackgroundPainter();

 @override
 void paint(Canvas canvas, Size size) {
 final paint = Paint()
 ..color = const Color(0xFFE7EBF2)
 ..strokeWidth = 1;
 const spacing = 18.0;
 for (double offset = -size.height; offset < size.width; offset += spacing) {
 final start = Offset(offset, 0);
 final end = Offset(offset + size.height, size.height);
 canvas.drawLine(start, end, paint);
 }
 }

 @override
 bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TitleBlock extends StatelessWidget {
 const _TitleBlock();

 @override
 Widget build(BuildContext context) {
 return EditableContentText(
 contentKey: 'fep_charter_title',
 fallback: 'The components of a project charter',
 category: 'front_end_planning',
 textAlign: TextAlign.center,
 style: TextStyle(
 color: Color(0xFF44474D),
 fontSize: 32,
 fontWeight: FontWeight.w700,
 letterSpacing: 0.2,
 ),
 );
 }
}

class _ProjectCharterTable extends StatelessWidget {
 const _ProjectCharterTable();

 static const _borderColor = Color(0xFFD8DDE6);
 static const _headerFill = Color(0xFFE5F3FF);
 static const _cellStyle = TextStyle(
 color: Color(0xFF3F3F3F),
 fontSize: 14,
 fontWeight: FontWeight.w600,
 letterSpacing: 0.4,
 );

 @override
 Widget build(BuildContext context) {    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 880),
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E6EF), width: 1.2),
 boxShadow: const [
 BoxShadow(
 color: Color(0x15000000),
 blurRadius: 28,
 offset: Offset(0, 18),
 ),
 BoxShadow(
 color: Color(0x0F000000),
 blurRadius: 8,
 offset: Offset(0, 4),
 ),
 ],
 ),
 child: ClipRRect(
 borderRadius: BorderRadius.circular(18),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 _TableRowCells(
 labels: ['TITLE', 'PROJECT NAME'],
 flexes: [1, 1],
 ),
 _SectionHeader(label: 'TEAM'),
 _TableRowCells(
 labels: [
 'PROJECT MANAGER',
 'PROJECT TEAM MEMBERS',
 'PROJECT STAKEHOLDERS',
 ],
 flexes: [1, 1, 1],
 ),
 _SectionHeader(label: 'SPECS'),
 _TableRowCells(
 labels: ['BUSINESS CASE', 'PROJECT PURPOSE'],
 flexes: [1, 1],
 ),
 _TableRowCells(
 labels: ['PROJECT DELIVERABLES', 'PROJECT SCOPE'],
 flexes: [1, 1],
 ),
 _TableRowCells(
 labels: ['PROJECT BENEFITS', 'PROJECT RISKS'],
 flexes: [1, 1],
 ),
 _TableRowCells(
 labels: ['RESOURCES', 'PROJECT BUDGET'],
 flexes: [1, 1],
 ),
 _SectionHeader(label: 'MILESTONES'),
 _TableRowCells(
 labels: [
 'STARTING DATE',
 'MILESTONE COMPLETION DATES',
 'PROJECT COMPLETION DATE',
 ],
 flexes: [1, 1, 1],
 showBottomBorder: false,
 ),
 ],
 ),
 ),
 ),
 );
 }
}

class _SectionHeader extends StatelessWidget {
 const _SectionHeader({required this.label});

 final String label;

 @override
 Widget build(BuildContext context) {
 return Container(
 height: 52,
 alignment: Alignment.center,
 decoration: const BoxDecoration(
 color: _ProjectCharterTable._headerFill,
 border: Border(
 top: BorderSide(color: _ProjectCharterTable._borderColor),
 bottom: BorderSide(color: _ProjectCharterTable._borderColor),
 ),
 ),
 child: EditableContentText(
 contentKey: 'fep_charter_section_${label.toLowerCase()}',
 fallback: label,
 category: 'front_end_planning',
 style: _ProjectCharterTable._cellStyle,
 ),
 );
 }
}

class _TableRowCells extends StatelessWidget {
 const _TableRowCells({
 required this.labels,
 required this.flexes,
 this.showBottomBorder = true,
 });

 final List<String> labels;
 final List<int> flexes;
 final bool showBottomBorder;

 @override
 Widget build(BuildContext context) {
 final children = <Widget>[];
 for (var index = 0; index < labels.length; index++) {
 children.add(
 Expanded(
 flex: flexes[index],
 child: Padding(
 padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
 child: Center(
 child: EditableContentText(
 contentKey:
 'fep_charter_cell_${labels[index].toLowerCase().replaceAll(' ', '_')}',
 fallback: labels[index],
 category: 'front_end_planning',
 textAlign: TextAlign.center,
 style: _ProjectCharterTable._cellStyle,
 ),
 ),
 ),
 ),
 );
 if (index != labels.length - 1) {
 children.add(
 const SizedBox(
 width: 1,
 child: ColoredBox(color: _ProjectCharterTable._borderColor),
 ),
 );
 }
 }    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: showBottomBorder
              ? const BorderSide(color: _ProjectCharterTable._borderColor)
              : BorderSide.none,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
 }
}
