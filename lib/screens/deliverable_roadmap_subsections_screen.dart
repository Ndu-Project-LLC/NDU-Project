import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/roadmap_deliverable.dart';
import '../models/roadmap_sprint.dart';
import '../services/roadmap_service.dart';
import '../providers/project_data_provider.dart';
import '../widgets/initiation_like_sidebar.dart';
import '../widgets/draggable_sidebar.dart';
import '../widgets/kaz_ai_chat_bubble.dart';
import '../widgets/responsive.dart';
import '../widgets/planning_ai_notes_card.dart';
import '../widgets/launch_phase_navigation.dart';
import '../utils/planning_phase_navigation.dart';
import '../services/firebase_auth_service.dart';
import '../services/user_service.dart';
import '../widgets/planning_phase_header.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

const Color _kBackground = Color(0xFFF9FAFC);
const Color _kHeadline = Color(0xFF111827);
const Color _kMuted = Color(0xFF6B7280);
const Color _kCardBorder = Color(0xFFE5E7EB);

class DeliverableRoadmapAgileMapOutScreen extends StatefulWidget {
 const DeliverableRoadmapAgileMapOutScreen({super.key});

 @override
 State<DeliverableRoadmapAgileMapOutScreen> createState() =>
 _DeliverableRoadmapAgileMapOutScreenState();
}

