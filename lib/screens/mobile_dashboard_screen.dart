import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/widgets/unified_phase_header.dart';

import '../models/program_model.dart';
import '../services/project_service.dart';
import '../services/program_service.dart';
import 'project_dashboard_screen.dart';
import 'program_dashboard_mobile_screen.dart';

class MobileDashboardScreen extends StatelessWidget {
 const MobileDashboardScreen({super.key});

 @override
 Widget build(BuildContext context) {
 final user = FirebaseAuth.instance.currentUser;
 final projectStream = user == null
 ? Stream.value(const <ProjectRecord>[])
 : ProjectService.streamProjects(ownerId: user.uid, limit: 50);
 final programStream = user == null
 ? Stream.value(const <ProgramModel>[])
 : ProgramService.streamPrograms(ownerId: user.uid);

 return Scaffold(
 appBar: AppBar(
 title: const Text('NDU mobile lightspeed'),
 elevation: 0,
 backgroundColor: Colors.white,
 foregroundColor: const Color(0xFF111827),
 actions: const [
 Padding(
 padding: EdgeInsets.only(right: 10),
 child: UnifiedProfileMenu(compact: true),
 ),
 ],
 ),
 backgroundColor: const Color(0xFFF8F9FB),
 body: SafeArea(
 top: true,
 child: StreamBuilder<List<ProjectRecord>>(
 stream: projectStream,
 builder: (context, projectSnapshot) {
 final projects = projectSnapshot.data ?? const <ProjectRecord>[];
 final topProjects = _topInvestmentProjects(projects);

 return StreamBuilder<List<ProgramModel>>(
 stream: programStream,
 builder: (context, programSnapshot) {
 final programs = programSnapshot.data ?? const <ProgramModel>[];
 final statCards =
 _buildStatusCards(context, projects, programs);
 return SingleChildScrollView(
 padding:
 const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Status overview',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF0F172A)),
 ),
 const SizedBox(height: 12),
 Wrap(
 runSpacing: 12,
 spacing: 12,
 children: statCards,
 ),
 const SizedBox(height: 24),
 _buildProgramsPanel(context, programs),
 const SizedBox(height: 24),
 _buildCostComparison(topProjects),
 const SizedBox(height: 32),
 ElevatedButton(
 onPressed: () => Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => const ProjectDashboardScreen()),
 ),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFC107),
 foregroundColor: const Color(0xFF111827),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(14)),
 padding: const EdgeInsets.symmetric(
 horizontal: 24, vertical: 14),
 ),
 child: const Text('Open full dashboard',
 style: TextStyle(fontWeight: FontWeight.w700)),
 ),
 ],
 ),
 );
 },
 );
 },
 ),
 ),
 );
 }

 List<Widget> _buildStatusCards(BuildContext context,
 List<ProjectRecord> projects, List<ProgramModel> programs) {
 final projectCount = projects.length;
 final basicProjectCount =
 projects.where((project) => project.isBasicPlanProject).length;
 final activeCount = projects
 .where((project) => project.status.toLowerCase().contains('progress'))
 .length;

 final programCount = programs.length;
 final tiles = [
 _MobileStatusCard(
 label: 'Regular projects',
 value: '$basicProjectCount',
 caption: 'Starter plan',
 color: Colors.teal.shade600,
 icon: Icons.folder_special_rounded,
 ),
 _MobileStatusCard(
 label: 'Projects',
 value: '$projectCount',
 caption: 'Active workspaces',
 color: Colors.blue.shade600,
 icon: Icons.folder_open_rounded,
 ),
 _MobileStatusCard(
 label: 'Active work',
 value: '$activeCount',
 caption: 'In progress',
 color: Colors.purple.shade600,
 icon: Icons.autorenew_rounded,
 ),
 _MobileStatusCard(
 label: 'Programs',
 value: '$programCount',
 caption: 'Grouped initiatives',
 color: Colors.amber.shade700,
 icon: Icons.layers_outlined,
 ),
 ];

 return tiles;
 }

 Widget _buildProgramsPanel(
 BuildContext context, List<ProgramModel> programs) {
 final preview = programs.isEmpty ? const [] : programs.take(3).toList();
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 14,
 offset: const Offset(0, 10)),
 ]),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('Programs quick look',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
 const SizedBox(height: 12),
 if (preview.isEmpty)
 const Text('Create a program to see live data.',
 style: TextStyle(color: Color(0xFF6B7280)))
 else ...[
 for (final program in preview)
 Padding(
 padding: const EdgeInsets.symmetric(vertical: 6),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 program.name.isEmpty
 ? 'Untitled program'
 : program.name,
 style:
 const TextStyle(fontWeight: FontWeight.w600)),
 const SizedBox(height: 4),
 Text('${program.projectIds.length} projects'),
 ],
 ),
 ),
 TextButton(
 onPressed: () => Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) =>
 const ProgramDashboardMobileScreen()),
 ),
 style: TextButton.styleFrom(
 minimumSize: const Size(72, 36),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 backgroundColor: const Color(0xFFF3F4F6),
 foregroundColor: const Color(0xFF1F2937),
 ),
 child: const Text('View'),
 ),
 ],
 ),
 ),
 if (programs.length > preview.length)
 Text('+${programs.length - preview.length} more programs',
 style: const TextStyle(color: Color(0xFF9CA3AF))),
 ],
 ],
 ),
 );
 }

 Widget _buildCostComparison(List<_MobileCostPoint> bars) {
 if (bars.isEmpty) {
 return const Text('No investment data yet.',
 style: TextStyle(color: Color(0xFF6B7280)));
 }

 final maxValue = bars.map((item) => item.value).fold<double>(0, math.max);
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('Project cost comparison',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
 const SizedBox(height: 12),
 SizedBox(
 height: 140,
 child: ListView.separated(
 scrollDirection: Axis.horizontal,
 itemCount: bars.length,
 separatorBuilder: (_, __) => const SizedBox(width: 12),
 itemBuilder: (context, index) {
 final bar = bars[index];
 final normalizedHeight =
 maxValue == 0 ? 80.0 : 60 + (bar.value / maxValue) * 60;

 return Column(
 children: [
 Container(
 width: 48,
 height: normalizedHeight,
 decoration: BoxDecoration(
 color: const Color(0xFF10B981),
 borderRadius: BorderRadius.circular(12),
 ),
 ),
 const SizedBox(height: 8),
 SizedBox(
 width: 72,
 child: Text(bar.label,
 style: const TextStyle(fontSize: 11),
 textAlign: TextAlign.center,
 maxLines: 2,
 overflow: TextOverflow.ellipsis),
 ),
 const SizedBox(height: 4),
 Text(bar.formattedValue,
 style: const TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600)),
 ],
 );
 },
 ),
 ),
 ],
 );
 }

 List<_MobileCostPoint> _topInvestmentProjects(List<ProjectRecord> projects) {
 final sorted = [...projects]
 ..sort((a, b) => b.investmentMillions.compareTo(a.investmentMillions));
 return sorted.take(6).map((project) {
 return _MobileCostPoint(
 label: project.name.isEmpty ? 'Untitled' : project.name,
 value: project.investmentMillions,
 formattedValue: '\$${project.investmentMillions.toStringAsFixed(1)}M',
 );
 }).toList();
 }
}

class _MobileStatusCard extends StatelessWidget {
 const _MobileStatusCard({
 required this.label,
 required this.value,
 required this.caption,
 required this.color,
 required this.icon,
 });

 final String label;
 final String value;
 final String caption;
 final IconData icon;
 final Color color;

 @override
 Widget build(BuildContext context) {
 return SizedBox(
 width: 160,
 child: Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 10,
 offset: const Offset(0, 6))
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Icon(icon, color: color),
 const SizedBox(height: 10),
 Text(value,
 style:
 const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
 const SizedBox(height: 4),
 Text(label,
 style:
 const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 const SizedBox(height: 2),
 Text(caption,
 style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
 ],
 ),
 ),
 );
 }
}

class _MobileCostPoint {
 const _MobileCostPoint(
 {required this.label, required this.value, required this.formattedValue});

 final String label;
 final double value;
 final String formattedValue;
}
