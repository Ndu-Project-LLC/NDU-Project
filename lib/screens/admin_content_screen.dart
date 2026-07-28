import 'package:flutter/material.dart';
import 'package:ndu_project/models/app_content_model.dart';
import 'package:ndu_project/providers/app_content_provider.dart';
import 'package:ndu_project/services/app_content_service.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:provider/provider.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';

class AdminContentScreen extends StatefulWidget {
 const AdminContentScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context)
 .push(MaterialPageRoute(builder: (_) => const AdminContentScreen()));
 }

 @override
 State<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends State<AdminContentScreen> {
 final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
 String _selectedCategory = 'all';
 List<String> _categories = ['all'];

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 final canPop = Navigator.of(context).canPop();
 final canEdit = AdminEditToggle.isAdmin();

 return Scaffold(
 key: _scaffoldKey,
 backgroundColor: Colors.white,
 appBar: PreferredSize(
 preferredSize: const Size.fromHeight(84),
 child: SafeArea(
 bottom: false,
 child: Padding(
 padding: EdgeInsets.fromLTRB(
 isMobile ? 20 : 48, 20, isMobile ? 20 : 48, 0),
 child: Row(
 children: [
 if (canPop) ...[
 IconButton(
 onPressed: () => Navigator.of(context).maybePop(),
 icon: const Icon(Icons.arrow_back),
 color: Colors.black,
 tooltip: 'Back',
 ),
 const SizedBox(width: 8),
 ],
 const Icon(Icons.admin_panel_settings,
 color: Color(0xFFFFC107), size: 28),
 const SizedBox(width: 12),
 const Text('Admin Content Management',
 style:
 TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
 const Spacer(),
 ElevatedButton.icon(
 onPressed: _showAddContentDialog,
 icon: const Icon(Icons.add),
 label: const Text('Add Content'),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFC107),
 foregroundColor: Colors.black,
 elevation: 0,
 padding: const EdgeInsets.symmetric(
 horizontal: 18, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 body: SafeArea(
 top: true,
 child: Stack(
 children: [
 StreamBuilder<List<AppContent>>(
 stream: AppContentService.watchContent(),
 builder: (context, snapshot) {
 if (snapshot.connectionState == ConnectionState.waiting) {
 return const Center(child: CircularProgressIndicator());
 }

 if (snapshot.hasError) {
 return Center(
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 const Icon(Icons.error_outline,
 size: 64, color: Colors.red),
 const SizedBox(height: 16),
 Text('Error: ${snapshot.error}'),
 const SizedBox(height: 16),
 ElevatedButton(
 onPressed: () => setState(() {}),
 child: const Text('Retry'),
 ),
 ],
 ),
 );
 }

 final content = snapshot.data ?? [];

 // Extract unique categories
 final categories = content.isEmpty
 ? _categories
 : [
 'all',
 ...content.map((c) => c.category).toSet().toList()
 ..sort()
 ];
 if (content.isNotEmpty &&
 _categories.length != categories.length) {
 WidgetsBinding.instance.addPostFrameCallback((_) {
 setState(() => _categories = categories);
 });
 }

 final filteredContent = _selectedCategory == 'all'
 ? content
 : content
 .where((c) => c.category == _selectedCategory)
 .toList();

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Padding(
 padding: EdgeInsets.fromLTRB(
 isMobile ? 20 : 48, 20, isMobile ? 20 : 48, 12),
 child: Consumer<AppContentProvider>(
 builder: (context, provider, _) => _StaticEditBanner(
 isEnabled: provider.isStaticEditMode,
 onToggle: provider.toggleStaticEditMode,
 isMobile: isMobile,
 canEdit: canEdit,
 ),
 ),
 ),
 if (content.isEmpty)
 Expanded(
 child: Center(
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 const Icon(Icons.content_paste_off,
 size: 64, color: Colors.grey),
 const SizedBox(height: 16),
 const Text('No content available',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w600)),
 const SizedBox(height: 8),
 const Text(
 'Add your first content item to get started',
 style: TextStyle(color: Colors.black54)),
 const SizedBox(height: 24),
 ElevatedButton.icon(
 onPressed: _initializeDefaultContent,
 icon: const Icon(Icons.auto_fix_high),
 label: const Text('Initialize Default Content'),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFC107),
 foregroundColor: Colors.black,
 padding: const EdgeInsets.symmetric(
 horizontal: 20, vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ],
 ),
 ),
 )
 else ...[
 Padding(
 padding: EdgeInsets.fromLTRB(
 isMobile ? 20 : 48, 8, isMobile ? 20 : 48, 16),
 child: _buildCategoryFilter(categories),
 ),
 Expanded(
 child: ListView.builder(
 padding: EdgeInsets.fromLTRB(
 isMobile ? 20 : 48, 0, isMobile ? 20 : 48, 48),
 itemCount: filteredContent.length,
 itemBuilder: (context, index) => _ContentCard(
 content: filteredContent[index],
 onEdit: () =>
 _showEditContentDialog(filteredContent[index]),
 onDelete: () =>
 _deleteContent(filteredContent[index]),
 ),
 ),
 ),
 ],
 ],
 );
 },
 ),
 const KazAiChatBubble(),
 ],
 ),
 ),
 );
 }

 Widget _buildCategoryFilter(List<String> categories) {
 return Wrap(
 spacing: 12,
 runSpacing: 12,
 children: categories.map((category) {
 final isSelected = _selectedCategory == category;
 return ChoiceChip(
 label: Text(category == 'all'
 ? 'All Categories'
 : category.replaceAll('_', ' ').toUpperCase()),
 selected: isSelected,
 onSelected: (selected) {
 if (selected) setState(() => _selectedCategory = category);
 },
 selectedColor: const Color(0xFFFFC107),
 backgroundColor: Colors.grey.withOpacity(0.1),
 labelStyle: TextStyle(
 color: isSelected ? Colors.black : Colors.black87,
 fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
 ),
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 );
 }).toList(),
 );
 }

 Future<void> _initializeDefaultContent() async {
 await AppContentService.initializeDefaultContent();
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Default content initialized successfully'),
 backgroundColor: Colors.green),
 );
 }
 }

 Future<void> _showAddContentDialog() async {
 // Capture before await to avoid use_build_context_synchronously.
 final messenger = ScaffoldMessenger.of(context);
 await showDialog(
 context: context,
 builder: (context) => _ContentEditorDialog(
 onSave: (key, value, category, description) async {
 final content = AppContent(
 id: '',
 key: key,
 value: value,
 category: category,
 description: description.isEmpty ? null : description,
 createdAt: DateTime.now(),
 updatedAt: DateTime.now(),
 );
 final id = await AppContentService.addContent(content);
 if (!mounted) return;
 messenger.showSnackBar(
 SnackBar(
 content: Text(id != null
 ? 'Content added successfully'
 : 'Failed to add content'),
 backgroundColor: id != null ? Colors.green : Colors.red,
 ),
 );
 },
 ),
 );
 }

 Future<void> _showEditContentDialog(AppContent content) async {
 // Capture before await to avoid use_build_context_synchronously.
 final messenger = ScaffoldMessenger.of(context);
 await showDialog(
 context: context,
 builder: (context) => _ContentEditorDialog(
 existingContent: content,
 onSave: (key, value, category, description) async {
 final updated = content.copyWith(
 key: key,
 value: value,
 category: category,
 description: description.isEmpty ? null : description,
 updatedAt: DateTime.now(),
 );
 final success =
 await AppContentService.updateContent(content.id, updated);
 if (!mounted) return;
 messenger.showSnackBar(
 SnackBar(
 content: Text(success
 ? 'Content updated successfully'
 : 'Failed to update content'),
 backgroundColor: success ? Colors.green : Colors.red,
 ),
 );
 },
 ),
 );
 }

 Future<void> _deleteContent(AppContent content) async {
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (context) => AlertDialog(
 title: const Text('Delete Content'),
 content: Text('Are you sure you want to delete "${content.key}"?'),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(context, false),
 child: const Text('Cancel')),
 ElevatedButton(
 onPressed: () => Navigator.pop(context, true),
 style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
 child: const Text('Delete'),
 ),
 ],
 ),
 );

 if (confirmed == true) {
 final success = await AppContentService.deleteContent(content.id);
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(success
 ? 'Content deleted successfully'
 : 'Failed to delete content'),
 backgroundColor: success ? Colors.green : Colors.red,
 ),
 );
 }
 }
 }
}

