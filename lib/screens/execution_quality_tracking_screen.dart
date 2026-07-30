/// Execution Quality Tracking Screen
/// Comprehensive quality tracking during project execution phase.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/execution_quality_tracking_model.dart';
import 'package:ndu_project/models/project_data_model.dart' hide AuditResultStatus;
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/execution_quality_tracking_service.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/responsive.dart';

enum _ExecQualityTab { dashboard, objectives, inspections, audits, correctiveActions, coq }

class ExecutionQualityTrackingScreen extends StatefulWidget {
  const ExecutionQualityTrackingScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ExecutionQualityTrackingScreen(),
      ),
    );
  }

  @override
  State<ExecutionQualityTrackingScreen> createState() => 
      _ExecutionQualityTrackingScreenState();
}

class _ExecutionQualityTrackingScreenState extends State<ExecutionQualityTrackingScreen> 
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;
  _ExecQualityTab _selectedTab = _ExecQualityTab.dashboard;
  
  ExecutionQualityTrackingData? _trackingData;
  bool _loading = true;
  bool _seeding = false;
  bool _syncingCalendar = false;
  String? _errorMessage;
  
  final ExecutionQualityTrackingService _service = 
      ExecutionQualityTrackingService.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _ExecQualityTab.values.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadData();
  }

  void _onTabChanged() {
    if (_tabController.index != _selectedTab.index) {
      setState(() => _selectedTab = _ExecQualityTab.values[_tabController.index]);
    }
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _errorMessage = null; });
    
    try {
      final provider = ProjectDataInherited.maybeOf(context);
      if (provider == null) {
        setState(() { 
          _loading = false; 
          _errorMessage = 'Project data not available'; 
        });
        return;
      }
      
      final projectId = provider.projectData.projectId;
      if (projectId == null || projectId.isEmpty) {
        // Try to seed from planning data directly
        await _seedFromPlanning(provider.projectData);
        return;
      }
      
      var trackingData = await _service.loadTrackingData(projectId: projectId);
      
      // If no data exists, try to seed from planning
      if (trackingData == null || !trackingData.seededFromPlanning) {
        await _seedFromPlanning(provider.projectData, projectId: projectId);
        return;
      }
      
      // Refresh dashboard snapshot
      await _service.refreshDashboard(projectId: projectId);
      trackingData = await _service.loadTrackingData(projectId: projectId);
      
      if (mounted) {
        setState(() => _trackingData = trackingData);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _seedFromPlanning(
    dynamic projectData, {
    String? projectId,
  }) async {
    setState(() => _seeding = true);
    
    try {
      final planningData = projectData.qualityManagementData;
      if (planningData == null) {
        throw Exception('No planning quality data available to seed from');
      }
      
      final effectiveProjectId = projectId ?? projectData.projectId ?? 'temp';
      
      final seededData = await _service.seedFromPlanningPhase(
        projectId: effectiveProjectId,
        planningData: planningData,
      );
      
      if (mounted) {
        setState(() => _trackingData = seededData);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Seeded ${seededData.objectives.length} objectives, '
              '${seededData.audits.length} audits, '
              '${seededData.inspections.length} inspections from Planning Phase'
            ),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Seeding failed: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  Future<void> _syncToCalendar() async {
    if (_trackingData == null) return;
    
    setState(() => _syncingCalendar = true);
    
    try {
      final provider = ProjectDataInherited.maybeOf(context);
      final projectId = provider?.projectData.projectId;
      if (projectId == null || projectId.isEmpty) throw Exception('No project ID');
      
      final syncedCount = await _service.syncAllPendingEvents(
        projectId: projectId,
        postedBy: 'System', // TODO: Get current user
      );
      
      // Reload data to get updated sync status
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📅 Synced $syncedCount events to Team Calendar'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Calendar sync failed: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncingCalendar = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    final padding = EdgeInsets.fromLTRB(
      isMobile ? 16 : 28,
      24,
      isMobile ? 16 : 28,
      120,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DraggableSidebar(
                  openWidth: AppBreakpoints.sidebarWidth(context),
                  child: const InitiationLikeSidebar(
                    activeItemLabel: 'Execution Quality Tracking',
                  ),
                ),
                Expanded(
                  child: _buildBody(padding),
                ),
              ],
            ),
            MobileSidebarHamburger(
              sidebar: const InitiationLikeSidebar(
                activeItemLabel: 'Execution Quality Tracking',
              ),
            ),
            const KazAiChatBubble(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(EdgeInsets padding) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _trackingData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Error loading quality data', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text(_errorMessage!, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlanningPhaseHeader(
            title: 'Execution Quality Tracking',
            onBack: () => PlanningPhaseNavigation.goToPrevious(
              context, 'execution_quality_tracking',
            ),
            onForward: () => PlanningPhaseNavigation.goToNext(
              context, 'execution_quality_tracking',
            ),
          ),
          const SizedBox(height: 18),
          
          // Seeded indicator and actions
          if (_trackingData?.seededFromPlanning == true)
            _buildSeededBanner(),
          
          const SizedBox(height: 14),
          
          // Tab bar
          _buildTabBar(),
          const SizedBox(height: 12),
          
          // Tab content
          SizedBox(
            height: MediaQuery.of(context).size.height - 300,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(),
                _buildObjectivesTab(),
                _buildInspectionsTab(),
                _buildAuditsTab(),
                _buildCorrectiveActionsTab(),
                _buildCoqTab(),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          LaunchPhaseNavigation(
            backLabel: PlanningPhaseNavigation.backLabel('execution_quality_tracking'),
            nextLabel: PlanningPhaseNavigation.nextLabel('execution_quality_tracking'),
            onBack: () => PlanningPhaseNavigation.goToPrevious(
              context, 'execution_quality_tracking',
            ),
            onNext: () => PlanningPhaseNavigation.goToNext(
              context, 'execution_quality_tracking',
            ),
            onSkip: () => PlanningPhaseNavigation.goToSkip(
              context, 'execution_quality_tracking',
            ),
            pageTitle: 'Quality Tracking',
          ),
        ],
      ),
    );
  }

  Widget _buildSeededBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.download_done_rounded, size: 20, color: Color(0xFF4F46E5)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seeded from Planning Phase',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF3730A3)),
                ),
                Text(
                  'Objectives: ${_trackingData?.objectives.length ?? 0} | '
                  'Audits: ${_trackingData?.audits.length ?? 0} | '
                  'Inspections: ${_trackingData?.inspections.length ?? 0}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _syncingCalendar ? null : _syncToCalendar,
            icon: _syncingCalendar 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.calendar_today_outlined),
            tooltip: 'Sync audit dates to Team Calendar',
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4B422),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: const Color(0xFF111827),

        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        tabs: _ExecQualityTab.values.map((tab) {
          return Tab(text: _getTabLabel(tab));
        }).toList(),
      ),
    );
  }

  String _getTabLabel(_ExecQualityTab tab) {
    switch (tab) {
      case _ExecQualityTab.dashboard: return 'Dashboard';
      case _ExecQualityTab.objectives: return 'Objectives';
      case _ExecQualityTab.inspections: return 'Inspections';
      case _ExecQualityTab.audits: return 'Audits';
      case _ExecQualityTab.correctiveActions: return 'Corrective Actions';
      case _ExecQualityTab.coq: return 'COQ';
    }
  }

  // ============================================================================
  // DASHBOARD TAB
  // ============================================================================

  Widget _buildDashboardTab() {
    final snapshot = _trackingData?.dashboardSnapshot ?? ExecutionDashboardSnapshot.empty();
    final overdueReport = _trackingData != null 
        ? _service.getOverdueReport(trackingData: _trackingData!)
        : null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Score Card
          _buildOverallScoreCard(snapshot),
          const SizedBox(height: 16),
          
          // Summary Cards Row
          Row(
            children: [
              Expanded(child: _buildSummaryCard('Objectives', snapshot.totalObjectives, snapshot.objectivesComplete, Icons.flag, const Color(0xFF3B82F6))),
              const SizedBox(width: 12),
              Expanded(child: _buildSummaryCard('Audits', snapshot.totalAudits, snapshot.auditsPassed, Icons.fact_check, const Color(0xFF8B5CF6))),
              const SizedBox(width: 12),
              Expanded(child: _buildSummaryCard('Inspections', snapshot.totalInspections, snapshot.inspectionsPassed, Icons.verified, const Color(0xFF10B981))),
            ],
          ),
          const SizedBox(height: 16),
          
          // Corrective Actions Status
          Row(
            children: [
              Expanded(
                child: _buildCaStatusCard(
                  open: snapshot.openCorrectiveActions,
                  overdue: snapshot.caOverdue,
                  critical: snapshot.caCritical,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOverdueAlertCard(overdueReport),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Quick Stats Grid
          _buildQuickStatsGrid(snapshot),
        ],
      ),
    );
  }

  Widget _buildOverallScoreCard(ExecutionDashboardSnapshot snapshot) {
    final score = snapshot.overallQualityScore;
    Color scoreColor;
    String grade;
    
    if (score >= 90) {
      scoreColor = const Color(0xFF10B981); grade = 'A';
    } else if (score >= 75) {
      scoreColor = const Color(0xFF3B82F6); grade = 'B';
    } else if (score >= 60) {
      scoreColor = const Color(0xFFF59E0B); grade = 'C';
    } else {
      scoreColor = const Color(0xFFEF4444); grade = 'D';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [scoreColor.withOpacity(0.1), scoreColor.withOpacity(0.05)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scoreColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text('Overall Quality Score', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          Text(score.toStringAsFixed(0), style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: scoreColor)),
          Text(grade, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: scoreColor.withOpacity(0.7))),
          const SizedBox(height: 4),
          Text(_getScoreInterpretation(score), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  String _getScoreInterpretation(double score) {
    if (score >= 90) return 'Excellent - On track';
    if (score >= 75) return 'Good - Minor attention needed';
    if (score >= 60) return 'Fair - Action required';
    return 'Needs Improvement - Immediate action required';
  }

  Widget _buildSummaryCard(String title, int total, int complete, IconData icon, Color color) {
    final percent = total > 0 ? ((complete / total) * 100).round() : 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 18, color: color), const SizedBox(width: 6), Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))]),
          const SizedBox(height: 12),
          Text('$complete/$total', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text('$percent% complete', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: percent / 100, backgroundColor: Colors.grey[200], color: color),
        ],
      ),
    );
  }

  Widget _buildCaStatusCard({required int open, required int overdue, required int critical}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.build_circle_outlined, size: 18, color: Color(0xFFEF4444)), SizedBox(width: 6), Text('Corrective Actions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))]),
          const SizedBox(height: 12),
          _buildStatRow('Open', open.toString(), Colors.blue),
          _buildStatRow('Overdue', overdue.toString(), Colors.red),
          _buildStatRow('Critical', critical.toString(), const Color(0xFFDC2626)),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }

  Widget _buildOverdueAlertCard(OverdueReport? report) {
    final hasOverdue = report != null && report.totalOverdueItems > 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasOverdue ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hasOverdue ? const Color(0xFBFECACA) : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(hasOverdue ? Icons.warning_amber : Icons.check_circle, size: 18, color: hasOverdue ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
            const SizedBox(width: 6),
            Text('Overdue Items', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 8),
          Text(
            hasOverdue ? '${report!.totalOverdueItems} items need attention' : 'No overdue items ✅',
            style: TextStyle(fontSize: 12, color: hasOverdue ? const Color(0xFFDC2626) : const Color(0xFF059669)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsGrid(ExecutionDashboardSnapshot snapshot) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: [
        _buildQuickStat('In Progress Obj.', snapshot.objectivesInProgress.toString(), Colors.blue),
        _buildQuickStat('Overdue Obj.', snapshot.objectivesOverdue.toString(), Colors.orange),
        _buildQuickStat('Audits w/ Findings', snapshot.auditsWithFindings.toString(), Colors.purple),
        _buildQuickStat('Overdue Audits', snapshot.auditsOverdue.toString(), Colors.red),
        _buildQuickStat('Hold Point Insp.', _trackingData?.inspections.where((i) => i.isHoldPoint).length.toString() ?? '0', Colors.amber),
        _buildQuickStat('Verified CAs', (_trackingData?.correctiveActions.where((c) => c.verified).length ?? 0).toString(), Colors.green),
      ],
    );
  }

  Widget _buildQuickStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
        ],
      ),
    );
  }

  // ============================================================================
  // OBJECTIVES TAB
  // ============================================================================

  Widget _buildObjectivesTab() {
    final objectives = _trackingData?.objectives ?? [];
    
    if (objectives.isEmpty) {
      return _buildEmptyState('No objectives to track', 'Objectives will appear here after seeding from Planning Phase.');
    }

    return ListView.builder(
      itemCount: objectives.length,
      itemBuilder: (context, index) => _buildObjectiveCard(objectives[index]),
    );
  }

  Widget _buildObjectiveCard(ExecutionObjective objective) {
    final isOverdue = objective.isOverdue;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isOverdue ? const Color(0xFFFCA5A5) : Colors.grey[300]!)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(objective.status.icon, size: 20, color: objective.status.color),
                const SizedBox(width: 8),
                Expanded(child: Text(objective.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                _buildStatusChip(objective.status),
                if (isOverdue) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                    child: const Text('⚠️ Overdue', style: TextStyle(fontSize: 11, color: Color(0xFFD97706))),
                  ),
                ],
              ],
            ),
            if (objective.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(objective.description, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            ],
            const SizedBox(height: 12),
            
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: objective.progressPercent / 100,
                backgroundColor: Colors.grey[200],
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${objective.progressPercent.round()}% complete', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text('Due: ${DateFormat.yMMMd().format(objective.plannedDate)}', style: TextStyle(fontSize: 12, color: isOverdue ? const Color(0xFFDC2626) : Colors.grey[600])),
              ],
            ),
            
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _advanceObjectiveStatus(objective),
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: const Text('Advance'),
                ),
                const Spacer(),
                if (objective.evidenceUrls.isNotEmpty)
                  Chip(label: Text('${objective.evidenceUrls.length} evidence', style: const TextStyle(fontSize: 11))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _advanceObjectiveStatus(ExecutionObjective objective) {
    final newStatus = _service.advanceStatus(objective.status);
    
    if (!_service.isValidTransition(objective.status, newStatus)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot advance from this status')));
      return;
    }

    setState(() {
      final index = _trackingData!.objectives.indexOf(objective);
      _trackingData!.objectives[index] = objective.copyWith(status: newStatus, progressPercent: newStatus == ExecutionQualityStatus.complete ? 100 : (newStatus == ExecutionQualityStatus.inProgress ? 50 : objective.progressPercent));
    });
  }

  // ============================================================================
  // INSPECTIONS TAB
  // ============================================================================

  Widget _buildInspectionsTab() {
    final inspections = _trackingData?.inspections ?? [];
    
    if (inspections.isEmpty) {
      return _buildEmptyState('No inspections scheduled', 'Inspections will appear here after seeding from Planning Phase.');
    }

    return ListView.builder(
      itemCount: inspections.length,
      itemBuilder: (context, index) => _buildInspectionCard(inspections[index]),
    );
  }

  Widget _buildInspectionCard(ExecutionInspection inspection) {
    final isOverdue = inspection.scheduledDate.isBefore(DateTime.now()) && inspection.status != ExecutionQualityStatus.complete;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: inspection.isHoldPoint ? const Color(0xFFFCA5A5) : (isOverdue ? const Color(0xFFFECACA) : Colors.grey[300]!)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: inspection.type == 'QA' ? const Color(0xFFDBEAFE) : const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(inspection.type, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: inspection.type == 'QA' ? const Color(0xFF2563EB) : const Color(0xFF059669))),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(inspection.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                if (inspection.isHoldPoint)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(4)),
                    child: const Text('🛑 Hold Point', style: TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
                  ),
              ],
            ),
            if (inspection.scope.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Scope: ${inspection.scope}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(inspection.inspector.isNotEmpty ? inspection.inspector : 'Unassigned', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                const Spacer(),
                Icon(Icons.calendar_today, size: 16, color: isOverdue ? Colors.red : Colors.grey[600]),
                const SizedBox(width: 4),
                Text(DateFormat.yMMMd().format(inspection.scheduledDate), style: TextStyle(fontSize: 12, color: isOverdue ? Colors.red : Colors.grey[700])),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatusChip(inspection.status),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => _updateInspectionStatus(inspection),
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Update'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateInspectionStatus(ExecutionInspection inspection) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Inspection Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(inspection.title, style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            ...ExecutionQualityStatus.values.map((status) => 
              ListTile(
                leading: Icon(status.icon, color: status.color),
                title: Text(status.label),
                trailing: inspection.status == status ? const Icon(Icons.check_circle, color: Color(0xFF10B981)) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _applyInspectionStatusUpdate(inspection, status);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _applyInspectionStatusUpdate(ExecutionInspection inspection, ExecutionQualityStatus newStatus) {
    setState(() {
      final index = _trackingData!.inspections.indexOf(inspection);
      _trackingData!.inspections[index] = inspection.copyWith(
        status: newStatus,
        completedDate: newStatus == ExecutionQualityStatus.complete ? DateTime.now() : inspection.completedDate,
      );
    });
  }

  // ============================================================================
  // AUDITS TAB
  // ============================================================================

  Widget _buildAuditsTab() {
    final audits = _trackingData?.audits ?? [];
    
    if (audits.isEmpty) {
      return _buildEmptyState('No audits planned', 'Audits will appear here after seeding from Planning Phase.');
    }

    return ListView.builder(
      itemCount: audits.length,
      itemBuilder: (context, index) => _buildAuditCard(audits[index]),
    );
  }

  Widget _buildAuditCard(ExecutionAudit audit) {
    final isOverdue = audit.isOverdue;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isOverdue ? const Color(0xFFFECACA) : Colors.grey[300]!)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _getAuditTypeColor(audit.auditType).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(audit.auditType, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _getAuditTypeColor(audit.auditType))),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(audit.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                _buildAuditResultChip(audit.resultStatus),
              ],
            ),
            if (audit.scope.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Scope: ${audit.scope}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('Auditor: ${audit.auditor}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                const Spacer(),
                Icon(Icons.calendar_today, size: 16, color: isOverdue ? Colors.red : Colors.grey[600]),
                const SizedBox(width: 4),
                Text(DateFormat.yMMMd().format(audit.plannedDate), style: TextStyle(fontSize: 12, color: isOverdue ? Colors.red : Colors.grey[700])),
              ],
            ),
            if (audit.findings.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(6)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Findings:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                    ...audit.findings.take(3).map((f) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${f.reference}: ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                          Expanded(child: Text(f.description, style: const TextStyle(fontSize: 11))),
                        ],
                      ),
                    )),
                    if (audit.findings.length > 3)
                      Text('+${audit.findings.length - 3} more findings...', style: const TextStyle(fontSize: 11, color: Color(0xFFD97706))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatusChip(audit.status),
                if (!audit.addedToCalendar) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _addAuditToCalendar(audit),
                    icon: const Icon(Icons.calendar_today, size: 14),
                    label: const Text('Add to Calendar'),
                  ),
                ] else ...[
                  const SizedBox(width: 8),
                              Chip(avatar: const Icon(Icons.check, size: 12),
                  label: const Text('In Calendar', style: TextStyle(fontSize: 11))),
                ],
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => _updateAuditStatus(audit),
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Update'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getAuditTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'external': return const Color(0xFF8B5CF6);
      case 'regulatory': return const Color(0xFFEF4444);
      default: return const Color(0xFF3B82F6);
    }
  }

  void _addAuditToCalendar(ExecutionAudit audit) async {
    final event = CalendarEvent(
      sourceType: 'audit',
      sourceId: audit.id,
      title: '📋 ${audit.title}',
      description: '${audit.auditType} Audit - ${audit.scope}',
      eventDate: audit.plannedDate,
      attendees: [audit.auditor, audit.auditee].where((e) => e.isNotEmpty).toList(),
      reminderMinutesBefore: audit.reminderDaysBefore * 24 * 60,
    );

    try {
      final provider = ProjectDataInherited.maybeOf(context);
      final projectId = provider?.projectData.projectId;
      if (projectId == null || projectId.isEmpty) throw Exception('No project ID');

      await _service.syncToTeamCalendar(projectId: projectId, event: event, postedBy: 'System');
      
      setState(() {
        final index = _trackingData!.audits.indexOf(audit);
        _trackingData!.audits[index] = audit.copyWith(addedToCalendar: true);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ "${audit.title}" added to Team Calendar'), backgroundColor: const Color(0xFF059669)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add to calendar: $e'), backgroundColor: const Color(0xFFDC2626)));
      }
    }
  }

  void _updateAuditStatus(ExecutionAudit audit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Audit Status & Result'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(audit.title, style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),
              const Text('Status:', style: TextStyle(fontWeight: FontWeight.w600)),
              ...ExecutionQualityStatus.values.map((status) => 
                ListTile(
                  dense: true,
                  leading: Icon(status.icon, color: status.color),
                  title: Text(status.label),
                  trailing: audit.status == status ? const Icon(Icons.check_circle, color: Color(0xFF10B981)) : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    _applyAuditStatusUpdate(audit: audit, status: status);
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text('Result:', style: TextStyle(fontWeight: FontWeight.w600)),
              ...AuditResultStatus.values.map((result) => 
                ListTile(
                  dense: true,
                  title: Text(result.label),
                  trailing: audit.resultStatus == result ? const Icon(Icons.check_circle, color: Color(0xFF10B981)) : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    _applyAuditStatusUpdate(audit: audit, resultStatus: result);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applyAuditStatusUpdate({required ExecutionAudit audit, ExecutionQualityStatus? status, AuditResultStatus? resultStatus}) {
    setState(() {
      final index = _trackingData!.audits.indexOf(audit);
      _trackingData!.audits[index] = audit.copyWith(
        status: status ?? audit.status,
        resultStatus: resultStatus ?? audit.resultStatus,
        actualDate: status == ExecutionQualityStatus.complete ? DateTime.now() : audit.actualDate,
      );
    });
  }

  // ============================================================================
  // CORRECTIVE ACTIONS TAB
  // ============================================================================

  Widget _buildCorrectiveActionsTab() {
    final cas = _trackingData?.correctiveActions ?? [];
    
    if (cas.isEmpty) {
      return _buildEmptyState('No corrective actions', 'Corrective actions will appear when findings or nonconformances are identified.');
    }

    // Sort by priority (critical first) then by due date
    final sortedCas = List<ExecutionCorrectiveAction>.from(cas)
      ..sort((a, b) {
        final priorityOrder = [CaPriority.critical, CaPriority.high, CaPriority.medium, CaPriority.low];
        final aIdx = priorityOrder.indexOf(a.priority);
        final bIdx = priorityOrder.indexOf(b.priority);
        if (aIdx != bIdx) return aIdx.compareTo(bIdx);
        return a.dueDate.compareTo(b.dueDate);
      });

    return ListView.builder(
      itemCount: sortedCas.length,
      itemBuilder: (context, index) => _buildCaCard(sortedCas[index]),
    );
  }

  Widget _buildCaCard(ExecutionCorrectiveAction ca) {
    final isOverdue = ca.isOverdue;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: ca.priority.color.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ca.priority.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(ca.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                _buildPriorityChip(ca.priority),
                if (isOverdue) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(4)),
                    child: const Text('⚠️ Overdue', style: TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
                  ),
                ],
              ],
            ),
            if (ca.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(ca.description, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            ],
            if (ca.rootCause.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Root Cause: ${ca.rootCause}', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(ca.assignedTo.isNotEmpty ? ca.assignedTo : 'Unassigned', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                const Spacer(),
                Icon(Icons.calendar_today, size: 16, color: isOverdue ? Colors.red : Colors.grey[600]),
                const SizedBox(width: 4),
                Text('Due: ${DateFormat.yMMMd().format(ca.dueDate)}', style: TextStyle(fontSize: 12, color: isOverdue ? Colors.red : Colors.grey[700])),
                if (!isOverdue) ...[
                  const SizedBox(width: 8),
                  Text('${ca.daysUntilDue}d left', style: TextStyle(fontSize: 11, color: ca.daysUntilDue <= 3 ? const Color(0xFFF59E0B) : Colors.grey[600])),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatusChip(ca.status),
                const Spacer(),
                if (!ca.verified && ca.status == ExecutionQualityStatus.complete)
                  OutlinedButton.icon(
                    onPressed: () => _verifyCa(ca),
                    icon: const Icon(Icons.verified_user, size: 14),
                    label: const Text('Verify'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => _updateCaStatus(ca),
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('Update'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _verifyCa(ExecutionCorrectiveAction ca) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify Corrective Action'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ca.title, style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(labelText: 'Verification Notes'),
              onChanged: (val) {},
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _applyCaUpdate(ca, verified: true, status: ExecutionQualityStatus.verified);
            },
            child: const Text('Confirm Verification'),
          ),
        ],
      ),
    );
  }

  void _updateCaStatus(ExecutionCorrectiveAction ca) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Corrective Action'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ca.title, style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            ...ExecutionQualityStatus.values.where((s) => s != ExecutionQualityStatus.planned).map((status) => 
              ListTile(
                dense: true,
                leading: Icon(status.icon, color: status.color),
                title: Text(status.label),
                trailing: ca.status == status ? const Icon(Icons.check_circle, color: Color(0xFF10B981)) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _applyCaUpdate(ca, status: status);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _applyCaUpdate(ExecutionCorrectiveAction ca, {ExecutionQualityStatus? status, bool? verified}) {
    setState(() {
      final index = _trackingData!.correctiveActions.indexOf(ca);
      _trackingData!.correctiveActions[index] = ca.copyWith(
        status: status ?? ca.status,
        verified: verified ?? ca.verified,
        verifiedDate: verified == true ? DateTime.now() : ca.verifiedDate,
        completedDate: status == ExecutionQualityStatus.complete || status == ExecutionQualityStatus.verified ? DateTime.now() : ca.completedDate,
      );
    });
  }

  // ============================================================================
  // COQ TAB
  // ============================================================================

  Widget _buildCoqTab() {
    final coq = _trackingData?.coqTracking ?? ExecutionCoqTracking.empty();
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // COQ Summary Cards
          Row(
            children: [
              Expanded(child: _buildCoqCategoryCard('Prevention', coq.preventionCostActual, const Color(0xFF10B981))),
              const SizedBox(width: 12),
              Expanded(child: _buildCoqCategoryCard('Appraisal', coq.appraisalCostActual, const Color(0xFF3B82F6))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildCoqCategoryCard('Internal Failure', coq.internalFailureCostActual, const Color(0xFFEF4444))),
              const SizedBox(width: 12),
              Expanded(child: _buildCoqCategoryCard('External Failure', coq.externalFailureCostActual, const Color(0xFFDC2626))),
            ],
          ),
          const SizedBox(height: 16),
          
          // Total COQ
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Total Cost of Quality', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                  SizedBox(height: 4),
                  Text('Prevention + Appraisal + Failures', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                ]),
                Text('\$${coq.totalCoqActual.toStringAsFixed(2)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // COQ Entries List
          if (coq.entries.isNotEmpty) ...[
            const Text('Cost Entries', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...coq.entries.map((entry) => _buildCoqEntryCard(entry)),
          ] else
            _buildEmptyState('No cost entries recorded', 'Track prevention, appraisal, and failure costs here.'),
        ],
      ),
    );
  }

  Widget _buildCoqCategoryCard(String category, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(category, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
          const SizedBox(height: 8),
          Text('\$${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildCoqEntryCard(CoqEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: _getCoqCategoryColor(entry.category).withOpacity(0.15),
          child: Text(entry.category[0], style: TextStyle(color: _getCoqCategoryColor(entry.category), fontWeight: FontWeight.bold)),
        ),
        title: Text(entry.description, style: const TextStyle(fontSize: 14)),
        subtitle: Text('${entry.performer} • ${DateFormat.yMMMd().format(entry.date)}'),
        trailing: Text('\$${entry.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Color _getCoqCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'prevention': return const Color(0xFF10B981);
      case 'appraisal': return const Color(0xFF3B82F6);
      case 'internal failure': return const Color(0xFFEF4444);
      case 'external failure': return const Color(0xFFDC2626);
      default: return Colors.grey;
    }
  }

  // ============================================================================
  // SHARED WIDGETS
  // ============================================================================

  Widget _buildStatusChip(ExecutionQualityStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 14, color: status.color),
          const SizedBox(width: 4),
          Text(status.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: status.color)),
        ],
      ),
    );
  }

  Widget _buildAuditResultChip(AuditResultStatus result) {
    Color color;
    switch (result) {
      case AuditResultStatus.passed: color = const Color(0xFF10B981); break;
      case AuditResultStatus.passedWithObservations: color = const Color(0xFF3B82F6); break;
      case AuditResultStatus.failed: color = const Color(0xFFEF4444); break;
      case AuditResultStatus.deferred: color = const Color(0xFFF59E0B); break;
      default: color = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(result.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
    );
  }

  Widget _buildPriorityChip(CaPriority priority) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: priority.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(priority.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: priority.color)),
    );
  }

  Widget _buildEmptyState(String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            const SizedBox(height: 24),
            if (!_seeding)
              ElevatedButton.icon(
                onPressed: _seeding ? null : _loadData,
                icon: const Icon(Icons.download),
                label: const Text('Seed from Planning'),
              )
            else
              const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
