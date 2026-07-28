import 'package:flutter/material.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/utils/text_sanitizer.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/ai_regenerate_undo_buttons.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
class ExternalIntegrationsScreen extends StatefulWidget {
 const ExternalIntegrationsScreen({super.key});
 static void open(BuildContext context) => Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const ExternalIntegrationsScreen()));

 @override
 State<ExternalIntegrationsScreen> createState() =>
 _ExternalIntegrationsScreenState();
}

class _ExternalIntegrationsScreenState
 extends State<ExternalIntegrationsScreen> {
 final List<Map<String, dynamic>> _items = [];
 bool _loading = true;
 bool _seeding = false;
 List<Map<String, dynamic>>? _undoBeforeAi;
 List<Map<String, dynamic>>? _redoAfterUndo;

 @override
 void initState() {
 super.initState();
 ApiKeyManager.initializeApiKey();
 WidgetsBinding.instance.addPostFrameCallback((_) => _load());
 }

 void _load() {
 final provider = ProjectDataInherited.maybeOf(context);
 if (provider == null) return setState(() => _loading = false);
 setState(() {
 _items
 ..clear()
 ..addAll(provider.projectData.externalIntegrations);
 _loading = false;
 });
 }

 Future<void> _save() async {
 final provider = ProjectDataInherited.maybeOf(context);
 if (provider == null) return;
 provider.updateField((d) => d.copyWith(externalIntegrations: _items));
 await provider.saveToFirebase(checkpoint: 'external_integrations');
 }

 Future<void> _seed() async {
 final provider = ProjectDataInherited.maybeOf(context);
 if (provider == null) return;
 if (_seeding) return;
 setState(() => _seeding = true);
 _undoBeforeAi = _items.map((e) => Map<String, dynamic>.from(e)).toList();
 _redoAfterUndo = null;
 final ai = OpenAiServiceSecure();
 final ctx =
 '${provider.projectData.projectName} - ${provider.projectData.solutionTitle}';
 try {
 final text = await ai.generateFepSectionText(
 section: 'External Integrations', context: ctx, maxTokens: 600);
 final sanitized = TextSanitizer.sanitizeAiText(text);
 final lines =
 sanitized.split('\n').where((l) => l.trim().isNotEmpty).toList();
 setState(() => _items
 ..clear()
 ..addAll(lines.map((l) => {'name': l.trim()})));
 await _save();
 } catch (e) {
 debugPrint('AI seed failed: $e');
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Regenerate failed: ${e.toString()}')),
 );
 }
 } finally {
 if (mounted) setState(() => _seeding = false);
 }
 }

 Future<void> _undoSeed() async {
 final prev = _undoBeforeAi;
 if (prev == null) return;
 final current = _items.map((e) => Map<String, dynamic>.from(e)).toList();
 setState(() {
 _items
 ..clear()
 ..addAll(prev.map((e) => Map<String, dynamic>.from(e)));
 _undoBeforeAi = null;
 _redoAfterUndo = current;
 });
 await _save();
 }

 Future<void> _redoSeed() async {
 final redo = _redoAfterUndo;
 if (redo == null) return;
 final current = _items.map((e) => Map<String, dynamic>.from(e)).toList();
 setState(() {
 _items
 ..clear()
 ..addAll(redo.map((e) => Map<String, dynamic>.from(e)));
 _undoBeforeAi = current;
 _redoAfterUndo = null;
 });
 await _save();
 }

 void _openAdd() {
 final name = TextEditingController();
 showDialog(
 context: context,
 builder: (c) => AlertDialog(
 title: const Text('Add integration'),
 content: VoiceTextField(
 controller: name,
 decoration: const InputDecoration(labelText: 'Name')),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(c).pop(),
 child: const Text('Cancel')),
 ElevatedButton(
 onPressed: () async {
 final nav = Navigator.of(c);
 setState(() => _items.add({'name': name.text.trim()}));
 await _save();
 if (!mounted) return;
 nav.pop();
 },
 child: const Text('Add'),
 ),
 ],
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 return ResponsiveScaffold(
 activeItemLabel: 'External Integrations',
 appBarTitle: 'External Integrations',
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: Padding(
 padding: const EdgeInsets.all(20),
 child: _loading
 ? const Center(child: CircularProgressIndicator())
 : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
 if (!isMobile)
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 const Text('External Integrations',
 style: TextStyle(
 fontSize: 20, fontWeight: FontWeight.w700)),
 Row(children: [
 AiRegenerateUndoButtons(
 isLoading: _seeding,
 canUndo: _undoBeforeAi != null,
 canRedo: _redoAfterUndo != null,
 onRegenerate: _seed,
 onUndo: () {
 _undoSeed();
 },
 onRedo: () {
 _redoSeed();
 },
 ),
 const SizedBox(width: 8),
 ElevatedButton(
 onPressed: _openAdd, child: const Text('Add')),
 ])
 ]),
 if (isMobile)
 Row(mainAxisAlignment: MainAxisAlignment.end, children: [
 AiRegenerateUndoButtons(
 isLoading: _seeding,
 canUndo: _undoBeforeAi != null,
 canRedo: _redoAfterUndo != null,
 onRegenerate: _seed,
 onUndo: () { _undoSeed(); },
 onRedo: () { _redoSeed(); },
 ),
 const SizedBox(width: 8),
 ElevatedButton(onPressed: _openAdd, child: const Text('Add')),
 ]),
 const SizedBox(height: 12),
 Expanded(
 child: Card(
 child: Padding(
 padding: const EdgeInsets.all(12),
 child: ListView(
 children: _items
 .map((it) => ListTile(
 title: Text(it['name'] ?? ''),
 subtitle: Text(it['notes'] ?? '')))
 .toList(),
 ),
 ),
 ),
 ),
 ]),
 ),
 );
 }
}
