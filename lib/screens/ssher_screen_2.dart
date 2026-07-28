import 'package:flutter/material.dart';
import 'package:ndu_project/screens/ssher_components.dart';
import 'package:ndu_project/screens/ssher_screen_3.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/unified_phase_header.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

class SsherScreen2 extends StatefulWidget {
 const SsherScreen2({super.key});

 @override
 State<SsherScreen2> createState() => _SsherScreen2State();
}

class _SsherScreen2State extends State<SsherScreen2> {
 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 final sidebarWidth = AppBreakpoints.sidebarWidth(context);

 // Content shared between mobile and desktop
 final content = Column(
 children: [
 // Security section
 SsherSectionCard(
 leadingIcon: Icons.shield_outlined,
 accentColor: const Color(0xFFEF5350),
 title: 'Security',
 subtitle: 'Physical and cyber security measures',
 detailsPlaceholder:
 'Multi- layered security approach including physical access controls, cybersecurity measures, surveillance systems, and incident response',
 itemsLabel: '12 Items',
 addButtonLabel: 'Add Safety Item',
 columns: const [
 '#',
 'Department',
 'Team Member',
 'Security Concern',
 'Risk Level',
 'Mitigation Strategy',
 'Actions'
 ],
 rows: const [
 [
 Text('1', style: TextStyle(fontSize: 12)),
 Text('Operations', style: TextStyle(fontSize: 13)),
 Text('Sarah Johnson', style: TextStyle(fontSize: 13)),
 Text('Chemical exposure i...', style: TextStyle(fontSize: 13)),
 RiskBadge.high(),
 Text('Enhanced ventilation s...', style: TextStyle(fontSize: 13)),
 ActionButtons(),
 ],
 [
 Text('2', style: TextStyle(fontSize: 12)),
 Text('Manufacturing', style: TextStyle(fontSize: 13)),
 Text('Mike Chen', style: TextStyle(fontSize: 13)),
 Text('Heavy machinery o...', style: TextStyle(fontSize: 13)),
 RiskBadge.high(),
 Text('Operator certification, ...',
 style: TextStyle(fontSize: 13)),
 ActionButtons(),
 ],
 ],
 ),

 // Health section
 SsherSectionCard(
 leadingIcon: Icons.volunteer_activism_outlined,
 accentColor: const Color(0xFF1E88E5),
 title: 'Health',
 subtitle: 'Occupational health and wellness programs',
 detailsPlaceholder:
 'Multi- layered security approach including physical access controls, cybersecurity measures, surveillance systems, and incident response',
 itemsLabel: '12 Items',
 addButtonLabel: 'Add Safety Item',
 columns: const [
 '#',
 'Department',
 'Team Member',
 'Health Concern',
 'Risk Level',
 'Mitigation Strategy',
 'Actions'
 ],
 rows: const [
 [
 Text('1', style: TextStyle(fontSize: 12)),
 Text('Operations', style: TextStyle(fontSize: 13)),
 Text('Sarah Johnson', style: TextStyle(fontSize: 13)),
 Text('Chemical exposure i...', style: TextStyle(fontSize: 13)),
 RiskBadge.high(),
 Text('Enhanced ventilation s...', style: TextStyle(fontSize: 13)),
 ActionButtons(),
 ],
 [
 Text('2', style: TextStyle(fontSize: 12)),
 Text('Manufacturing', style: TextStyle(fontSize: 13)),
 Text('Mike Chen', style: TextStyle(fontSize: 13)),
 Text('Heavy machinery o...', style: TextStyle(fontSize: 13)),
 RiskBadge.high(),
 Text('Operator certification, ...',
 style: TextStyle(fontSize: 13)),
 ActionButtons(),
 ],
 ],
 ),

 Align(
 alignment: Alignment.centerRight,
 child: ElevatedButton(
 onPressed: () => Navigator.push(context,
 MaterialPageRoute(builder: (_) => const SsherScreen3())),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: Colors.black,
 elevation: 0,
 padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(10)),
 ),
 child: const Text('Next'),
 ),
 ),
 ],
 );

 // --- Mobile layout ---
 if (isMobile) {
 return Scaffold(
 backgroundColor: Colors.grey[50],
 drawer: Drawer(
 width: sidebarWidth,
 child: SafeArea(
 child: InitiationLikeSidebar(
 activeItemLabel: 'SSHE Planning',
 showHeader: true,
 ),
 ),
 ),
 body: SafeArea(
 top: true,
 child: Column(
 children: [
 PlanningPhaseHeader(
 title: 'SSHER',
 breadcrumbPhase: 'Planning Phase',
 breadcrumbTitle: 'SSHE Planning',
 onBack: () => Navigator.maybePop(context), onExportPdf: _exportPdf),
 Expanded(
 child: SingleChildScrollView(
 padding: const EdgeInsets.all(24),
 child: content,
 ),
 ),
 ],
 ),
 ),
 );
 }

 // --- Desktop layout ---
 return Scaffold(
 backgroundColor: Colors.grey[50],
 body: SafeArea(
 top: true,
 child: Column(
 children: [
 PlanningPhaseHeader(
 title: 'SSHER',
 breadcrumbPhase: 'Planning Phase',
 breadcrumbTitle: 'SSHE Planning',
 onBack: () => Navigator.maybePop(context), onExportPdf: _exportPdf),
 Expanded(
 child: Row(
 children: [
 DraggableSidebar(
 openWidth: sidebarWidth,
 child: const InitiationLikeSidebar(
 activeItemLabel: 'SSHE Planning',
 ),
 ),
 Expanded(
 child: SingleChildScrollView(
 padding: const EdgeInsets.all(24),
 child: content,
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

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'SSHER Screen 2',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_ssher_screen_2_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

