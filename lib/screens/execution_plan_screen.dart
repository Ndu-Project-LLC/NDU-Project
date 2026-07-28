import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/execution_plan_shared.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/project_navigation_service.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

class ExecutionPlanScreen extends StatefulWidget {
 const ExecutionPlanScreen({super.key});

 @override
 State<ExecutionPlanScreen> createState() => _ExecutionPlanScreenState();
}

class _ExecutionPlanScreenState extends State<ExecutionPlanScreen> {
 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) async {
 final provider = ProjectDataInherited.maybeOf(context);
 final pid = provider?.projectData.projectId;
 if (pid != null && pid.isNotEmpty) {
 await ProjectNavigationService.instance
 .saveLastPage(pid, 'execution_plan');
 }
 });
 }

 
 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Execution Plan',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['execution_plan_screen'] ?? 'No data recorded.'),
 ],
 );
 }
@override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 20 : 40;

 return ResponsiveScaffold(
 activeItemLabel: 'Execution Plan Overview',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 32),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 ExecutionPlanHeader(
 onBack: () => PlanningPhaseNavigation.goToPrevious(
 context, 'execution_plan'),
 onNext: () => PlanningPhaseNavigation.goToNext(
 context, 'execution_plan'), onExportPdf: _exportPdf),
  const SizedBox(height: 24),
 ExecutionPlanForm(
 hintText:
 'Describe the sequential, and overall, thought process for executing the project',
 noteKey: 'execution_plan_outline',
 ),
 const SizedBox(height: 48),
 Align(
 alignment: Alignment.centerRight,
 child: Wrap(
 spacing: 16,
 runSpacing: 12,
 crossAxisAlignment: WrapCrossAlignment.center,
 alignment: WrapAlignment.end,
 children: [
 const InfoBadge(),
 const AiTipCard(),
 YellowActionButton(
 label: 'Next',
 onPressed: () => PlanningPhaseNavigation.goToNext(
 context, 'execution_plan'),
 ),
 ],
 ),
 ),
 const SizedBox(height: 56),
 ],
 ),
 ),
 );
 }
}
