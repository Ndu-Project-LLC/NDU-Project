import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/planning_ai_notes_card.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
class LessonsLearnedScreen extends StatefulWidget {
 const LessonsLearnedScreen({super.key});

 static Future<void> open(BuildContext context) {
 return Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const LessonsLearnedScreen()),
 );
 }

 @override
 State<LessonsLearnedScreen> createState() => _LessonsLearnedScreenState();
}

class _LessonsLearnedScreenState extends State<LessonsLearnedScreen> {
 final TextEditingController _searchController = TextEditingController();
 @override
 void initState() {
 super.initState();
 _searchController.addListener(_handleSearchChanged);
 }

 @override
 void dispose() {
 _searchController.removeListener(_handleSearchChanged);
 _searchController.dispose();
 super.dispose();
 }

 void _handleSearchChanged() {
 setState(() {});
 }

 Future<void> _openLessonDialog([_LessonEntry? existing]) async {
 final result = await showDialog<_LessonEntry>(
 context: context,
 barrierDismissible: false,
 builder: (dialogContext) => _LessonDialog(existing: existing),
 );

 if (result == null || !mounted) return;

 try {
 final isEdit = existing != null;
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'lessons_learned',
 showSnackbar: false,
 dataUpdater: (current) {
 final lessons = List<LessonRecord>.from(current.lessonsLearned);
 if (isEdit) {
 final idx = lessons.indexWhere((l) => l.id == existing.id);
 if (idx != -1) {
 lessons[idx] = LessonRecord(
 id: existing.id,
 lesson: result.lesson,
 category: result.category,
 type: result.type,
 phase: result.phase,
 status: result.status,
 submittedBy: result.submittedBy,
 notes: '',
 impact: result.impact,
 highlight: result.highlight,
 dateSubmitted: _parseDate(result.date),
 );
 }
 } else {
 lessons.insert(
 0,
 LessonRecord(
 lesson: result.lesson,
 category: result.category,
 type: result.type,
 phase: result.phase,
 status: result.status,
 submittedBy: result.submittedBy,
 notes: '',
 impact: result.impact,
 highlight: result.highlight,
 dateSubmitted: _parseDate(result.date),
 ),
 );
 }
 return current.copyWith(lessonsLearned: lessons);
 },
 );

 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(SnackBar(
 content: Text(isEdit
 ? 'Lesson updated successfully.'
 : 'Lesson added to Lessons Learned.')));
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
 }
 }

 Future<void> _confirmDelete(String id) async {
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (ctx) => AlertDialog(
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
 title: const Text('Delete Lesson'),
 content: const Text(
 'Are you sure you want to delete this lesson? This action cannot be undone.'),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(ctx).pop(true),
 style: ElevatedButton.styleFrom(
 backgroundColor: Colors.redAccent,
 foregroundColor: Colors.white,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8)),
 ),
 child: const Text('Delete'),
 ),
 ],
 ),
 );

 if (confirmed != true || !mounted) return;

 try {
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'lessons_learned',
 showSnackbar: false,
 dataUpdater: (current) => current.copyWith(
 lessonsLearned:
 current.lessonsLearned.where((l) => l.id != id).toList(),
 ),
 );
 if (!mounted) return;
 ScaffoldMessenger.of(context)
 .showSnackBar(const SnackBar(content: Text('Lesson deleted.')));
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
 }
 }

 DateTime? _parseDate(String dateStr) {
 try {
 final parts = dateStr.split('-');
 if (parts.length == 3) {
 return DateTime(
 int.parse(parts[0]),
 int.parse(parts[1]),
 int.parse(parts[2]),
 );
 }
 } catch (e) { debugPrint('Error: $e'); }
 return null;
 }

 List<_LessonEntry> get _filteredEntries {
 final query = _searchController.text.trim().toLowerCase();

 final data = ProjectDataHelper.getDataListening(context);
 final lessons = data.lessonsLearned;

 final mapped = lessons
 .map((l) => _LessonEntry(
 id: l.id,
 lesson: l.lesson,
 type: l.type,
 category: l.category,
 phase: l.phase,
 impact: l.impact,
 status: l.status,
 submittedBy: l.submittedBy,
 date: l.dateSubmitted != null
 ? '${l.dateSubmitted!.year.toString().padLeft(4, '0')}-${l.dateSubmitted!.month.toString().padLeft(2, '0')}-${l.dateSubmitted!.day.toString().padLeft(2, '0')}'
 : '',
 highlight: l.highlight,
 ))
 .toList();

 if (query.isEmpty) return mapped;

 return mapped
 .where((entry) =>
 entry.lesson.toLowerCase().contains(query) ||
 entry.type.toLowerCase().contains(query) ||
 entry.category.toLowerCase().contains(query) ||
 entry.phase.toLowerCase().contains(query) ||
 entry.status.toLowerCase().contains(query) ||
 entry.submittedBy.toLowerCase().contains(query))
 .toList();
 }

 int _countByType(List<LessonRecord> lessons, String type) {
 return lessons
 .where((l) => l.type.toLowerCase() == type.toLowerCase())
 .length;
 }

 @override
 Widget build(BuildContext context) {
 final sidebarWidth = AppBreakpoints.sidebarWidth(context);
 return Scaffold(
 backgroundColor: Colors.white,
 body: Stack(
 children: [
 SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: sidebarWidth,
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Lessons Learned'),
 ),
 Expanded(child: _buildMainContent(context)),
 ],
 ),
 ),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Lessons Learned',
 ),
 ),
 const KazAiChatBubble(),
 ],
 ),
 );
 }

 Widget _buildMainContent(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 return Column(
 children: [
 Expanded(
 child: SingleChildScrollView(
 padding: EdgeInsets.all(AppBreakpoints.pagePadding(context)),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(title: 'Lessons Learned', onExportPdf: _exportPdf),
 const SizedBox(height: 24),
 const PlanningAiNotesCard(
 title: 'Notes',
 sectionLabel: 'Lessons Learned',
 noteKey: 'planning_lessons_learned_notes',
 checkpoint: 'lessons_learned',
 description:
 'Summarize key lessons, adoption steps, and follow-up actions.',
 ),
 const SizedBox(height: 24),
 _buildSummaryCard(isMobile),
 const SizedBox(height: 24),
 _buildLessonsCard(isMobile),
 const SizedBox(height: 24),
 ],
 ),
 ),
 ),
 // ── Pinned footer navigation ──
 Container(
 padding: EdgeInsets.symmetric(
 horizontal: AppBreakpoints.pagePadding(context),
 vertical: 16,
 ),
 decoration: const BoxDecoration(
 color: Colors.white,
 border: Border(
 top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
 ),
 ),
 child: Padding(
 padding: const EdgeInsets.only(right: 72),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 ElevatedButton.icon(
 onPressed: () => PlanningPhaseNavigation.goToPrevious(
 context, 'lessons_learned'),
 icon: const Icon(Icons.arrow_back, size: 16),
 label: Text(PlanningPhaseNavigation.backLabel('lessons_learned')),
 style: ElevatedButton.styleFrom(
 backgroundColor: Colors.white,
 foregroundColor: const Color(0xFF374151),
 elevation: 0,
 side: const BorderSide(color: Color(0xFFD1D5DB)),
 padding: const EdgeInsets.symmetric(
 horizontal: 20, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8)),
 ),
 ),
 ElevatedButton.icon(
 onPressed: () => PlanningPhaseNavigation.goToNext(
 context, 'lessons_learned'),
 icon: const Icon(Icons.arrow_forward, size: 16),
 label: Text(PlanningPhaseNavigation.nextLabel('lessons_learned')),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFC044),
 foregroundColor: const Color(0xFF111827),
 elevation: 0,
 padding: const EdgeInsets.symmetric(
 horizontal: 20, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8)),
 ),
 ),
 ],
 ),
 ),
 ),
 ],
 );
 }


 Widget _buildSummaryCard(bool isMobile) {
 final data = ProjectDataHelper.getDataListening(context);
 final lessons = data.lessonsLearned;
 final successCount = _countByType(lessons, 'Success');
 final challengeCount = _countByType(lessons, 'Challenge');
 final insightCount = _countByType(lessons, 'Insight');

 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: Colors.grey.withOpacity(0.2)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.02),
 blurRadius: 12,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Lessons Learned',
 style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
 ),
 const SizedBox(height: 4),
 Text(
 'Capture and implement knowledge from project experiences',
 style: TextStyle(fontSize: 14, color: Colors.grey[600]),
 ),
 const SizedBox(height: 20),
 Divider(color: Colors.grey.withOpacity(0.2), thickness: 1),
 const SizedBox(height: 20),
 isMobile
 ? Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _summaryLeftColumn(),
 const SizedBox(height: 20),
 _summaryRightColumn(
 successCount, challengeCount, insightCount),
 ],
 )
 : Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(child: _summaryLeftColumn()),
 Container(
 width: 1,
 height: 220,
 margin: const EdgeInsets.symmetric(horizontal: 24),
 color: Colors.grey.withOpacity(0.2),
 ),
 Expanded(
 child: _summaryRightColumn(
 successCount, challengeCount, insightCount)),
 ],
 ),
 ],
 ),
 );
 }

 Widget _summaryLeftColumn() {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'What are Lessons Learned?',
 style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
 ),
 const SizedBox(height: 12),
 Text(
 'Lessons Learned is the knowledge gained from the process of conducting a project. They may be identified at any point during the project\'s life cycle and should capture both positive experiences to repeat and negative experiences to avoid.',
 style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5),
 ),
 const SizedBox(height: 20),
 _bulletRow(Icons.emoji_events_outlined, 'Successes',
 'Positive outcomes and practices to continue'),
 const SizedBox(height: 12),
 _bulletRow(Icons.report_problem_outlined, 'Challenges',
 'Issues encountered and how they were addressed'),
 const SizedBox(height: 12),
 _bulletRow(Icons.lightbulb_outline, 'Insights',
 'New knowledge or observations that can benefit future projects'),
 ],
 );
 }

 Widget _summaryRightColumn(int successes, int challenges, int insights) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Benefits of Lessons Learned',
 style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
 ),
 const SizedBox(height: 16),
 _benefitRow('Prevents repeating the same mistakes'),
 const SizedBox(height: 10),
 _benefitRow('Improves future project performance'),
 const SizedBox(height: 10),
 _benefitRow('Enhances organizational knowledge'),
 const SizedBox(height: 10),
 _benefitRow('Promotes continuous improvement culture'),
 const SizedBox(height: 10),
 _benefitRow('Reduces risk in similar future projects'),
 const SizedBox(height: 24),
 Row(
 children: [
 _SummaryStat(
 label: 'Successes',
 value: '$successes',
 color: const Color(0xFF36C275)),
 const SizedBox(width: 16),
 _SummaryStat(
 label: 'Challenges',
 value: '$challenges',
 color: const Color(0xFFFFB74D)),
 const SizedBox(width: 16),
 _SummaryStat(
 label: 'Insights',
 value: '$insights',
 color: const Color(0xFF5C6BC0)),
 ],
 ),
 ],
 );
 }

 Widget _bulletRow(IconData icon, String title, String description) {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: const Color(0xFFE8F5E9),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style:
 const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
 ),
 const SizedBox(height: 4),
 Text(
 description,
 style: TextStyle(
 fontSize: 14, color: Colors.grey[700], height: 1.4),
 ),
 ],
 ),
 ),
 ],
 );
 }

 Widget _benefitRow(String text) {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Icon(Icons.check_circle, color: Color(0xFF36C275), size: 20),
 const SizedBox(width: 10),
 Expanded(
 child: Text(
 text,
 style:
 TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.4),
 ),
 ),
 ],
 );
 }

 Widget _buildLessonsCard(bool isMobile) {
 final entries = _filteredEntries;
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: Colors.grey.withOpacity(0.2)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.02),
 blurRadius: 12,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Text(
 'Lessons Learned',
 style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
 ),
 const Spacer(),
 if (!isMobile)
 Row(
 children: [
 SizedBox(
 width: 260,
 child: VoiceTextField(
 controller: _searchController,
 decoration: InputDecoration(
 prefixIcon: const Icon(Icons.search),
 hintText: 'Search...',
 filled: true,
 fillColor: Colors.grey.withOpacity(0.1),
 contentPadding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 12),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: BorderSide.none,
 ),
 ),
 ),
 ),
 const SizedBox(width: 12),
 OutlinedButton.icon(
 onPressed: () {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Filter options coming soon.')),
 );
 },
 icon: const Icon(Icons.filter_alt_outlined, size: 18),
 label: const Text('Filter'),
 style: OutlinedButton.styleFrom(
 foregroundColor: Colors.grey[800],
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 const SizedBox(width: 12),
 ElevatedButton.icon(
 onPressed: () => _openLessonDialog(),
 icon: const Icon(Icons.add, size: 18),
 label: const Text('Add Lesson'),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: Colors.black,
 elevation: 0,
 padding: const EdgeInsets.symmetric(
 horizontal: 20, vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ],
 ),
 ],
 ),
 if (isMobile)
 Padding(
 padding: const EdgeInsets.only(top: 16),
 child: Column(
 children: [
 VoiceTextField(
 controller: _searchController,
 decoration: InputDecoration(
 prefixIcon: const Icon(Icons.search),
 hintText: 'Search...',
 filled: true,
 fillColor: Colors.grey.withOpacity(0.1),
 contentPadding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 12),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: BorderSide.none,
 ),
 ),
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: OutlinedButton.icon(
 onPressed: () {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Filter options coming soon.')),
 );
 },
 icon: const Icon(Icons.filter_alt_outlined, size: 18),
 label: const Text('Filter'),
 style: OutlinedButton.styleFrom(
 foregroundColor: Colors.grey[800],
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: ElevatedButton.icon(
 onPressed: () => _openLessonDialog(),
 icon: const Icon(Icons.add, size: 18),
 label: const Text('Add Lesson'),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: Colors.black,
 elevation: 0,
 padding: const EdgeInsets.symmetric(
 horizontal: 20, vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 const SizedBox(height: 24),
 if (entries.isEmpty)
 Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(vertical: 48),
 decoration: BoxDecoration(
 color: Colors.grey.withOpacity(0.08),
 borderRadius: BorderRadius.circular(16),
 ),
 child: Column(
 children: [
 Icon(Icons.search_off, color: Colors.grey[500], size: 36),
 const SizedBox(height: 12),
 Text(
 'No lessons match your search yet.',
 style: TextStyle(fontSize: 14, color: Colors.grey[600]),
 ),
 ],
 ),
 )
 else
 _buildTasksTable(entries),
 ],
 ),
 );
 }

 Widget _buildTasksTable(List<_LessonEntry> entries) {
 const headerStyle = TextStyle(
 fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87);
 const cellStyle = TextStyle(fontSize: 13, color: Colors.black87);
 const subStyle = TextStyle(fontSize: 12, color: Colors.black54);

 return LayoutBuilder(
 builder: (context, constraints) {
 final availableWidth = constraints.hasBoundedWidth
 ? constraints.maxWidth
 : MediaQuery.of(context).size.width;
 final tableWidth = math.max(960.0, availableWidth);

 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: ConstrainedBox(
 constraints:
 BoxConstraints(minWidth: tableWidth, maxWidth: tableWidth),
 child: Column(
 children: [
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: BoxDecoration(
 color: Colors.grey.withOpacity(0.12),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Row(
 children: const [
 Expanded(flex: 6, child: Text('#', style: headerStyle)),
 Expanded(
 flex: 32, child: Text('Lesson', style: headerStyle)),
 Expanded(
 flex: 14, child: Text('Type', style: headerStyle)),
 Expanded(
 flex: 14,
 child: Text('Category', style: headerStyle)),
 Expanded(
 flex: 14, child: Text('Phase', style: headerStyle)),
 Expanded(
 flex: 12, child: Text('Impact', style: headerStyle)),
 Expanded(
 flex: 14, child: Text('Status', style: headerStyle)),
 Expanded(
 flex: 20,
 child: Text('Submitted By', style: headerStyle)),
 Expanded(
 flex: 14, child: Text('Date', style: headerStyle)),
 Expanded(
 flex: 10,
 child: Text('Actions',
 style: headerStyle, textAlign: TextAlign.center)),
 ],
 ),
 ),
 const SizedBox(height: 8),
 Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border:
 Border.all(color: Colors.grey.withOpacity(0.12)),
 ),
 child: Column(
 children: [
 for (int i = 0; i < entries.length; i++)
 Container(
 decoration: BoxDecoration(
 color: entries[i].highlight
 ? Colors.white
 : Colors.grey
 .withOpacity(0.05 * ((i % 2) + 1)),
 borderRadius: i == 0
 ? const BorderRadius.vertical(
 top: Radius.circular(16))
 : i == entries.length - 1
 ? const BorderRadius.vertical(
 bottom: Radius.circular(16))
 : BorderRadius.zero,
 ),
 padding: const EdgeInsets.symmetric(
 horizontal: 20, vertical: 18),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 flex: 6,
 child: Text('${i + 1}', style: cellStyle)),
 Expanded(
 flex: 32,
 child: Text(
 entries[i].lesson,
 style: cellStyle.copyWith(
 fontWeight: FontWeight.w600),
 ),
 ),
 Expanded(
 flex: 14,
 child: _statusPill(entries[i].type)),
 Expanded(
 flex: 14,
 child: Text(entries[i].category,
 style: cellStyle)),
 Expanded(
 flex: 14,
 child:
 Text(entries[i].phase, style: cellStyle)),
 Expanded(
 flex: 12,
 child: Text(
 entries[i].impact,
 style: entries[i].impact == 'High'
 ? cellStyle.copyWith(
 color: Colors.redAccent)
 : cellStyle,
 ),
 ),
 Expanded(
 flex: 14,
 child: Text(entries[i].status,
 style: cellStyle)),
 Expanded(
 flex: 20,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(entries[i].submittedBy,
 style: cellStyle),
 ],
 ),
 ),
 Expanded(
 flex: 14,
 child:
 Text(entries[i].date, style: cellStyle)),
 Expanded(
 flex: 10,
 child: Align(
 alignment: Alignment.centerRight,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 onPressed: () =>
 _openLessonDialog(entries[i]),
 icon: const Icon(Icons.edit_outlined,
 size: 18, color: Colors.grey),
 tooltip: 'Edit lesson',
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(
 minWidth: 32, minHeight: 32),
 ),
 IconButton(
 onPressed: () =>
 _confirmDelete(entries[i].id),
 icon: const Icon(Icons.delete_outline,
 size: 18, color: Colors.redAccent),
 tooltip: 'Delete lesson',
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(
 minWidth: 32, minHeight: 32),
 ),
 IconButton(
   onPressed: () {
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('KAZ AI: Generating suggestions...'), duration: Duration(seconds: 2)),
     );
   },
   icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFF59E0B)),
   tooltip: 'KAZ AI',
   padding: EdgeInsets.zero,
   constraints: const BoxConstraints(minWidth: 28),
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
 ],
 ),
 ),
 );
 },
 );
 }

 Widget _statusPill(String value) {
 Color background;
 Color foreground;
 switch (value.toLowerCase()) {
 case 'success':
 background = const Color(0xFFE8F5E9);
 foreground = const Color(0xFF2E7D32);
 break;
 case 'challenge':
 background = const Color(0xFFFFF3E0);
 foreground = const Color(0xFFF57C00);
 break;
 default:
 background = const Color(0xFFE8EAF6);
 foreground = const Color(0xFF3949AB);
 }

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: background,
 borderRadius: BorderRadius.circular(999),
 ),
 alignment: Alignment.centerLeft,
 child: Text(
 value,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: foreground,
 ),
 ),
 );
 }

 Widget _circularIconButton(IconData icon, {VoidCallback? onTap}) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(24),
 child: Container(
 width: 44,
 height: 44,
 decoration: BoxDecoration(
 color: icon == Icons.arrow_forward_ios
 ? const Color(0xFFFFD700)
 : Colors.white,
 borderRadius: BorderRadius.circular(22),
 border: Border.all(color: Colors.grey.withOpacity(0.2)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.05),
 blurRadius: 6,
 offset: const Offset(0, 2)),
 ],
 ),
 child: Icon(
 icon,
 size: 18,
 color:
 icon == Icons.arrow_forward_ios ? Colors.black : Colors.grey[800],
 ),
 ),
 );
 }

 Widget _profileChip() {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(30),
 border: Border.all(color: Colors.grey.withOpacity(0.2)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.05),
 blurRadius: 6,
 offset: const Offset(0, 2)),
 ],
 ),
 child: StreamBuilder<bool>(
 stream: UserService.watchAdminStatus(),
 builder: (context, snapshot) {
 final user = FirebaseAuth.instance.currentUser;
 final displayName =
 FirebaseAuthService.displayNameOrEmail(fallback: 'User');
 final email = user?.email ?? '';
 final name = displayName.isNotEmpty
 ? displayName
 : (email.isNotEmpty ? email : 'User');
 final photoUrl = user?.photoURL ?? '';
 final isAdmin = snapshot.data ?? UserService.isAdminEmail(email);
 final role = isAdmin ? 'Admin' : 'Member';

 return Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CircleAvatar(
 radius: 18,
 backgroundColor: Colors.grey.withOpacity(0.2),
 backgroundImage:
 photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
 child: photoUrl.isEmpty
 ? Text(
 name.isNotEmpty ? name[0].toUpperCase() : 'U',
 style: TextStyle(
 color: Colors.grey[800],
 fontWeight: FontWeight.w600,
 ),
 )
 : null,
 ),
 const SizedBox(width: 10),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 name,
 style: const TextStyle(
 fontSize: 14, fontWeight: FontWeight.w600),
 ),
 Text(
 role,
 style: TextStyle(fontSize: 12, color: Colors.grey[600]),
 ),
 ],
 ),
 const SizedBox(width: 6),
 Icon(Icons.keyboard_arrow_down,
 color: Colors.grey[700], size: 18),
 ],
 );
 },
 ),
 );
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Lessons Learned',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_lessons_learned_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