class _StaticEditBanner extends StatelessWidget {
 const _StaticEditBanner({
 required this.isEnabled,
 required this.onToggle,
 required this.isMobile,
 required this.canEdit,
 });

 final bool isEnabled;
 final VoidCallback onToggle;
 final bool isMobile;
 final bool canEdit;

 @override
 Widget build(BuildContext context) {
 final accent = isEnabled ? Colors.green : const Color(0xFFFFC107);
 final effectiveAccent = canEdit ? accent : Colors.grey;
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: effectiveAccent.withOpacity(0.08),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: effectiveAccent.withOpacity(0.3)),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 44,
 height: 44,
 decoration: BoxDecoration(
 color: effectiveAccent.withOpacity(0.15),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Icon(isEnabled ? Icons.edit_note : Icons.edit_off,
 color: effectiveAccent, size: 24),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 isEnabled ? 'Static Edit Mode is On' : 'Static Edit Mode',
 style: const TextStyle(
 fontSize: 16, fontWeight: FontWeight.w700),
 ),
 const SizedBox(height: 6),
 Text(
 isEnabled
 ? 'Go to any page and click highlighted text to edit local, static copy.'
 : 'Enable to edit static text across pages without changing backend content.',
 style: TextStyle(color: Colors.grey[700], height: 1.4),
 ),
 if (!canEdit) ...[
 const SizedBox(height: 6),
 const Text(
 'Admin access required to enable static edit mode.',
 style: TextStyle(
 color: Colors.redAccent, fontWeight: FontWeight.w600),
 ),
 ],
 ],
 ),
 ),
 if (!isMobile) ...[
 const SizedBox(width: 12),
 ElevatedButton.icon(
 onPressed: canEdit ? onToggle : null,
 icon: Icon(isEnabled ? Icons.check : Icons.edit, size: 18),
 label: Text(isEnabled ? 'Enabled' : 'Enable'),
 style: ElevatedButton.styleFrom(
 backgroundColor: accent,
 foregroundColor: Colors.white,
 padding:
 const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(24)),
 ),
 ),
 ] else ...[
 const SizedBox(width: 8),
 IconButton(
 onPressed: canEdit ? onToggle : null,
 icon: Icon(isEnabled ? Icons.check_circle : Icons.edit,
 color: effectiveAccent),
 tooltip: isEnabled
 ? 'Disable static edit mode'
 : 'Enable static edit mode',
 ),
 ],
 ],
 ),
 );
 }
}