class _DeliverableRoadmapAgileMapOutScreenState
 extends State<DeliverableRoadmapAgileMapOutScreen> {
 List<RoadmapSprint> _sprints = [];
 List<RoadmapDeliverable> _deliverables = [];
 bool _isLoading = false;

 String? get _projectId {
 try {
 return ProjectDataInherited.maybeOf(context)?.projectData.projectId;
 } catch (e) {
 return null;
 }
 }

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
 }

 @override
 void didChangeDependencies() {
 super.didChangeDependencies();
 if (!_hasLoaded) {
 _loadData();
 }
 }

 bool _hasLoaded = false;

 Future<void> _loadData() async {
 final projectId = _projectId;
 if (projectId == null) {
 await Future.delayed(const Duration(milliseconds: 300));
 if (!mounted) return;
 final retryId = _projectId;
 if (retryId == null) return;
 return _loadDataWithId(retryId);
 }
 return _loadDataWithId(projectId);
 }

 Future<void> _loadDataWithId(String projectId) async {
 if (_hasLoaded) return;
 setState(() => _isLoading = true);
 try {
 final result = await RoadmapService.loadAll(projectId: projectId);
 if (mounted) {
 setState(() {
 _sprints = result.sprints;
 _deliverables = result.deliverables;
 _isLoading = false;
 _hasLoaded = true;
 });
 }
 } catch (e) {
 debugPrint('Error loading roadmap: $e');
 if (mounted) setState(() => _isLoading = false);
 }
 }

 int _pointsForSprint(String sprintId) {
 return _deliverables
 .where((d) => d.sprintId == sprintId)
 .fold<int>(0, (sum, d) => sum + d.storyPoints);
 }

 int _completedPointsForSprint(String sprintId) {
 return _deliverables
 .where((d) =>
 d.sprintId == sprintId &&
 d.status == RoadmapDeliverableStatus.completed)
 .fold<int>(0, (sum, d) => sum + d.storyPoints);
 }

 int get _totalPoints =>
 _deliverables.fold<int>(0, (sum, d) => sum + d.storyPoints);
 int get _completedPoints => _deliverables
 .where((d) => d.status == RoadmapDeliverableStatus.completed)
 .fold<int>(0, (sum, d) => sum + d.storyPoints);
 int get _avgVelocity {
 if (_sprints.isEmpty) return 0;
 final sprints = _sprints.where((s) {
 final pts = _completedPointsForSprint(s.id);
 return pts > 0;
 }).toList();
 if (sprints.isEmpty) return 0;
 final total =
 sprints.fold<int>(0, (sum, s) => sum + _completedPointsForSprint(s.id));
 return (total / sprints.length).round();
 }

 List<_DeliveryWave> _buildWaves() {
 if (_sprints.isEmpty) return [];
 final waveSize = 2;
 final waves = <_DeliveryWave>[];
 for (var i = 0; i < _sprints.length; i += waveSize) {
 final waveSprints =
 _sprints.sublist(i, (i + waveSize).clamp(0, _sprints.length));
 final waveDeliverables = _deliverables
 .where((d) => waveSprints.any((s) => s.id == d.sprintId))
 .toList();
 waves.add(_DeliveryWave(
 index: waves.length + 1,
 sprints: waveSprints,
 deliverables: waveDeliverables,
 ));
 }
 return waves;
 }

 List<_DependencyLink> _buildDependencies() {
 final links = <_DependencyLink>[];
 for (final d in _deliverables) {
 for (final depId in d.dependencies) {
 final dep = _deliverables.firstWhere(
 (dd) => dd.id == depId,
 orElse: () => RoadmapDeliverable(title: '(unknown)'),
 );
 links.add(_DependencyLink(
 from: dep.title,
 to: d.title,
 isBlocked: d.status == RoadmapDeliverableStatus.blocked ||
 dep.status != RoadmapDeliverableStatus.completed,
 ));
 }
 }
 return links;
 }

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 final hPad = isMobile ? 20.0 : 32.0;

 return Scaffold(
 backgroundColor: _kBackground,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Agile Delivery Model - Agile Map Out'),
 ),
 Expanded(
 child: Stack(
 children: [
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Agile Delivery Model - Agile Map Out',
 ),
 ),
 SingleChildScrollView(
 padding:
 EdgeInsets.symmetric(horizontal: hPad, vertical: 24),
 child: LayoutBuilder(
 builder: (context, constraints) {
 final width = constraints.maxWidth;
 const gap = 24.0;
 final twoCol = width >= 980;
 final halfWidth = twoCol ? (width - gap) / 2 : width;
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(title: 'Agile Map Out', onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 _TopHeader(
 onBack: () =>
 PlanningPhaseNavigation.goToPrevious(context,
 'agile_map_out'),
 onForward: () => PlanningPhaseNavigation.goToNext(
 context, 'agile_map_out'),
 ),
 const SizedBox(height: 12),
 const Text(
 'Delivery waves, velocity, dependencies & milestones',
 style: TextStyle(fontSize: 14, color: _kMuted),
 ),
 const SizedBox(height: 20),
 const PlanningAiNotesCard(
 title: 'Notes',
 sectionLabel: 'Agile Map Out',
 noteKey:
 'planning_deliverable_roadmap_agile_map_out',
 checkpoint: 'agile_map_out',
 description:
 'Capture sprint priorities, dependencies, and release sequencing.',
 ),
 const SizedBox(height: 24),
 if (_isLoading)
 const Center(
 child: Padding(
 padding: EdgeInsets.all(48),
 child: CircularProgressIndicator(),
 ))
 else ...[
 _buildMetricsRow(),
 const SizedBox(height: 24),
 Wrap(
 spacing: gap,
 runSpacing: gap,
 children: [
 SizedBox(
 width: halfWidth,
 child: _buildDeliveryWavesCard(),
 ),
 SizedBox(
 width: halfWidth,
 child: _buildVelocityCard(),
 ),
 ],
 ),
 const SizedBox(height: 24),
 Wrap(
 spacing: gap,
 runSpacing: gap,
 children: [
 SizedBox(
 width: halfWidth,
 child: _buildDependenciesCard(),
 ),
 SizedBox(
 width: halfWidth,
 child: _buildMilestonesCard(),
 ),
 ],
 ),
 ],
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: PlanningPhaseNavigation.backLabel(
 'agile_map_out'),
 nextLabel: PlanningPhaseNavigation.nextLabel(
 'agile_map_out'),
 onBack: () =>
 PlanningPhaseNavigation.goToPrevious(context,
 'agile_map_out'),
 onNext: () => PlanningPhaseNavigation.goToNext(
 context, 'agile_map_out'),
 ),
 const SizedBox(height: 40),
 ],
 );
 },
 ),
 ),
 const Positioned(
 right: 24,
 bottom: 24,
 child: KazAiChatBubble(positioned: false)),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildMetricsRow() {
 return Wrap(
 spacing: 16,
 runSpacing: 16,
 children: [
 _MetricCard(
 label: 'Total Sprints',
 value: '${_sprints.length}',
 accent: const Color(0xFF8B5CF6)),
 _MetricCard(
 label: 'Est. Velocity',
 value: '$_avgVelocity pts/sprint',
 accent: const Color(0xFF10B981)),
 _MetricCard(
 label: 'Total Story Points',
 value: '$_totalPoints',
 accent: const Color(0xFF2563EB)),
 _MetricCard(
 label: 'Progress',
 value: _totalPoints > 0
 ? '${((_completedPoints / _totalPoints) * 100).round()}%'
 : '0%',
 accent: const Color(0xFFF59E0B)),
 ],
 );
 }

 Widget _buildDeliveryWavesCard() {
 final waves = _buildWaves();
 return _SectionCard(
 title: 'Delivery Waves',
 subtitle: 'Sprints grouped into delivery waves with theme goals.',
 child: waves.isEmpty
 ? const _EmptySection(
 message: 'Create sprints in Roadmap Overview to see waves here.')
 : Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 for (final wave in waves)
 _WaveRow(
 wave: wave,
 deliverables: _deliverables,
 sprints: _sprints,
 ),
 ],
 ),
 );
 }

 Widget _buildVelocityCard() {
 return _SectionCard(
 title: 'Sprint Velocity Estimation',
 subtitle: 'Planned vs. completed story points per sprint.',
 child: _sprints.isEmpty
 ? const _EmptySection(message: 'No sprints to show velocity data.')
 : Column(
 children: [
 _VelocityHeader(),
 for (final sprint in _sprints)
 _VelocityRow(
 sprintName: sprint.name,
 planned: _pointsForSprint(sprint.id),
 completed: _completedPointsForSprint(sprint.id),
 ),
 ],
 ),
 );
 }

 Widget _buildDependenciesCard() {
 final deps = _buildDependencies();
 return _SectionCard(
 title: 'Dependency Tracker',
 subtitle: 'Deliverable dependencies and blocker flags.',
 child: deps.isEmpty
 ? const _EmptySection(
 message:
 'No dependencies defined. Add dependencies when creating deliverables.')
 : Column(
 children: [
 for (final link in deps) _DependencyRow(link: link),
 ],
 ),
 );
 }

 Widget _buildMilestonesCard() {
 final milestones = <_Milestone>[];
 for (final sprint in _sprints) {
 final sprintItems =
 _deliverables.where((d) => d.sprintId == sprint.id).toList();
 final completed = sprintItems
 .where((d) => d.status == RoadmapDeliverableStatus.completed)
 .length;
 final total = sprintItems.length;
 milestones.add(_Milestone(
 name: sprint.name,
 targetDate: sprint.endDate,
 total: total,
 completed: completed,
 ));
 }

 return _SectionCard(
 title: 'Release Milestones',
 subtitle: 'Sprint end-dates as release checkpoints.',
 child: milestones.isEmpty
 ? const _EmptySection(
 message: 'Create sprints with end dates to see milestones.')
 : Column(
 children: [
 for (final m in milestones) _MilestoneRow(milestone: m),
 ],
 ),
 );
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Deliverable Roadmap Subsections',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_deliverable_roadmap_subsections_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

// ── Data classes ─────────────────────────────────────────────

class _DeliveryWave {
 final int index;
 final List<RoadmapSprint> sprints;
 final List<RoadmapDeliverable> deliverables;

 const _DeliveryWave({
 required this.index,
 required this.sprints,
 required this.deliverables,
 });

 int get totalPoints =>
 deliverables.fold<int>(0, (sum, d) => sum + d.storyPoints);
 int get completedPoints => deliverables
 .where((d) => d.status == RoadmapDeliverableStatus.completed)
 .fold<int>(0, (sum, d) => sum + d.storyPoints);
}

class _DependencyLink {
 final String from;
 final String to;
 final bool isBlocked;
 const _DependencyLink(
 {required this.from, required this.to, required this.isBlocked});
}

class _Milestone {
 final String name;
 final DateTime? targetDate;
 final int total;
 final int completed;
 const _Milestone(
 {required this.name,
 this.targetDate,
 required this.total,
 required this.completed});
}

// ── Widgets ──────────────────────────────────────────────────

class _TopHeader extends StatelessWidget {
 const _TopHeader({required this.onBack, required this.onForward});
 final VoidCallback onBack;
 final VoidCallback onForward;

 @override
 Widget build(BuildContext context) {
 return Row(
 children: [
 _CircleBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
 const SizedBox(width: 12),
 _CircleBtn(icon: Icons.arrow_forward_ios_rounded, onTap: onForward),
 const SizedBox(width: 16),
 const Text('Agile Map Out',
 style: TextStyle(
 fontSize: 22, fontWeight: FontWeight.w700, color: _kHeadline)),
 const Spacer(),
 const SizedBox(width: 12),
 const _UserChip(),
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
 borderRadius: BorderRadius.circular(18),
 child: Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: Colors.white,
 shape: BoxShape.circle,
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Icon(icon, size: 16, color: _kMuted),
 ),
 );
 }
}

class _UserChip extends StatelessWidget {
 const _UserChip();

 @override
 Widget build(BuildContext context) {
 final user = FirebaseAuth.instance.currentUser;
 final displayName =
 FirebaseAuthService.displayNameOrEmail(fallback: 'User');
 final email = user?.email ?? '';

 return StreamBuilder<bool>(
 stream: UserService.watchAdminStatus(),
 builder: (context, snapshot) {
 final isAdmin = snapshot.data ?? UserService.isAdminEmail(email);
 final role = isAdmin ? 'Admin' : 'Member';
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CircleAvatar(
 radius: 16,
 backgroundColor: const Color(0xFFE5E7EB),
 backgroundImage: user?.photoURL != null
 ? NetworkImage(user!.photoURL!)
 : null,
 child: user?.photoURL == null
 ? Text(
 displayName.isNotEmpty
 ? displayName[0].toUpperCase()
 : 'U',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF374151)),
 )
 : null,
 ),
 const SizedBox(width: 8),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(displayName,
 style: const TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600)),
 Text(role,
 style: const TextStyle(
 fontSize: 10, color: Color(0xFF6B7280))),
 ],
 ),
 const SizedBox(width: 6),
 const Icon(Icons.keyboard_arrow_down,
 size: 18, color: Color(0xFF9CA3AF)),
 ],
 ),
 );
 },
 );
 }
}