class _LessonDialog extends StatefulWidget {
 final _LessonEntry? existing;

 const _LessonDialog({this.existing});

 @override
 State<_LessonDialog> createState() => _LessonDialogState();
}

class _LessonDialogState extends State<_LessonDialog> {
 final _formKey = GlobalKey<FormState>();
 final TextEditingController _lessonController = TextEditingController();
 final TextEditingController _categoryController = TextEditingController();
 final TextEditingController _phaseController = TextEditingController();
 final TextEditingController _statusController = TextEditingController();
 final TextEditingController _submittedByController = TextEditingController();
 final TextEditingController _dateController = TextEditingController();

 String _selectedType = 'Success';
 String _selectedImpact = 'Medium';
 bool _highlightRow = false;
 DateTime? _selectedDate;

 bool get _isEdit => widget.existing != null;

 @override
 void initState() {
 super.initState();
 if (widget.existing != null) {
 final e = widget.existing!;
 _lessonController.text = e.lesson;
 _categoryController.text = e.category;
 _phaseController.text = e.phase;
 _statusController.text = e.status;
 _submittedByController.text = e.submittedBy;
 _dateController.text = e.date;
 _selectedType = e.type;
 _selectedImpact = e.impact;
 _highlightRow = e.highlight;
 if (e.date.isNotEmpty) {
 try {
 final parts = e.date.split('-');
 _selectedDate = DateTime(
 int.parse(parts[0]),
 int.parse(parts[1]),
 int.parse(parts[2]),
 );
 } catch (e) { debugPrint('Error: $e'); }
 }
 }
 }

