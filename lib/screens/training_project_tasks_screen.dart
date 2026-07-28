import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/widgets/app_logo.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/widgets/launch_data_table.dart';
import 'package:ndu_project/widgets/launch_modal.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';

class _LessonItem {
 String id;
 String lesson;
 String type;
 String category;
 String phase;
 String impact;
 String status;
 String submittedBy;
 String date;

 _LessonItem({
 required this.id,
 required this.lesson,
 required this.type,
 required this.category,
 required this.phase,
 required this.impact,
 required this.status,
 required this.submittedBy,
 required this.date,
 });
}

class TrainingProjectTasksScreen extends StatefulWidget {
 const TrainingProjectTasksScreen({super.key});

 @override
 State<TrainingProjectTasksScreen> createState() => _TrainingProjectTasksScreenState();
}

class _TrainingProjectTasksScreenState extends State<TrainingProjectTasksScreen> {
 final List<_LessonItem> _lessons = [
 _LessonItem(id: 'T-001', lesson: 'Early stakeholder engagement improved', type: 'Success', category: 'Process', phase: 'Planning', impact: 'High', status: 'Implemented', submittedBy: 'Emily Johnson', date: '2025-02-15'),
 _LessonItem(id: 'T-002', lesson: 'Technical debt underestimated in legacy modules', type: 'Issue', category: 'Technical', phase: 'Execution', impact: 'High', status: 'Open', submittedBy: 'James Lee', date: '2025-03-10'),
 _LessonItem(id: 'T-003', lesson: 'Parallel testing reduced regression cycles', type: 'Success', category: 'Process', phase: 'Testing', impact: 'Medium', status: 'Implemented', submittedBy: 'Sara Khan', date: '2025-04-01'),
 _LessonItem(id: 'T-004', lesson: 'Vendor SLA monitoring needs automation', type: 'Issue', category: 'Vendor', phase: 'Operations', impact: 'Medium', status: 'Open', submittedBy: 'Omar Diaz', date: '2025-04-18'),
 ];

 String _searchQuery = '';