class _MetricCard extends StatelessWidget {
 const _MetricCard(
 {required this.label, required this.value, required this.accent});
 final String label;
 final String value;
 final Color accent;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: 190,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: _kCardBorder),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 6)),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label, style: const TextStyle(fontSize: 12, color: _kMuted)),
 const SizedBox(height: 6),
 Text(value,
 style: TextStyle(
 fontSize: 20, fontWeight: FontWeight.w700, color: accent)),
 ],
 ),
 );
 }
}

class _SectionCard extends StatelessWidget {
 const _SectionCard(
 {required this.title, required this.subtitle, required this.child});
 final String title;
 final String subtitle;
 final Widget child;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: _kCardBorder),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 6)),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(title,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: _kHeadline)),
 const SizedBox(height: 4),
 Text(subtitle,
 style:
 const TextStyle(fontSize: 12, color: _kMuted, height: 1.4)),
 const SizedBox(height: 16),
 child,
 ],
 ),
 );
 }
}

class _EmptySection extends StatelessWidget {
 const _EmptySection({required this.message});
 final String message;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.symmetric(vertical: 12),
 child: Text(message,
 style: const TextStyle(
 fontSize: 12, color: _kMuted, fontStyle: FontStyle.italic)),
 );
 }
}

class _WaveRow extends StatelessWidget {
 const _WaveRow({
 required this.wave,
 required this.deliverables,
 required this.sprints,
 });

