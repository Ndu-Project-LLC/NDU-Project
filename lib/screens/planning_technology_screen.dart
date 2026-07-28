import 'package:flutter/material.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/utils/text_sanitizer.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/inner_page_navigation_hint.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
enum _TechnologyTab {
 inventory('Technology Inventory'),
 aiIntegrations('AI Integrations'),
 externalIntegrations('External Integrations'),
 definitions('Technology Definitions'),
 aiRecommendations('AI Recommendations');

 const _TechnologyTab(this.label);
 final String label;
}

class PlanningTechnologyScreen extends StatefulWidget {
 const PlanningTechnologyScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const PlanningTechnologyScreen()),
 );
 }

 @override
 State<PlanningTechnologyScreen> createState() =>
 _PlanningTechnologyScreenState();
}

class _PlanningTechnologyScreenState extends State<PlanningTechnologyScreen> {
 static const List<String> _statusOptions = <String>[
 'Proposed/Pending',
 'Deployed',
 'Implemented',
 'Dismissed',
 ];

 final List<Map<String, dynamic>> _inventory = [];
 final List<Map<String, dynamic>> _aiIntegrations = [];
 final List<Map<String, dynamic>> _externalIntegrations = [];
 final List<Map<String, dynamic>> _definitions = [];
 final List<Map<String, dynamic>> _recommendations = [];

 _TechnologyTab _selectedTab = _TechnologyTab.inventory;
 bool _loading = true;
 bool _regenerating = false;

 String _inventorySearch = '';
 String _inventoryCategory = 'All Categories';

 @override
 void initState() {
 super.initState();
 ApiKeyManager.initializeApiKey();
 WidgetsBinding.instance.addPostFrameCallback((_) => _load());
 }

 void _load() {
 final provider = ProjectDataInherited.maybeOf(context);
 if (provider == null) {
 if (mounted) setState(() => _loading = false);
 return;
 }

 final data = provider.projectData;
 _inventory
 ..clear()
 ..addAll(
 data.technologyInventory.map((e) => Map<String, dynamic>.from(e)));
 _aiIntegrations
 ..clear()
 ..addAll(data.aiIntegrations.map((e) => Map<String, dynamic>.from(e)));
 _externalIntegrations
 ..clear()
 ..addAll(
 data.externalIntegrations.map((e) => Map<String, dynamic>.from(e)));
 _definitions
 ..clear()
 ..addAll(
 data.technologyDefinitions.map((e) => Map<String, dynamic>.from(e)));
 _recommendations
 ..clear()
 ..addAll(data.aiRecommendations.map((e) => Map<String, dynamic>.from(e)));

 if (mounted) setState(() => _loading = false);
 }

 Future<void> _save({String checkpoint = 'technology'}) async {
 final provider = ProjectDataInherited.maybeOf(context);
 if (provider == null) return;
 provider.updateField(
 (d) => d.copyWith(
 technologyInventory: _inventory,
 aiIntegrations: _aiIntegrations,
 externalIntegrations: _externalIntegrations,
 technologyDefinitions: _definitions,
 aiRecommendations: _recommendations,
 ),
 );
 await provider.saveToFirebase(checkpoint: checkpoint);
 }