 @override
 void dispose() {
 _lessonController.dispose();
 _categoryController.dispose();
 _phaseController.dispose();
 _statusController.dispose();
 _submittedByController.dispose();
 _dateController.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 return Dialog(
 insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 560),
 child: Padding(
 padding: const EdgeInsets.all(24),
 child: Form(
 key: _formKey,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Text(
 _isEdit ? 'Edit Lesson' : 'Add Lesson',
 style: const TextStyle(
 fontSize: 20, fontWeight: FontWeight.w700),
 ),
 ),
 IconButton(
 onPressed: () => Navigator.of(context).pop(),
 icon: const Icon(Icons.close),
 tooltip: 'Close',
 ),
 ],
 ),
 const SizedBox(height: 8),
 Text(
 _isEdit
 ? 'Update the lesson details below.'
 : 'Fill in the lesson details below.',
 style: TextStyle(fontSize: 13, color: Colors.grey[600]),
 ),
 const SizedBox(height: 24),
 VoiceTextFormField(
 controller: _lessonController,
 decoration: _inputDecoration('Lesson'),
 textInputAction: TextInputAction.newline,
 maxLines: 4,
 minLines: 3,
 validator: (value) =>
 (value == null || value.trim().isEmpty)
 ? 'Please describe the lesson.'
 : null,
 ),
 const SizedBox(height: 16),
 Row(
 children: [
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue: _selectedType,
 decoration: _inputDecoration('Type'),
 items: const [
 DropdownMenuItem(
 value: 'Success', child: Text('Success')),
 DropdownMenuItem(
 value: 'Challenge', child: Text('Challenge')),
 DropdownMenuItem(
 value: 'Insight', child: Text('Insight')),
 ],
 onChanged: (value) {
 if (value != null) {
 setState(() => _selectedType = value);
 }
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 initialValue: _selectedImpact,
 decoration: _inputDecoration('Impact'),
 items: const [
 DropdownMenuItem(
 value: 'High', child: Text('High')),
 DropdownMenuItem(
 value: 'Medium', child: Text('Medium')),
 DropdownMenuItem(value: 'Low', child: Text('Low')),
 ],
 onChanged: (value) {
 if (value != null) {
 setState(() => _selectedImpact = value);
 }
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 Row(
 children: [
 Expanded(
 child: VoiceTextFormField(
 controller: _categoryController,
 decoration: _inputDecoration('Category',
 hintText: 'e.g. Process'),
 textInputAction: TextInputAction.next,
 validator: (value) =>
 (value == null || value.trim().isEmpty)
 ? 'Please add a category.'
 : null,
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextFormField(
 controller: _phaseController,
 decoration: _inputDecoration('Phase',
 hintText: 'e.g. Planning'),
 textInputAction: TextInputAction.next,
 validator: (value) =>
 (value == null || value.trim().isEmpty)
 ? 'Please add a phase.'
 : null,
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 Row(
 children: [
 Expanded(
 child: VoiceTextFormField(
 controller: _statusController,
 decoration: _inputDecoration('Status',
 hintText: 'e.g. In Review'),
 textInputAction: TextInputAction.next,
 validator: (value) =>
 (value == null || value.trim().isEmpty)
 ? 'Please provide a status.'
 : null,
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextFormField(
 controller: _submittedByController,
 decoration: _inputDecoration('Submitted By',
 hintText: 'e.g. Emily Johnson'),
 textInputAction: TextInputAction.next,
 validator: (value) =>
 (value == null || value.trim().isEmpty)
 ? 'Please add a name.'
 : null,
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 VoiceTextFormField(
 controller: _dateController,
 decoration: _inputDecoration('Date', hintText: 'YYYY-MM-DD')
 .copyWith(
 suffixIcon: IconButton(
 onPressed: _pickDate,
 icon: const Icon(Icons.calendar_today_outlined),
 ),
 ),
 readOnly: true,
 onTap: _pickDate,
 validator: (value) =>
 (value == null || value.trim().isEmpty)
 ? 'Select a date.'
 : null,
 ),
 const SizedBox(height: 12),
 SwitchListTile.adaptive(
 value: _highlightRow,
 onChanged: (value) => setState(() => _highlightRow = value),
 contentPadding: EdgeInsets.zero,
 title: const Text('Highlight this lesson in the table'),
 thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? const Color(0xFFFFD700) : null),
 ),
 const SizedBox(height: 24),
 Row(
 children: [
 Expanded(
 child: OutlinedButton(
 onPressed: () => Navigator.of(context).pop(),
 style: OutlinedButton.styleFrom(
 padding: const EdgeInsets.symmetric(vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 child: const Text('Cancel'),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: ElevatedButton(
 onPressed: _handleSubmit,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: Colors.black,
 elevation: 0,
 padding: const EdgeInsets.symmetric(vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 child: Text(_isEdit ? 'Update Lesson' : 'Add Lesson'),
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 ),
 ),
 ),
 );
 }

 InputDecoration _inputDecoration(String label, {String? hintText}) {
 return InputDecoration(
 labelText: label,
 hintText: hintText,
 filled: true,
 fillColor: Colors.grey.withOpacity(0.08),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: BorderSide.none,
 ),
 contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
 );
 }

 Future<void> _pickDate() async {
 final now = DateTime.now();
 final initialDate = _selectedDate ?? now;
 final picked = await showDatePicker(
 context: context,
 initialDate: initialDate,
 firstDate: DateTime(now.year - 5),
 lastDate: DateTime(now.year + 5),
 );

 if (picked != null) {
 setState(() {
 _selectedDate = picked;
 _dateController.text = _formatDate(picked);
 });
 }
 }

 void _handleSubmit() {
 if (!_formKey.currentState!.validate()) return;

 final entry = _LessonEntry(
 id: widget.existing?.id ?? '',
 lesson: _lessonController.text.trim(),
 type: _selectedType,
 category: _categoryController.text.trim(),
 phase: _phaseController.text.trim(),
 impact: _selectedImpact,
 status: _statusController.text.trim(),
 submittedBy: _submittedByController.text.trim(),
 date: _dateController.text.trim(),
 highlight: _highlightRow,
 );

 Navigator.of(context).pop(entry);
 }

 String _formatDate(DateTime date) {
 final year = date.year.toString().padLeft(4, '0');
 final month = date.month.toString().padLeft(2, '0');
 final day = date.day.toString().padLeft(2, '0');
 return '$year-$month-$day';
 }
}

class _LessonEntry {
 final String id;
 final String lesson;
 final String type;
 final String category;
 final String phase;
 final String impact;
 final String status;
 final String submittedBy;
 final String date;
 final bool highlight;

 const _LessonEntry({
 required this.id,
 required this.lesson,
 required this.type,
 required this.category,
 required this.phase,
 required this.impact,
 required this.status,
 required this.submittedBy,
 required this.date,
 required this.highlight,
 });
}

class _SummaryStat extends StatelessWidget {
 final String label;
 final String value;
 final Color color;

 const _SummaryStat(
 {required this.label, required this.value, required this.color});

 @override
 Widget build(BuildContext context) {
 return Expanded(
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
 decoration: BoxDecoration(
 color: color.withOpacity(0.08),
 borderRadius: BorderRadius.circular(14),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 Text(
 value,
 style: TextStyle(
 fontSize: 28,
 fontWeight: FontWeight.w700,
 color: color,
 ),
 ),
 const SizedBox(height: 6),
 Text(
 label,
 style: TextStyle(fontSize: 13, color: Colors.grey[700]),
 ),
 ],
 ),
 ),
 );
 }
}