 final _DeliveryWave wave;
 final List<RoadmapDeliverable> deliverables;
 final List<RoadmapSprint> sprints;

 @override
 Widget build(BuildContext context) {
 final sprintNames = wave.sprints.map((s) => s.name).join(', ');
 final progress = wave.totalPoints > 0
 ? ((wave.completedPoints / wave.totalPoints) * 100).round()
 : 0;

 return Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFC),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: _kCardBorder),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 28,
 height: 28,
 decoration: BoxDecoration(
 color: const Color(0xFF8B5CF6).withOpacity(0.12),
 borderRadius: BorderRadius.circular(8),
 ),
 alignment: Alignment.center,
 child: Text(
 'W${wave.index}',
 style: const TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF8B5CF6),
 ),
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Text(sprintNames,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: _kHeadline)),
 ),
 Text('${wave.totalPoints} pts',
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: _kMuted)),
 ],
 ),
 const SizedBox(height: 10),
 ClipRRect(
 borderRadius: BorderRadius.circular(6),
 child: LinearProgressIndicator(
 value: progress / 100,
 backgroundColor: const Color(0xFFE5E7EB),
 valueColor:
 const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
 minHeight: 6,
 ),
 ),
 const SizedBox(height: 6),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 '${wave.completedPoints}/${wave.totalPoints} pts completed',
 style: const TextStyle(fontSize: 10, color: _kMuted),
 ),
 Text(
 '$progress%',
 style: const TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: Color(0xFF8B5CF6)),
 ),
 ],
 ),
 if (wave.deliverables.isNotEmpty) ...[
 const SizedBox(height: 10),
 ...wave.deliverables.take(3).map((d) => Padding(
 padding: const EdgeInsets.only(bottom: 3),
 child: Row(
 children: [
 Container(
 width: 6,
 height: 6,
 decoration: BoxDecoration(
 color: d.status == RoadmapDeliverableStatus.completed
 ? const Color(0xFF10B981)
 : const Color(0xFFD1D5DB),
 shape: BoxShape.circle,
 ),
 ),
 const SizedBox(width: 6),
 Expanded(
 child: Text(d.title,
 style: const TextStyle(
 fontSize: 11, color: _kHeadline),
 maxLines: 1,
 overflow: TextOverflow.ellipsis),
 ),
 ],
 ),
 )),
 if (wave.deliverables.length > 3)
 Padding(
 padding: const EdgeInsets.only(top: 4),
 child: Text(
 '+${wave.deliverables.length - 3} more',
 style: const TextStyle(fontSize: 10, color: _kMuted),
 ),
 ),
 ],
 ],
 ),
 );
 }
}