class _ContentCard extends StatelessWidget {
 const _ContentCard(
 {required this.content, required this.onEdit, required this.onDelete});

 final AppContent content;
 final VoidCallback onEdit;
 final VoidCallback onDelete;

 @override
 Widget build(BuildContext context) {
 return Card(
 margin: const EdgeInsets.only(bottom: 16),
 elevation: 0,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(16),
 side: BorderSide(color: Colors.grey.withOpacity(0.2)),
 ),
 child: Padding(
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: const Color(0xFFFFC107).withOpacity(0.2),
 borderRadius: BorderRadius.circular(20),
 ),
 child: Text(
 content.category.replaceAll('_', ' ').toUpperCase(),
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Colors.black87),
 ),
 ),
 const Spacer(),
 IconButton(
 onPressed: onEdit,
 icon: const Icon(Icons.edit_outlined),
 color: const Color(0xFFFFC107),
 tooltip: 'Edit',
 ),
 IconButton(
 onPressed: onDelete,
 icon: const Icon(Icons.delete_outline),
 color: Colors.red,
 tooltip: 'Delete',
 ),
 ],
 ),
 const SizedBox(height: 12),
 Text(content.key,
 style:
 const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
 const SizedBox(height: 8),
 Text(content.value,
 style: const TextStyle(
 fontSize: 16, color: Colors.black87, height: 1.4)),
 if (content.description != null) ...[
 const SizedBox(height: 12),
 Text(content.description!,
 style: TextStyle(
 fontSize: 13,
 color: Colors.grey.shade600,
 fontStyle: FontStyle.italic)),
 ],
 const SizedBox(height: 12),
 Row(
 children: [
 Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
 const SizedBox(width: 6),
 Text(
 'Updated ${_formatDate(content.updatedAt)}',
 style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
 ),
 ],
 ),
 ],
 ),
 ),
 );
 }

 String _formatDate(DateTime date) {
 final now = DateTime.now();
 final diff = now.difference(date);

 if (diff.inDays == 0) {
 if (diff.inHours == 0) {
 return '${diff.inMinutes} minutes ago';
 }
 return '${diff.inHours} hours ago';
 } else if (diff.inDays == 1) {
 return 'yesterday';
 } else if (diff.inDays < 7) {
 return '${diff.inDays} days ago';
 } else {
 return '${date.day}/${date.month}/${date.year}';
 }
 }
}