 Future<void> _regenerateCurrentTab() async {
 if (_regenerating) return;
 final provider = ProjectDataInherited.maybeOf(context);
 if (provider == null) return;

 setState(() => _regenerating = true);
 final ai = OpenAiServiceSecure();
 final ctx = _buildAiContextForCurrentTab(provider.projectData);

 try {
 switch (_selectedTab) {
 case _TechnologyTab.inventory:
 final text = await ai.generateFepSectionText(
 section: 'Technology Inventory',
 context:
 '$ctx\nOutput format (one per line): Name | Category | Cost | Status | Vendor | Added Date (YYYY-MM-DD) | Notes',
 maxTokens: 700,
 );
 final lines = TextSanitizer.sanitizeAiText(text)
 .split('\n')
 .where((l) => l.trim().isNotEmpty);
 _inventory
 ..clear()
 ..addAll(lines.map((line) {
 final parts = line.split('|').map((p) => p.trim()).toList();
 return {
 'name': parts.isNotEmpty ? parts[0] : line.trim(),
 'category': parts.length > 1 ? parts[1] : 'Software',
 'cost': parts.length > 2 ? parts[2] : '',
 'status': _normalizeStatus(
 parts.length > 3 ? parts[3] : 'Proposed/Pending'),
 'vendor': parts.length > 4 ? parts[4] : '',
 'added': parts.length > 5 ? parts[5] : '',
 'notes': parts.length > 6 ? parts.sublist(6).join(' | ') : '',
 };
 }));
 break;
 case _TechnologyTab.aiIntegrations:
 final text = await ai.generateFepSectionText(
 section: 'AI Integrations',
 context:
 '$ctx\nOutput format (one per line): Name | Description | Status | Cost',
 maxTokens: 700,
 );
 final lines = TextSanitizer.sanitizeAiText(text)
 .split('\n')
 .where((l) => l.trim().isNotEmpty);
 _aiIntegrations
 ..clear()
 ..addAll(lines.map((line) {
 final parts = line.split('|').map((p) => p.trim()).toList();
 return {
 'name': parts.isNotEmpty ? parts[0] : line.trim(),
 'description': parts.length > 1 ? parts[1] : '',
 'status': _normalizeStatus(
 parts.length > 2 ? parts[2] : 'Proposed/Pending'),
 'cost': parts.length > 3 ? parts[3] : '',
 };
 }));
 break;
 case _TechnologyTab.externalIntegrations:
 final text = await ai.generateFepSectionText(
 section: 'External Integrations',
 context:
 '$ctx\nOutput format (one per line): Name | Description | Status | Connection Type | Complexity | Implementation Cost',
 maxTokens: 700,
 );
 final lines = TextSanitizer.sanitizeAiText(text)
 .split('\n')
 .where((l) => l.trim().isNotEmpty);
 _externalIntegrations
 ..clear()
 ..addAll(lines.map((line) {
 final parts = line.split('|').map((p) => p.trim()).toList();
 return {
 'name': parts.isNotEmpty ? parts[0] : line.trim(),
 'description': parts.length > 1 ? parts[1] : '',
 'status': _normalizeStatus(
 parts.length > 2 ? parts[2] : 'Proposed/Pending'),
 'connectionType': parts.length > 3 ? parts[3] : 'API',
 'complexity': parts.length > 4 ? parts[4] : 'Medium',
 'implementationCost': parts.length > 5 ? parts[5] : '',
 };
 }));
 break;
 case _TechnologyTab.definitions:
 final text = await ai.generateFepSectionText(
 section: 'Technology Definitions',
 context: '$ctx\nOutput format (one per line): Term - Definition',
 maxTokens: 700,
 );
 final lines = TextSanitizer.sanitizeAiText(text)
 .split('\n')
 .where((l) => l.trim().isNotEmpty);
 _definitions
 ..clear()
 ..addAll(lines.map((line) {
 final parts = line.split('-').map((p) => p.trim()).toList();
 return {
 'term': parts.isNotEmpty ? parts[0] : line.trim(),
 'definition':
 parts.length > 1 ? parts.sublist(1).join(' - ') : '',
 };
 }));
 break;
 case _TechnologyTab.aiRecommendations:
 final text = await ai.generateFepSectionText(
 section: 'AI Recommendations',
 context:
 '$ctx\nOutput format (one per line): Recommendation | Description | Estimated Cost | Suggested Vendor',
 maxTokens: 900,
 );
 final lines = TextSanitizer.sanitizeAiText(text)
 .split('\n')
 .where((l) => l.trim().isNotEmpty);
 _recommendations
 ..clear()
 ..addAll(lines.map((line) {
 final parts = line.split('|').map((p) => p.trim()).toList();
 return {
 'recommendation': parts.isNotEmpty ? parts[0] : line.trim(),
 'description': parts.length > 1 ? parts[1] : '',
 'estimatedCost': parts.length > 2 ? parts[2] : '',
 'vendor': parts.length > 3 ? parts[3] : '',
 'status': 'Proposed/Pending',
 };
 }));
 break;
 }

 await _save();
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Regenerate failed: $e')),
 );
 } finally {
 if (mounted) setState(() => _regenerating = false);
 }
 }

 Future<void> _openAddDialog() async {
 switch (_selectedTab) {
 case _TechnologyTab.inventory:
 await _openInventoryDialog();
 break;
 case _TechnologyTab.aiIntegrations:
 await _openIntegrationDialog(isExternal: false);
 break;
 case _TechnologyTab.externalIntegrations:
 await _openIntegrationDialog(isExternal: true);
 break;
 case _TechnologyTab.definitions:
 await _openDefinitionDialog();
 break;
 case _TechnologyTab.aiRecommendations:
 await _openRecommendationDialog();
 break;
 }
 }

 Future<void> _openInventoryDialog({int? index}) async {
 final existing = index != null ? _inventory[index] : <String, dynamic>{};
 final name =
 TextEditingController(text: existing['name']?.toString() ?? '');
 final category =
 TextEditingController(text: existing['category']?.toString() ?? '');
 final cost =
 TextEditingController(text: existing['cost']?.toString() ?? '');
 final vendor =
 TextEditingController(text: existing['vendor']?.toString() ?? '');

 String status =
 _normalizeStatus(existing['status']?.toString() ?? 'Proposed/Pending');
 String date = existing['added']?.toString() ?? '';

 final save = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (context, setLocalState) => AlertDialog(
 title: Text(
 index == null ? 'Add technology item' : 'Edit technology item'),
 content: SizedBox(
 width: MediaQuery.of(context).size.width * 0.82,
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 1100),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: name,
 decoration: const InputDecoration(labelText: 'Name'),
 ),
 VoiceTextField(
 controller: category,
 decoration: const InputDecoration(labelText: 'Category'),
 ),
 VoiceTextField(
 controller: cost,
 decoration: const InputDecoration(labelText: 'Cost'),
 ),
 DropdownButtonFormField<String>(
 value: status,
 decoration: const InputDecoration(labelText: 'Status'),
 items: _statusOptions
 .map((s) => DropdownMenuItem<String>(
 value: s,
 child: Text(s),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setLocalState(() => status = value);
 },
 ),
 VoiceTextField(
 controller: vendor,
 decoration: const InputDecoration(labelText: 'Vendor'),
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: Text(
 date.isEmpty
 ? 'Added Date: Not set'
 : 'Added Date: $date',
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF4B5563),
 ),
 ),
 ),
 OutlinedButton.icon(
 onPressed: () async {
 final now = DateTime.now();
 final picked = await showDatePicker(
 context: dialogContext,
 initialDate: _parseDateOrNow(date),
 firstDate: DateTime(now.year - 15),
 lastDate: DateTime(now.year + 15),
 );
 if (picked == null) return;
 setLocalState(() {
 date = picked.toIso8601String().split('T').first;
 });
 },
 icon:
 const Icon(Icons.calendar_today_outlined, size: 16),
 label: const Text('Select date'),
 ),
 ],
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(dialogContext).pop(true),
 child: const Text('Save'),
 ),
 ],
 ),
 ),
 );

 if (save != true) return;

 final item = <String, dynamic>{
 'name': name.text.trim(),
 'category': category.text.trim(),
 'cost': cost.text.trim(),
 'status': status,
 'vendor': vendor.text.trim(),
 'added': date,
 };

 setState(() {
 if (index == null) {
 _inventory.add(item);
 } else {
 _inventory[index] = item;
 }
 });
 await _save();
 }

 Future<void> _openIntegrationDialog(
 {required bool isExternal, int? index}) async {
 final list = isExternal ? _externalIntegrations : _aiIntegrations;
 final existing = index != null ? list[index] : <String, dynamic>{};

 final name =
 TextEditingController(text: existing['name']?.toString() ?? '');
 final description =
 TextEditingController(text: existing['description']?.toString() ?? '');
 final cost = TextEditingController(
 text: existing['cost']?.toString() ??
 existing['implementationCost']?.toString() ??
 '',
 );

 String status =
 _normalizeStatus(existing['status']?.toString() ?? 'Proposed/Pending');

 final save = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (context, setLocalState) => AlertDialog(
 title: Text(index == null ? 'Add integration' : 'Edit integration'),
 content: SizedBox(
 width: MediaQuery.of(context).size.width * 0.75,
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 900),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: name,
 decoration: const InputDecoration(labelText: 'Name'),
 ),
 VoiceTextField(
 controller: description,
 decoration: const InputDecoration(labelText: 'Description'),
 ),
 DropdownButtonFormField<String>(
 value: status,
 decoration: const InputDecoration(labelText: 'Status'),
 items: _statusOptions
 .map((s) => DropdownMenuItem<String>(
 value: s,
 child: Text(s),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setLocalState(() => status = value);
 },
 ),
 VoiceTextField(
 controller: cost,
 decoration: InputDecoration(
 labelText: isExternal
 ? 'Implementation Cost'
 : 'Integration Cost',
 ),
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(dialogContext).pop(true),
 child: const Text('Save'),
 ),
 ],
 ),
 ),
 );

 if (save != true) return;

 final item = <String, dynamic>{
 ...existing,
 'name': name.text.trim(),
 'description': description.text.trim(),
 'status': status,
 if (isExternal)
 'implementationCost': cost.text.trim()
 else
 'cost': cost.text.trim(),
 };

 setState(() {
 if (index == null) {
 list.add(item);
 } else {
 list[index] = item;
 }
 });
 await _save();
 }

 Future<void> _openDefinitionDialog({int? index}) async {
 final existing = index != null ? _definitions[index] : <String, dynamic>{};
 final term = TextEditingController(
 text: existing['term']?.toString() ?? existing['name']?.toString() ?? '',
 );
 final definition = TextEditingController(
 text: existing['definition']?.toString() ??
 existing['description']?.toString() ??
 '',
 );

 final save = await showDialog<bool>(
 context: context,
 builder: (c) => AlertDialog(
 title: Text(index == null
 ? 'Add technology definition'
 : 'Edit technology definition'),
 content: SizedBox(
 width: MediaQuery.of(context).size.width * 0.7,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: term,
 decoration: const InputDecoration(labelText: 'Term'),
 ),
 VoiceTextField(
 controller: definition,
 maxLines: 5,
 decoration: const InputDecoration(labelText: 'Definition'),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(c).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(c).pop(true),
 child: const Text('Save'),
 ),
 ],
 ),
 );

 if (save != true) return;

 final item = <String, dynamic>{
 ...existing,
 'term': term.text.trim(),
 'definition': definition.text.trim(),
 };

 setState(() {
 if (index == null) {
 _definitions.add(item);
 } else {
 _definitions[index] = item;
 }
 });
 await _save();
 }

 Future<void> _openRecommendationDialog({int? index}) async {
 final existing =
 index != null ? _recommendations[index] : <String, dynamic>{};
 final recommendation = TextEditingController(
 text: existing['recommendation']?.toString() ??
 existing['title']?.toString() ??
 '',
 );
 final description =
 TextEditingController(text: existing['description']?.toString() ?? '');
 final cost = TextEditingController(
 text: existing['estimatedCost']?.toString() ?? '');
 final vendor =
 TextEditingController(text: existing['vendor']?.toString() ?? '');

 final save = await showDialog<bool>(
 context: context,
 builder: (c) => AlertDialog(
 title:
 Text(index == null ? 'Add recommendation' : 'Edit recommendation'),
 content: SizedBox(
 width: MediaQuery.of(context).size.width * 0.75,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: recommendation,
 decoration: const InputDecoration(labelText: 'Recommendation'),
 ),
 VoiceTextField(
 controller: description,
 decoration: const InputDecoration(labelText: 'Description'),
 ),
 VoiceTextField(
 controller: cost,
 decoration: const InputDecoration(labelText: 'Estimated Cost'),
 ),
 VoiceTextField(
 controller: vendor,
 decoration:
 const InputDecoration(labelText: 'Suggested Vendor'),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(c).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(c).pop(true),
 child: const Text('Save'),
 ),
 ],
 ),
 );

 if (save != true) return;

 final item = <String, dynamic>{
 ...existing,
 'recommendation': recommendation.text.trim(),
 'description': description.text.trim(),
 'estimatedCost': cost.text.trim(),
 'vendor': vendor.text.trim(),
 'status': existing['status']?.toString().isNotEmpty == true
 ? existing['status']
 : 'Proposed/Pending',
 };

 setState(() {
 if (index == null) {
 _recommendations.add(item);
 } else {
 _recommendations[index] = item;
 }
 });
 await _save();
 }

 Future<bool> _confirmDelete() async {
 final result = await showDialog<bool>(
 context: context,
 builder: (c) => AlertDialog(
 title: const Text('Delete item'),
 content: const Text(
 'Are you sure you want to delete this item? This action cannot be undone.'),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(c).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(c).pop(true),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFDC2626)),
 child: const Text('Delete'),
 ),
 ],
 ),
 );
 return result == true;
 }

 Future<void> _removeAtCurrentTab(int index) async {
 final confirmed = await _confirmDelete();
 if (!confirmed) return;

 setState(() {
 switch (_selectedTab) {
 case _TechnologyTab.inventory:
 _inventory.removeAt(index);
 break;
 case _TechnologyTab.aiIntegrations:
 _aiIntegrations.removeAt(index);
 break;
 case _TechnologyTab.externalIntegrations:
 _externalIntegrations.removeAt(index);
 break;
 case _TechnologyTab.definitions:
 _definitions.removeAt(index);
 break;
 case _TechnologyTab.aiRecommendations:
 _recommendations.removeAt(index);
 break;
 }
 });
 await _save();
 }

 Future<void> _implementRecommendation(int index) async {
 if (index < 0 || index >= _recommendations.length) return;
 final recommendation = Map<String, dynamic>.from(_recommendations[index]);
 final title = _recommendationTitle(recommendation);
 final desc = recommendation['description']?.toString() ?? '';
 final estimatedCost = recommendation['estimatedCost']?.toString() ?? '';

 final hasInventoryItem = _inventory.any(
 (item) =>
 item['name']?.toString().trim().toLowerCase() ==
 title.trim().toLowerCase(),
 );
 if (!hasInventoryItem) {
 _inventory.add({
 'name': title,
 'category': 'AI Recommendation',
 'cost': estimatedCost,
 'status': 'Proposed/Pending',
 'vendor': recommendation['vendor']?.toString() ?? '',
 'added': DateTime.now().toIso8601String().split('T').first,
 'notes': desc,
 });
 }

 final hasAiIntegration = _aiIntegrations.any(
 (item) =>
 item['name']?.toString().trim().toLowerCase() ==
 title.trim().toLowerCase(),
 );
 if (!hasAiIntegration) {
 _aiIntegrations.add({
 'name': title,
 'description': desc,
 'status': 'Proposed/Pending',
 'cost': estimatedCost,
 });
 }

 _recommendations[index] = {
 ...recommendation,
 'status': 'Implemented',
 };

 setState(() {});
 await _save();
 }

 Future<void> _dismissRecommendation(int index) async {
 if (index < 0 || index >= _recommendations.length) return;
 setState(() {
 _recommendations[index] = {
 ..._recommendations[index],
 'status': 'Dismissed',
 };
 });
 await _save();
 }

 List<Map<String, dynamic>> get _filteredInventory {
 return _inventory.where((item) {
 final name = (item['name'] ?? '').toString().toLowerCase();
 final category = (item['category'] ?? '').toString();
 final searchOk = _inventorySearch.trim().isEmpty ||
 name.contains(_inventorySearch.trim().toLowerCase());
 final categoryOk = _inventoryCategory == 'All Categories' ||
 category == _inventoryCategory;
 return searchOk && categoryOk;
 }).toList();
 }

 List<String> get _categories {
 final set = <String>{'All Categories'};
 for (final item in _inventory) {
 final category = item['category']?.toString().trim() ?? '';
 if (category.isNotEmpty) set.add(category);
 }
 return set.toList();
 }

 String _recommendationTitle(Map<String, dynamic> rec) {
 final title = rec['recommendation']?.toString().trim();
 if (title != null && title.isNotEmpty) return title;
 final fallback = rec['title']?.toString().trim();
 if (fallback != null && fallback.isNotEmpty) return fallback;
 return 'Untitled Recommendation';
 }

 String _normalizeStatus(String raw) {
 final lower = raw.trim().toLowerCase();
 if (lower.contains('deploy')) return 'Deployed';
 if (lower.contains('implement')) return 'Implemented';
 if (lower.contains('dismiss')) return 'Dismissed';
 return 'Proposed/Pending';
 }

 String _statusOf(Map<String, dynamic> item) {
 return _normalizeStatus(item['status']?.toString() ?? 'Proposed/Pending');
 }

 DateTime _parseDateOrNow(String raw) {
 final parsed = DateTime.tryParse(raw);
 return parsed ?? DateTime.now();
 }

 double _parseAmount(String raw) {
 final cleaned = raw.replaceAll(',', '');
 final match = RegExp(r'(-?\d+(?:\.\d+)?)').firstMatch(cleaned);
 if (match == null) return 0;
 return double.tryParse(match.group(1) ?? '') ?? 0;
 }

 (double oneTime, double annual) _computeBudget() {
 double oneTime = 0;
 double annual = 0;

 void absorb(Map<String, dynamic> item, String key) {
 final value = item[key]?.toString() ?? '';
 if (value.trim().isEmpty) return;
 final amount = _parseAmount(value);
 final normalized = value.toLowerCase();
 if (normalized.contains('/month') || normalized.contains('monthly')) {
 annual += amount * 12;
 } else if (normalized.contains('/year') ||
 normalized.contains('annual')) {
 annual += amount;
 } else {
 oneTime += amount;
 }
 }

 for (final item in _inventory) {
 absorb(item, 'cost');
 }
 for (final item in _aiIntegrations) {
 absorb(item, 'cost');
 }
 for (final item in _externalIntegrations) {
 absorb(item, 'implementationCost');
 }

 return (oneTime, annual);
 }

 int _countByCategory(String category) {
 return _inventory
 .where((item) =>
 (item['category']?.toString().toLowerCase() ?? '') ==
 category.toLowerCase())
 .length;
 }

 int get _deployedCount => _aiIntegrations
 .where((item) => _statusOf(item).toLowerCase().contains('deployed'))
 .length;

 int get _proposedPendingCount => _aiIntegrations
 .where((item) => _statusOf(item).toLowerCase().contains('proposed'))
 .length;

 int get _availableRecommendationCount => _recommendations.where((item) {
 final status = _statusOf(item).toLowerCase();
 return !status.contains('dismissed') && !status.contains('implemented');
 }).length;

 String _formatCurrency(double value) {
 final rounded = value.round();
 final s = rounded.toString();
 final withCommas = s.replaceAllMapped(
 RegExp(r'\B(?=(\d{3})+(?!\d))'),
 (match) => ',',
 );
 return '\$$withCommas';
 }

 String _buildAiContextForCurrentTab(ProjectDataModel data) {
 String takeNames(List<Map<String, dynamic>> list, String key) {
 if (list.isEmpty) return 'none';
 return list
 .take(8)
 .map((item) => (item[key] ?? '').toString().trim())
 .where((e) => e.isNotEmpty)
 .join(', ');
 }

 return [
 'You are preparing enterprise technology planning data.',
 'Project Name: ${data.projectName}',
 'Solution Title: ${data.solutionTitle}',
 'Project Objective: ${data.projectObjective}',
 'Business Case: ${data.businessCase}',
 'Initiation Notes: ${data.notes}',
 'FEP Technology Notes: ${data.frontEndPlanning.technology}',
 'Existing Inventory: ${takeNames(_inventory, 'name')}',
 'Existing AI Integrations: ${takeNames(_aiIntegrations, 'name')}',
 'Existing External Integrations: ${takeNames(_externalIntegrations, 'name')}',
 'Existing Definitions: ${takeNames(_definitions, 'term')}',
 'Generate concise, realistic entries specific to this project context.',
 ].join('\n');
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
 activeItemLabel: 'Technology Planning',
 ),
 ),
 Expanded(
 child: _loading
 ? const Center(child: CircularProgressIndicator())
 : SingleChildScrollView(
 padding: padding,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(
 title: 'Technology Planning',
onBack: () =>
 PlanningPhaseNavigation.goToPrevious(
 context,
 'technology',
 ),
 onForward: () =>
 PlanningPhaseNavigation.goToNext(
 context,
 'technology',
 ), onExportPdf: _exportPdf),
 const SizedBox(height: 18),
 _buildTopMetrics(),
 const SizedBox(height: 14),
 _buildTabsBar(),
 const SizedBox(height: 12),
 InnerPageNavigationHint(
 pageId: 'planning_technology',
 pageTitle: 'Technology Planning',
 sections: _TechnologyTab.values.map((tab) => InnerPageSection(
 id: tab.name,
 label: tab.label,
 status: tab == _selectedTab
 ? InnerPageSectionStatus.current
 : InnerPageSectionStatus.available,
 stepNumber: _TechnologyTab.values.indexOf(tab) + 1,
 )).toList(),
 currentSectionId: _selectedTab.name,
 onSectionTap: (sectionId) {
 final tab = _TechnologyTab.values.firstWhere(
 (t) => t.name == sectionId);
 setState(() => _selectedTab = tab);
 },
 ),
 _buildCurrentTabContent(),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: PlanningPhaseNavigation.backLabel(
 'technology'),
 nextLabel: PlanningPhaseNavigation.nextLabel(
 'technology'),
 onBack: () =>
 PlanningPhaseNavigation.goToPrevious(
 context,
 'technology',
 ),
 onNext: () => PlanningPhaseNavigation.goToNext(
 context,
 'technology',
 ),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Technology Planning',
 ),
 ),
 const KazAiChatBubble(),
 ],
 ),
 ),
 );
 }

 Widget _buildTopMetrics() {
 final budget = _computeBudget();
 return Row(
 children: [
 Expanded(
 child: _MetricCard(
 title: 'Total Technology Items',
 value: '${_inventory.length}',
 rows: [
 _MetricRow(
 label: 'Hardware',
 value: _countByCategory('Hardware').toString()),
 _MetricRow(
 label: 'Software',
 value: _countByCategory('Software').toString()),
 _MetricRow(
 label: 'Development Tools',
 value: _countByCategory('Development Tools').toString()),
 ],
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: _MetricCard(
 title: 'Total Technology Budget',
 value: _formatCurrency(budget.$1),
 rows: [
 _MetricRow(
 label: 'One-time Costs', value: _formatCurrency(budget.$1)),
 _MetricRow(
 label: 'Annual Running Costs',
 value: '${_formatCurrency(budget.$2)}/year'),
 ],
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: _MetricCard(
 title: 'AI Integrations',
 value: '${_aiIntegrations.length}',
 rows: [
 _MetricRow(label: 'Deployed', value: '$_deployedCount'),
 _MetricRow(
 label: 'Proposed/Pending', value: '$_proposedPendingCount'),
 _MetricRow(
 label: 'Available Recommendations',
 value: '$_availableRecommendationCount'),
 ],
 ),
 ),
 ],
 );
 }

 Widget _buildTabsBar() {
 return Container(
 padding: const EdgeInsets.all(6),
 decoration: BoxDecoration(
 color: const Color(0xFFF4B422),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Row(
 children: _TechnologyTab.values.map((tab) {
 final selected = tab == _selectedTab;
 return Expanded(
 child: InkWell(
 onTap: () => setState(() => _selectedTab = tab),
 borderRadius: BorderRadius.circular(8),
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 160),
 padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
 decoration: BoxDecoration(
 color: selected ? Colors.white : Colors.transparent,
 borderRadius: BorderRadius.circular(8),
 ),
 child: Text(
 tab.label,
 textAlign: TextAlign.center,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: selected ? const Color(0xFF111827) : Colors.white,
 ),
 ),
 ),
 ),
 );
 }).toList(),
 ),
 );
 }

 Widget _buildCurrentTabContent() {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Text(
 _selectedTab.label,
 style: const TextStyle(
 fontSize: 22,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ),
 OutlinedButton.icon(
 onPressed: _regenerating ? null : _regenerateCurrentTab,
 icon: const Icon(Icons.auto_awesome_outlined, size: 16),
 label: Text(_regenerating ? 'Regenerating...' : 'Regenerate'),
 ),
 const SizedBox(width: 8),
 ElevatedButton.icon(
 onPressed: _openAddDialog,
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add'),
 ),
 ],
 ),
 const SizedBox(height: 16),
 switch (_selectedTab) {
 _TechnologyTab.inventory => _buildInventoryContent(),
 _TechnologyTab.aiIntegrations => _buildIntegrationsContent(false),
 _TechnologyTab.externalIntegrations =>
 _buildIntegrationsContent(true),
 _TechnologyTab.definitions => _buildDefinitionsContent(),
 _TechnologyTab.aiRecommendations => _buildRecommendationsContent(),
 },
 ],
 ),
 );
 }

 Widget _buildInventoryContent() {
 final rows = _filteredInventory;
 return Column(
 children: [
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 onChanged: (value) => setState(() => _inventorySearch = value),
 decoration: const InputDecoration(
 hintText: 'Search technology...',
 prefixIcon: Icon(Icons.search, size: 18),
 border: OutlineInputBorder(),
 isDense: true,
 ),
 ),
 ),
 const SizedBox(width: 12),
 SizedBox(
 width: 280,
 child: DropdownButtonFormField<String>(
 isExpanded: true,
 value: _categories.contains(_inventoryCategory)
 ? _inventoryCategory
 : 'All Categories',
 items: _categories
 .map((category) => DropdownMenuItem<String>(
 value: category,
 child: Text(
 category,
 overflow: TextOverflow.ellipsis,
 ),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setState(() => _inventoryCategory = value);
 },
 decoration: const InputDecoration(
 border: OutlineInputBorder(),
 isDense: true,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 14),
 _buildTableHeader(
 const [
 'Name',
 'Category',
 'Cost',
 'Status',
 'Vendor',
 'Added',
 'Actions'
 ],
 const [5, 2, 2, 2, 2, 2, 2],
 ),
 ...List.generate(rows.length, (index) {
 final item = rows[index];
 final sourceIndex = _inventory.indexOf(item);
 return _buildTableRow(
 [
 Text(
 item['name']?.toString() ?? '',
 maxLines: 3,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(fontSize: 12),
 ),
 Text(item['category']?.toString() ?? '',
 style: const TextStyle(fontSize: 12)),
 Text(item['cost']?.toString() ?? '',
 style: const TextStyle(fontSize: 12)),
 _StatusBadge(label: _statusOf(item)),
 Text(item['vendor']?.toString() ?? '',
 style: const TextStyle(fontSize: 12)),
 Text(item['added']?.toString() ?? '',
 style: const TextStyle(fontSize: 12)),
 Wrap(
 spacing: 2,
 children: [
 IconButton(
 tooltip: 'Edit',
 onPressed: () => _openInventoryDialog(index: sourceIndex),
 icon: const Icon(Icons.edit_outlined, size: 16),
 ),
 IconButton(
 tooltip: 'Delete',
 onPressed: () => _removeAtCurrentTab(sourceIndex),
 icon: const Icon(Icons.delete_outline, size: 16),
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
 ],
 const [5, 2, 2, 2, 2, 2, 2],
 );
 }),
 ],
 );
 }

 Widget _buildIntegrationsContent(bool external) {
 final list = external ? _externalIntegrations : _aiIntegrations;
 final headers = external
 ? const [
 'Name',
 'Description',
 'Status',
 'Connection',
 'Complexity',
 'Cost',
 'Actions'
 ]
 : const ['Name', 'Description', 'Status', 'Cost', 'Actions'];
 final flexes =
 external ? const [3, 4, 2, 2, 2, 2, 2] : const [3, 5, 2, 2, 2];

 return Column(
 children: [
 _buildTableHeader(headers, flexes),
 ...List.generate(list.length, (index) {
 final item = list[index];
 final cells = <Widget>[
 Text(item['name']?.toString() ?? '',
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(fontSize: 12)),
 Text(item['description']?.toString() ?? '',
 maxLines: 3,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(fontSize: 12)),
 _StatusBadge(label: _statusOf(item)),
 if (external)
 Text(item['connectionType']?.toString() ?? 'API',
 style: const TextStyle(fontSize: 12)),
 if (external)
 Text(item['complexity']?.toString() ?? 'Medium',
 style: const TextStyle(fontSize: 12)),
 Text(
 (external ? item['implementationCost'] : item['cost'])
 ?.toString() ??
 '',
 style: const TextStyle(fontSize: 12)),
 Wrap(
 spacing: 2,
 children: [
 IconButton(
 tooltip: 'Edit',
 onPressed: () => _openIntegrationDialog(
 isExternal: external,
 index: index,
 ),
 icon: const Icon(Icons.edit_outlined, size: 16),
 ),
 IconButton(
 tooltip: 'Delete',
 onPressed: () => _removeAtCurrentTab(index),
 icon: const Icon(Icons.delete_outline, size: 16),
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
 ];
 return _buildTableRow(cells, flexes);
 }),
 ],
 );
 }

 Widget _buildDefinitionsContent() {
 return Column(
 children: [
 _buildTableHeader(
 const ['Term', 'Definition', 'Actions'], const [2, 7, 2]),
 ...List.generate(_definitions.length, (index) {
 final item = _definitions[index];
 final title =
 item['term']?.toString() ?? item['name']?.toString() ?? '';
 final definition = item['definition']?.toString() ??
 item['description']?.toString() ??
 '';
 return _buildTableRow(
 [
 Text(title,
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(fontSize: 12)),
 Text(definition,
 maxLines: 4,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(fontSize: 12)),
 Wrap(
 spacing: 2,
 children: [
 IconButton(
 tooltip: 'Edit',
 onPressed: () => _openDefinitionDialog(index: index),
 icon: const Icon(Icons.edit_outlined, size: 16),
 ),
 IconButton(
 tooltip: 'Delete',
 onPressed: () => _removeAtCurrentTab(index),
 icon: const Icon(Icons.delete_outline, size: 16),
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
 ],
 const [2, 7, 2],
 );
 }),
 ],
 );
 }

 Widget _buildRecommendationsContent() {
 return Column(
 children: [
 _buildTableHeader(
 const [
 'Recommendation',
 'Description',
 'Est. Cost',
 'Status',
 'Actions'
 ],
 const [4, 4, 2, 2, 3],
 ),
 ...List.generate(_recommendations.length, (index) {
 final item = _recommendations[index];
 final title = _recommendationTitle(item);
 final status = _statusOf(item);
 final isImplemented = status.toLowerCase().contains('implemented');
 final isDismissed = status.toLowerCase().contains('dismissed');
 return _buildTableRow(
 [
 Text(title,
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(fontSize: 12)),
 Text(item['description']?.toString() ?? '',
 maxLines: 3,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(fontSize: 12)),
 Text(item['estimatedCost']?.toString() ?? '',
 style: const TextStyle(fontSize: 12)),
 _StatusBadge(label: status),
 Wrap(
 spacing: 2,
 runSpacing: 2,
 children: [
 ElevatedButton.icon(
 onPressed: (isImplemented || isDismissed)
 ? null
 : () => _implementRecommendation(index),
 icon: const Icon(Icons.check, size: 14),
 label: const Text('Implement'),
 ),
 TextButton(
 onPressed: isDismissed
 ? null
 : () => _dismissRecommendation(index),
 child: const Text('Dismiss'),
 ),
 IconButton(
 tooltip: 'Edit',
 onPressed: () => _openRecommendationDialog(index: index),
 icon: const Icon(Icons.edit_outlined, size: 16),
 ),
 IconButton(
 tooltip: 'Delete',
 onPressed: () => _removeAtCurrentTab(index),
 icon: const Icon(Icons.delete_outline, size: 16),
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
 ],
 const [4, 4, 2, 2, 3],
 );
 }),
 ],
 );
 }

 Widget _buildTableHeader(List<String> headers, List<int> flexes) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 borderRadius: const BorderRadius.only(
 topLeft: Radius.circular(8),
 topRight: Radius.circular(8),
 ),
 ),
 child: Row(
 children: List.generate(headers.length, (index) {
 return Expanded(
 flex: flexes[index],
 child: Text(
 headers[index],
 textAlign: TextAlign.center,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF374151),
 ),
 ),
 );
 }),
 ),
 );
 }

 Widget _buildTableRow(List<Widget> cells, List<int> flexes) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
 decoration: const BoxDecoration(
 border: Border(
 left: BorderSide(color: Color(0xFFE5E7EB)),
 right: BorderSide(color: Color(0xFFE5E7EB)),
 bottom: BorderSide(color: Color(0xFFE5E7EB)),
 ),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: List.generate(cells.length, (index) {
 return Expanded(
 flex: flexes[index],
 child: Padding(
 padding: const EdgeInsets.only(right: 6),
 child: cells[index],
 ),
 );
 }),
 ),
 );
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Planning Technology',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_technology_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

class _MetricCard extends StatelessWidget {
 const _MetricCard({
 required this.title,
 required this.value,
 required this.rows,
 });

 final String title;
 final String value;
 final List<_MetricRow> rows;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF1F2937),
 ),
 ),
 const SizedBox(height: 10),
 Text(
 value,
 style: const TextStyle(
 fontSize: 32,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 10),
 for (int i = 0; i < rows.length; i++) ...[
 Row(
 children: [
 Expanded(
 child: Text(
 rows[i].label,
 style:
 const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 ),
 Text(
 rows[i].value,
 style:
 const TextStyle(fontSize: 12, color: Color(0xFF374151)),
 ),
 ],
 ),
 if (i != rows.length - 1) const SizedBox(height: 4),
 ],
 ],
 ),
 );
 }
}

class _MetricRow {
 const _MetricRow({required this.label, required this.value});

 final String label;
 final String value;
}

class _StatusBadge extends StatelessWidget {
 const _StatusBadge({required this.label});

 final String label;

 @override
 Widget build(BuildContext context) {
 final normalized = label.toLowerCase();
 final color = normalized.contains('deployed')
 ? const Color(0xFF166534)
 : normalized.contains('implemented')
 ? const Color(0xFF1D4ED8)
 : normalized.contains('dismissed')
 ? const Color(0xFF991B1B)
 : const Color(0xFF92400E);

 final bg = Color.alphaBlend(color.withOpacity(0.12), Colors.white);
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: bg,
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 label,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: color,
 ),
 ),
 );
 }
}