class _VelocityHeader extends StatelessWidget {
 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.only(bottom: 8),
 decoration: const BoxDecoration(
 border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
 ),
 child: const Row(
 children: [
 SizedBox(
 width: 100,
 child: Text('Sprint',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: _kMuted))),
 SizedBox(
 width: 70,
 child: Text('Planned',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: _kMuted),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 70,
 child: Text('Done',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: _kMuted),
 textAlign: TextAlign.center)),
 Expanded(
 child: Text('Delta',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: _kMuted),
 textAlign: TextAlign.center)),
 ],
 ),
 );
 }
}

class _VelocityRow extends StatelessWidget {
 const _VelocityRow({
 required this.sprintName,
 required this.planned,
 required this.completed,
 });
 final String sprintName;
 final int planned;
 final int completed;

 @override
 Widget build(BuildContext context) {
 final delta = completed - planned;
 final deltaColor =
 delta >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444);
 final deltaLabel = delta >= 0 ? '+$delta' : '$delta';

 return Container(
 padding: const EdgeInsets.symmetric(vertical: 8),
 decoration: const BoxDecoration(
 border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
 ),
 child: Row(
 children: [
 SizedBox(
 width: 100,
 child: Text(sprintName,
 style: const TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600))),
 SizedBox(
 width: 70,
 child: Text('$planned',
 style: const TextStyle(fontSize: 12, color: _kMuted),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 70,
 child: Text('$completed',
 style: const TextStyle(fontSize: 12, color: _kMuted),
 textAlign: TextAlign.center)),
 Expanded(
 child: Text(deltaLabel,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: deltaColor),
 textAlign: TextAlign.center)),
 ],
 ),
 );
 }
}