 List<_LessonItem> get _filtered {
 if (_searchQuery.isEmpty) return _lessons;
 final q = _searchQuery.toLowerCase();
 return _lessons.where((l) =>
 l.lesson.toLowerCase().contains(q) ||
 l.type.toLowerCase().contains(q) ||
 l.category.toLowerCase().contains(q) ||
 l.submittedBy.toLowerCase().contains(q)
 ).toList();
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: Colors.grey[50],
 body: SafeArea(
 top: true,
 child: Row(
 children: [
 _sidebar(context),
 Expanded(child: _main()),
 ],
 ),
 ),
 );
 }

 Widget _sidebar(BuildContext context) {
 return Container(
 width: 320,
 color: Colors.white,
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.all(24),
 decoration: const BoxDecoration(
 border: Border(
 bottom: BorderSide(color: Color(0xFFFFD700), width: 3),
 ),
 ),
 child:
 Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 AppLogo(
 height: 56,
 width: 148,
 ),
 SizedBox(height: 20),
 Row(children: [
 Container(
 width: 40,
 height: 40,
 decoration: const BoxDecoration(
 color: Colors.grey, shape: BoxShape.circle)),
 const SizedBox(width: 12),
 const Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('StackOne',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w600,
 color: Colors.black)),
 ]),
 ]),
 ]),
 ),
 Expanded(
 child: ListView(
 padding: const EdgeInsets.symmetric(vertical: 20),
 children: const [
 _SidebarItem(
 icon: Icons.group_work_outlined,
 title: 'Team Training and Team Building',
 isActive: true),
 ],
 ),
 ),
 const SizedBox(height: 20),
 ],
 ),
 );
 }

 Widget _main() {
 final filtered = _filtered;
 return SingleChildScrollView(
 child: Padding(
 padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
 child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 Row(children: [
 _circleIconButton(Icons.arrow_back_ios),
 const SizedBox(width: 12),
 _circleIconButton(Icons.arrow_forward_ios),
 const SizedBox(width: 16),
 const Expanded(
 child: Center(
 child: Text('Project Tasks',
 style: TextStyle(
 fontSize: 28, fontWeight: FontWeight.w600))),
 ),
 _profileChip(),
 ]),
 const SizedBox(height: 8),
 LaunchDataTable(
 title: 'Project Lessons Learned',
 subtitle: 'Track lessons, insights, and outcomes across project phases',
 columns: const [
 LaunchColumn(label: 'ID', width: 80),
 LaunchColumn(label: 'Lesson', flexible: true, hint: 'Lesson description'),
 LaunchColumn(label: 'Type', width: 110, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Success', 'Issue', 'Risk', 'Improvement']),
 LaunchColumn(label: 'Category', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Process', 'Technical', 'Vendor', 'People', 'Schedule', 'Quality']),
 LaunchColumn(label: 'Phase', width: 110, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Planning', 'Execution', 'Testing', 'Operations', 'Closure']),
 LaunchColumn(label: 'Impact', width: 100, fieldType: LaunchFieldType.dropdown, dropdownItems: ['High', 'Medium', 'Low']),
 LaunchColumn(label: 'Status', width: 130, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Implemented', 'Open', 'In Review', 'Deferred']),
 LaunchColumn(label: 'Submitted By', width: 140),
 LaunchColumn(label: 'Date', width: 120, fieldType: LaunchFieldType.date),
 ],
 rowCount: filtered.length,
 addLabel: 'Add Lesson',
 csvColumns: const [
 CsvColumnSpec(key: 'id', label: 'ID', sampleValue: 'T-005'),
 CsvColumnSpec(key: 'lesson', label: 'Lesson', sampleValue: 'Early engagement improved'),
 CsvColumnSpec(key: 'type', label: 'Type', sampleValue: 'Success', allowedValues: ['Success', 'Issue', 'Risk', 'Improvement']),
 CsvColumnSpec(key: 'category', label: 'Category', sampleValue: 'Process'),
 CsvColumnSpec(key: 'phase', label: 'Phase', sampleValue: 'Planning'),
 CsvColumnSpec(key: 'impact', label: 'Impact', sampleValue: 'High', allowedValues: ['High', 'Medium', 'Low']),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Open', allowedValues: ['Implemented', 'Open', 'In Review', 'Deferred']),
 CsvColumnSpec(key: 'submittedBy', label: 'Submitted By', sampleValue: 'Team Member'),
 CsvColumnSpec(key: 'date', label: 'Date', sampleValue: '2025-05-01'),
 ],
 onAddValues: (values) {
 setState(() {
 final nextId = 'T-${(_lessons.length + 1).toString().padLeft(3, '0')}';
 _lessons.add(_LessonItem(
 id: nextId,
 lesson: values['Lesson'] ?? '',
 type: values['Type'] ?? 'Success',
 category: values['Category'] ?? 'Process',
 phase: values['Phase'] ?? 'Planning',
 impact: values['Impact'] ?? 'Medium',
 status: values['Status'] ?? 'Open',
 submittedBy: values['Submitted By'] ?? '',
 date: values['Date'] ?? '',
 ));
 });
 },
 onCsvImport: (rows) async {
 setState(() {
 for (final row in rows) {
 final nextId = row['id']?.isNotEmpty == true
 ? row['id']!
 : 'T-${(_lessons.length + 1).toString().padLeft(3, '0')}';
 _lessons.add(_LessonItem(
 id: nextId,
 lesson: row['lesson'] ?? '',
 type: row['type'] ?? 'Success',
 category: row['category'] ?? 'Process',
 phase: row['phase'] ?? 'Planning',
 impact: row['impact'] ?? 'Medium',
 status: row['status'] ?? 'Open',
 submittedBy: row['submittedBy'] ?? '',
 date: row['date'] ?? '',
 ));
 }
 });
 },
 onSearch: (query) {
 setState(() => _searchQuery = query);
 },
 onFilter: () {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Filter options coming soon.')),
 );
 },
 cellBuilder: (context, rowIdx) {
 final item = filtered[rowIdx];
 return LaunchDataRow(
 onEdit: () => _showEditDialog(context, item),
 onDelete: () async {
 final confirmed = await launchConfirmDelete(context, itemName: item.lesson);
 if (confirmed) {
 setState(() => _lessons.removeWhere((l) => l.id == item.id));
 }
 },
 cells: [
 LaunchEditableCell(value: item.id, onChanged: (v) => item.id = v, width: 80),
 LaunchEditableCell(value: item.lesson, onChanged: (v) => item.lesson = v, expand: true),
 LaunchStatusDropdown(value: item.type, items: const ['Success', 'Issue', 'Risk', 'Improvement'], onChanged: (v) => setState(() => item.type = v ?? item.type), width: 110),
 LaunchStatusDropdown(value: item.category, items: const ['Process', 'Technical', 'Vendor', 'People', 'Schedule', 'Quality'], onChanged: (v) => setState(() => item.category = v ?? item.category), width: 120),
 LaunchStatusDropdown(value: item.phase, items: const ['Planning', 'Execution', 'Testing', 'Operations', 'Closure'], onChanged: (v) => setState(() => item.phase = v ?? item.phase), width: 110),
 LaunchStatusDropdown(value: item.impact, items: const ['High', 'Medium', 'Low'], onChanged: (v) => setState(() => item.impact = v ?? item.impact), width: 100),
 LaunchStatusDropdown(value: item.status, items: const ['Implemented', 'Open', 'In Review', 'Deferred'], onChanged: (v) => setState(() => item.status = v ?? item.status), width: 130),
 LaunchEditableCell(value: item.submittedBy, onChanged: (v) => item.submittedBy = v, width: 140),
 LaunchDateCell(value: item.date, onChanged: (v) => item.date = v, width: 120),
 ],
 );
 },
 ),
 ]),
 ),
 );
 }

 void _showEditDialog(BuildContext context, _LessonItem item) {
 final lessonCtrl = TextEditingController(text: item.lesson);
 final submittedByCtrl = TextEditingController(text: item.submittedBy);
 var type = item.type;
 var category = item.category;
 var phase = item.phase;
 var impact = item.impact;
 var status = item.status;

 showDialog(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (ctx, setDialogState) => LaunchModalShell(
 icon: Icons.edit_rounded,
 accent: const Color(0xFF0EA5E9),
 title: 'Edit Lesson',
 subtitle: 'Update the lesson details.',
 body: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 LaunchModalTextField(label: 'Lesson *', controller: lessonCtrl, hint: 'Describe the lesson'),
 const SizedBox(height: 12),
 LaunchModalTextField(label: 'Submitted By *', controller: submittedByCtrl, hint: 'Team member name'),
 const SizedBox(height: 12),
 Row(children: [
 Expanded(child: LaunchModalDropdown(label: 'Type', value: type, items: const ['Success', 'Issue', 'Risk', 'Improvement'], onChanged: (v) => setDialogState(() => type = v ?? type))),
 const SizedBox(width: 12),
 Expanded(child: LaunchModalDropdown(label: 'Category', value: category, items: const ['Process', 'Technical', 'Vendor', 'People', 'Schedule', 'Quality'], onChanged: (v) => setDialogState(() => category = v ?? category))),
 ]),
 const SizedBox(height: 12),
 Row(children: [
 Expanded(child: LaunchModalDropdown(label: 'Phase', value: phase, items: const ['Planning', 'Execution', 'Testing', 'Operations', 'Closure'], onChanged: (v) => setDialogState(() => phase = v ?? phase))),
 const SizedBox(width: 12),
 Expanded(child: LaunchModalDropdown(label: 'Impact', value: impact, items: const ['High', 'Medium', 'Low'], onChanged: (v) => setDialogState(() => impact = v ?? impact))),
 ]),
 const SizedBox(height: 12),
 LaunchModalDropdown(label: 'Status', value: status, items: const ['Implemented', 'Open', 'In Review', 'Deferred'], onChanged: (v) => setDialogState(() => status = v ?? status)),
 ],
 ),
 actions: [
 LaunchModalCancelButton(label: 'Cancel', onPressed: () => Navigator.pop(ctx)),
 LaunchModalPrimaryButton(
 label: 'Update',
 icon: Icons.check_rounded,
 onPressed: () {
 setState(() {
 item.lesson = lessonCtrl.text;
 item.submittedBy = submittedByCtrl.text;
 item.type = type;
 item.category = category;
 item.phase = phase;
 item.impact = impact;
 item.status = status;
 });
 Navigator.pop(ctx);
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Lesson updated successfully.')),
 );
 },
 ),
 ],
 ),
 ),
 );
 }

 Widget _circleIconButton(IconData icon) {
 return Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.06),
 blurRadius: 6,
 offset: const Offset(0, 2))
 ],
 ),
 child: Icon(icon, size: 16, color: Colors.grey[700]),
 );
 }

 Widget _profileChip() {
 return StreamBuilder<bool>(
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

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(26),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.06),
 blurRadius: 8,
 offset: const Offset(0, 2))
 ],
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CircleAvatar(
 radius: 16,
 backgroundColor: const Color(0xFFFBBF24),
 backgroundImage:
 photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
 child: photoUrl.isEmpty
 ? Text(
 name.isNotEmpty ? name[0].toUpperCase() : 'U',
 style: const TextStyle(
 color: Colors.white,
 fontWeight: FontWeight.bold,
 fontSize: 14),
 )
 : null,
 ),
 const SizedBox(width: 8),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(name,
 style: const TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600)),
 Text(role,
 style: const TextStyle(fontSize: 10, color: Colors.grey)),
 ],
 ),
 const SizedBox(width: 8),
 Icon(Icons.keyboard_arrow_down,
 color: Colors.grey[700], size: 18),
 ],
 ),
 );
 },
 );
 }
}

class _SidebarItem extends StatelessWidget {
 final IconData icon;
 final String title;
 final bool isActive;
 const _SidebarItem(
 {required this.icon, required this.title, this.isActive = false});
 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 decoration: BoxDecoration(
 color: isActive ? Colors.grey.withOpacity(0.06) : Colors.transparent,
 borderRadius: BorderRadius.circular(8),
 ),
 child: Row(children: [
 Icon(icon, size: 20, color: Colors.grey[600]),
 const SizedBox(width: 16),
 Expanded(
 child: Text(title,
 style: TextStyle(fontSize: 14, color: Colors.grey[700]),
 softWrap: true,
 maxLines: 2,
 overflow: TextOverflow.ellipsis),
 ),
 ]),
 ),
 );
 }
}
