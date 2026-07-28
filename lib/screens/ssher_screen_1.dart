import 'package:flutter/material.dart';
import 'package:ndu_project/screens/ssher_components.dart';
import 'package:ndu_project/screens/ssher_screen_2.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/unified_phase_header.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

class SsherScreen1 extends StatefulWidget {
 const SsherScreen1({super.key});

 @override
 State<SsherScreen1> createState() => _SsherScreen1State();
}

class _SsherScreen1State extends State<SsherScreen1> {
 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 final sidebarWidth = AppBreakpoints.sidebarWidth(context);

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
 child: Column(
 children: [
 // Plan Summary
 Container(
 margin: const EdgeInsets.only(bottom: 20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border:
 Border.all(color: Colors.grey.withOpacity(0.2)),
 ),
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 20, vertical: 14),
 decoration: BoxDecoration(
 color: Colors.blue.withOpacity(0.08),
 borderRadius: const BorderRadius.vertical(
 top: Radius.circular(12)),
 ),
 child: Row(
 children: [
 Container(
 width: 30,
 height: 30,
 decoration: BoxDecoration(
 color: Colors.blue.withOpacity(0.15),
 shape: BoxShape.circle),
 child: const Icon(Icons.receipt_long,
 size: 18, color: Colors.blue),
 ),
 const SizedBox(width: 12),
 const Expanded(
 child: Text('SSHER Plan Summary',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700)),
 ),
 ],
 ),
 ),
 Container(
 padding: const EdgeInsets.all(16),
 margin: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(8),
 border: Border.all(
 color: Colors.grey.withOpacity(0.25)),
 ),
 child: Text(
 'This SSHER plan encompasses comprehensive risk management across all operational domains. Safety protocols focus on workplace injury prevention and emergency response procedures. Security measures address both physical and cyber threats with multi- layered protection strategies. Health initiatives promote employee wellbeing and occupational health standards. Environmental considerations ensure sustainable practices and regulatory compliance. Regulatory frameworks maintain adherence to industry standards and legal requirements .',
 style: TextStyle(
 fontSize: 13, color: Colors.grey[700]),
 ),
 ),
 ],
 ),
 ),

 // Safety section
 SsherSectionCard(
 leadingIcon: Icons.health_and_safety,
 accentColor: const Color(0xFF34A853),
 title: 'Safety',
 subtitle:
 'Workplace safety protocols and risk management',
 detailsPlaceholder:
 'Comprehensive safety protocols including personal protective equipment requirements, emergency evacuation procedures, incident reporting systems , and regular safety training programs for all personnel .',
 itemsLabel: '12 Items',
 addButtonLabel: 'Add Safety Item',
 columns: const [
 '#',
 'Department',
 'Team Member',
 'Safety Concern',
 'Risk Level',
 'Mitigation Strategy',
 'Actions'
 ],
 rows: [
 [
 const Text('1', style: TextStyle(fontSize: 12)),
 const Text('Operations',
 style: TextStyle(fontSize: 13)),
 const Text('Sarah Johnson',
 style: TextStyle(fontSize: 13)),
 const Text('Chemical exposure i...',
 style: TextStyle(
 fontSize: 13, color: Colors.black87)),
 const RiskBadge.high(),
 const Text('Enhanced ventilation s...',
 style: TextStyle(fontSize: 13)),
 const ActionButtons(),
 ],
 [
 const Text('2', style: TextStyle(fontSize: 12)),
 const Text('Manufacturing',
 style: TextStyle(fontSize: 13)),
 const Text('Mike Chen',
 style: TextStyle(fontSize: 13)),
 const Text('Heavy machinery o...',
 style: TextStyle(fontSize: 13)),
 const RiskBadge.high(),
 const Text('Operator certification, ...',
 style: TextStyle(fontSize: 13)),
 const ActionButtons(),
 ],
 ],
 ),

 // Security header only (as shown in first screenshot)
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
 rows: const [],
 ),

 // navigation to next page
 Align(
 alignment: Alignment.centerRight,
 child: ElevatedButton(
 onPressed: () => Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => const SsherScreen2())),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: Colors.black,
 elevation: 0,
 padding: const EdgeInsets.symmetric(
 horizontal: 22, vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(10)),
 ),
 child: const Text('Next'),
 ),
 ),
 ],
 ),
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
 child: Column(
 children: [
 // Plan Summary
 Container(
 margin: const EdgeInsets.only(bottom: 20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(
 color: Colors.grey.withOpacity(0.2)),
 ),
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 20, vertical: 14),
 decoration: BoxDecoration(
 color: Colors.blue.withOpacity(0.08),
 borderRadius: const BorderRadius.vertical(
 top: Radius.circular(12)),
 ),
 child: Row(
 children: [
 Container(
 width: 30,
 height: 30,
 decoration: BoxDecoration(
 color:
 Colors.blue.withOpacity(0.15),
 shape: BoxShape.circle),
 child: const Icon(Icons.receipt_long,
 size: 18, color: Colors.blue),
 ),
 const SizedBox(width: 12),
 const Expanded(
 child: Text('SSHER Plan Summary',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700)),
 ),
 ],
 ),
 ),
 Container(
 padding: const EdgeInsets.all(16),
 margin: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(8),
 border: Border.all(
 color: Colors.grey.withOpacity(0.25)),
 ),
 child: Text(
 'This SSHER plan encompasses comprehensive risk management across all operational domains. Safety protocols focus on workplace injury prevention and emergency response procedures. Security measures address both physical and cyber threats with multi- layered protection strategies. Health initiatives promote employee wellbeing and occupational health standards. Environmental considerations ensure sustainable practices and regulatory compliance. Regulatory frameworks maintain adherence to industry standards and legal requirements .',
 style: TextStyle(
 fontSize: 13, color: Colors.grey[700]),
 ),
 ),
 ],
 ),
 ),

 // Safety section
 SsherSectionCard(
 leadingIcon: Icons.health_and_safety,
 accentColor: const Color(0xFF34A853),
 title: 'Safety',
 subtitle:
 'Workplace safety protocols and risk management',
 detailsPlaceholder:
 'Comprehensive safety protocols including personal protective equipment requirements, emergency evacuation procedures, incident reporting systems , and regular safety training programs for all personnel .',
 itemsLabel: '12 Items',
 addButtonLabel: 'Add Safety Item',
 columns: const [
 '#',
 'Department',
 'Team Member',
 'Safety Concern',
 'Risk Level',
 'Mitigation Strategy',
 'Actions'
 ],
 rows: [
 [
 const Text('1', style: TextStyle(fontSize: 12)),
 const Text('Operations',
 style: TextStyle(fontSize: 13)),
 const Text('Sarah Johnson',
 style: TextStyle(fontSize: 13)),
 const Text('Chemical exposure i...',
 style: TextStyle(
 fontSize: 13, color: Colors.black87)),
 const RiskBadge.high(),
 const Text('Enhanced ventilation s...',
 style: TextStyle(fontSize: 13)),
 const ActionButtons(),
 ],
 [
 const Text('2', style: TextStyle(fontSize: 12)),
 const Text('Manufacturing',
 style: TextStyle(fontSize: 13)),
 const Text('Mike Chen',
 style: TextStyle(fontSize: 13)),
 const Text('Heavy machinery o...',
 style: TextStyle(fontSize: 13)),
 const RiskBadge.high(),
 const Text('Operator certification, ...',
 style: TextStyle(fontSize: 13)),
 const ActionButtons(),
 ],
 ],
 ),

 // Security header only (as shown in first screenshot)
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
 rows: const [],
 ),

 // navigation to next page
 Align(
 alignment: Alignment.centerRight,
 child: ElevatedButton(
 onPressed: () => Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => const SsherScreen2())),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: Colors.black,
 elevation: 0,
 padding: const EdgeInsets.symmetric(
 horizontal: 22, vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(10)),
 ),
 child: const Text('Next'),
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
 ),
 ),
 );
 
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'SSHER Screen 1',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_ssher_screen_1_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