class _ContentEditorDialog extends StatefulWidget {
 const _ContentEditorDialog({this.existingContent, required this.onSave});

 final AppContent? existingContent;
 final Future<void> Function(
 String key, String value, String category, String description) onSave;

 @override
 State<_ContentEditorDialog> createState() => _ContentEditorDialogState();
}

class _ContentEditorDialogState extends State<_ContentEditorDialog> {
 late final TextEditingController _keyController;
 late final TextEditingController _valueController;
 late final TextEditingController _categoryController;
 late final TextEditingController _descriptionController;
 bool _isSaving = false;

 @override
 void initState() {
 super.initState();
 _keyController =
 TextEditingController(text: widget.existingContent?.key ?? '');
 _valueController =
 TextEditingController(text: widget.existingContent?.value ?? '');
 _categoryController = TextEditingController(
 text: widget.existingContent?.category ?? 'general');
 _descriptionController =
 TextEditingController(text: widget.existingContent?.description ?? '');
 }

 @override
 void dispose() {
 _keyController.dispose();
 _valueController.dispose();
 _categoryController.dispose();
 _descriptionController.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 return AlertDialog(
 title:
 Text(widget.existingContent == null ? 'Add Content' : 'Edit Content'),
 content: SizedBox(
 width: 600,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 VoiceTextField(
 controller: _keyController,
 decoration: const InputDecoration(
 labelText: 'Key',
 hintText: 'e.g., welcome_message',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 16),
 VoiceTextField(
 controller: _valueController,
 maxLines: 3,
 decoration: const InputDecoration(
 labelText: 'Value',
 hintText: 'Enter the text content',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 16),
 VoiceTextField(
 controller: _categoryController,
 decoration: const InputDecoration(
 labelText: 'Category',
 hintText: 'e.g., general, phase_titles, labels',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 16),
 VoiceTextField(
 controller: _descriptionController,
 maxLines: 2,
 decoration: const InputDecoration(
 labelText: 'Description (optional)',
 hintText: 'Brief description of this content',
 border: OutlineInputBorder(),
 ),
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: _isSaving ? null : () => Navigator.pop(context),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: _isSaving ? null : _handleSave,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFC107),
 foregroundColor: Colors.black,
 ),
 child: _isSaving
 ? const SizedBox(
 width: 20,
 height: 20,
 child: CircularProgressIndicator(strokeWidth: 2))
 : const Text('Save'),
 ),
 ],
 );
 }

 Future<void> _handleSave() async {
 if (_keyController.text.trim().isEmpty ||
 _valueController.text.trim().isEmpty ||
 _categoryController.text.trim().isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Key, value, and category are required'),
 backgroundColor: Colors.red),
 );
 return;
 }

 setState(() => _isSaving = true);

 try {
 await widget.onSave(
 _keyController.text.trim(),
 _valueController.text.trim(),
 _categoryController.text.trim().toLowerCase().replaceAll(' ', '_'),
 _descriptionController.text.trim(),
 );
 if (mounted) Navigator.pop(context);
 } finally {
 if (mounted) setState(() => _isSaving = false);
 }
 }
}