class _DependencyRow extends StatelessWidget {
 const _DependencyRow({required this.link});
 final _DependencyLink link;

 @override
 Widget build(BuildContext context) {
 return Container(
 margin: const EdgeInsets.only(bottom: 8),
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(
 color:
 link.isBlocked ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(
 color: link.isBlocked
 ? const Color(0xFFFECACA)
 : const Color(0xFFBBF7D0)),
 ),
 child: Row(
 children: [
 Icon(
 link.isBlocked ? Icons.warning_amber : Icons.check_circle,
 size: 14,
 color: link.isBlocked
 ? const Color(0xFFEF4444)
 : const Color(0xFF10B981),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: RichText(
 text: TextSpan(
 style: const TextStyle(fontSize: 11, color: _kHeadline),
 children: [
 TextSpan(
 text: link.from,
 style: const TextStyle(fontWeight: FontWeight.w600)),
 const TextSpan(text: ' → '),
 TextSpan(
 text: link.to,
 style: const TextStyle(fontWeight: FontWeight.w600)),
 ],
 ),
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: (link.isBlocked
 ? const Color(0xFFEF4444)
 : const Color(0xFF10B981))
 .withOpacity(0.12),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Text(
 link.isBlocked ? 'Blocked' : 'Clear',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: link.isBlocked
 ? const Color(0xFFEF4444)
 : const Color(0xFF10B981),
 ),
 ),
 ),
 ],
 ),
 );
 }
}

class _MilestoneRow extends StatelessWidget {
 const _MilestoneRow({required this.milestone});
 final _Milestone milestone;

 @override
 Widget build(BuildContext context) {
 final pct = milestone.total > 0
 ? ((milestone.completed / milestone.total) * 100).round()
 : 0;
 final isComplete = pct == 100 && milestone.total > 0;
 final dateLabel = milestone.targetDate != null
 ? '${milestone.targetDate!.month}/${milestone.targetDate!.day}/${milestone.targetDate!.year}'
 : 'No date';

 return Container(
 margin: const EdgeInsets.only(bottom: 10),
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFC),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: _kCardBorder),
 ),
 child: Row(
 children: [
 Container(
 width: 32,
 height: 32,
 decoration: BoxDecoration(
 color: (isComplete
 ? const Color(0xFF10B981)
 : const Color(0xFF2563EB))
 .withOpacity(0.12),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Icon(
 isComplete ? Icons.flag : Icons.outlined_flag,
 size: 16,
 color: isComplete
 ? const Color(0xFF10B981)
 : const Color(0xFF2563EB),
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(milestone.name,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: _kHeadline)),
 const SizedBox(height: 2),
 Text(
 '$dateLabel · ${milestone.completed}/${milestone.total} done ($pct%)',
 style: const TextStyle(fontSize: 10, color: _kMuted),
 ),
 ],
 ),
 ),
 if (isComplete)
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: const Color(0xFF10B981).withOpacity(0.12),
 borderRadius: BorderRadius.circular(8),
 ),
 child: const Text('Complete',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: Color(0xFF10B981))),
 ),
 ],
 ),
 );
 }
}
