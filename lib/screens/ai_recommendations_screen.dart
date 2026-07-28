import 'package:flutter/material.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/utils/text_sanitizer.dart';
import 'package:ndu_project/widgets/page_regenerate_all_button.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
class AiRecommendationsScreen extends StatefulWidget {
 const AiRecommendationsScreen({super.key});
 static void open(BuildContext context) =>
 Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiRecommendationsScreen()));

 @override
 State<AiRecommendationsScreen> createState() => _AiRecommendationsScreenState();
}

class _AiRecommendationsScreenState extends State<AiRecommendationsScreen> {
 final List<Map<String, dynamic>> _items = [];
 bool _loading = true;
 bool _generating = false;

 @override
 void initState() {
 super.initState();
 ApiKeyManager.initializeApiKey();
 WidgetsBinding.instance.addPostFrameCallback((_) => _load());
 }

 void _load() {
 final p = ProjectDataInherited.maybeOf(context);
 if (p == null) return setState(() => _loading = false);
 setState(() {
 _items..clear()..addAll(p.projectData.aiRecommendations);
 });
 }

 Future<void> _save() async {
 final p = ProjectDataInherited.maybeOf(context);
 if (p == null) return;
 p.updateField((d) => d.copyWith(aiRecommendations: _items));
 await p.saveToFirebase(checkpoint: 'ai_recommendations');
 }

 Future<void> _regenerateAllRecommendations() async {
 await _generate();
 }

 Future<void> _generate() async {
 final p = ProjectDataInherited.maybeOf(context);
 if (p == null) return;
 if (_generating) return;
 setState(() => _generating = true);
 
 // Track field history before regenerating
 for (int i = 0; i < _items.length; i++) {
 final recommendation = _items[i]['recommendation']?.toString() ?? '';
 if (recommendation.isNotEmpty) {
 p.addFieldToHistory(
 'ai_recommendation_$i',
 recommendation,
 isAiGenerated: true,
 );
 }
 }
 
 final ai = OpenAiServiceSecure();
 final ctx = '${p.projectData.projectName}\n${p.projectData.solutionTitle}\n${p.projectData.projectObjective}';
 try {
 final text = await ai.generateFepSectionText(section: 'AI Recommendations', context: ctx, maxTokens: 800);
 final sanitized = TextSanitizer.sanitizeAiText(text);
 final lines = sanitized.split('\n').where((l) => l.trim().isNotEmpty).toList();
 
 // Track new AI-generated content
 for (int i = 0; i < lines.length; i++) {
 final recommendation = lines[i].trim();
 if (recommendation.isNotEmpty) {
 p.addFieldToHistory(
 'ai_recommendation_$i',
 recommendation,
 isAiGenerated: true,
 );
 }
 }
 
 setState(() => _items..clear()..addAll(lines.map((l) => {'recommendation': l.trim()})));
 await _save();
 } catch (e) {
 debugPrint('AI gen failed: $e');
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Regenerate failed: ${e.toString()}')),
 );
 }
 } finally {
 if (mounted) setState(() => _generating = false);
 }
 }


 void _openAdd() {
 final t = TextEditingController();
 final navigator = Navigator.of(context);
 showDialog(
 context: context,
 builder: (c) => AlertDialog(
 title: const Text('Add recommendation'),
 content: VoiceTextField(controller: t, decoration: const InputDecoration(labelText: 'Recommendation')),
 actions: [
 TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Cancel')),
 ElevatedButton(
 onPressed: () async {
 setState(() => _items.add({'recommendation': t.text.trim()}));
 await _save();
 if (!mounted) return;
 navigator.pop();
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
 activeItemLabel: 'AI Recommendations',
 appBarTitle: 'AI Recommendations',
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: Padding(
 padding: const EdgeInsets.all(20),
 child: _loading
 ? const Center(child: CircularProgressIndicator())
 : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
 if (!isMobile)
 Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
 const Expanded(
 child: Text('AI Recommendations', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
 ),
 PageRegenerateAllButton(
 onRegenerateAll: () async {
 final confirmed = await showRegenerateAllConfirmation(context);
 if (confirmed && mounted) {
 await _regenerateAllRecommendations();
 }
 },
 isLoading: _generating,
 tooltip: 'Regenerate all AI recommendations',
 ),
 const SizedBox(width: 8),
 ElevatedButton(onPressed: _openAdd, child: const Text('Add')),
 ]),
 if (isMobile)
 Row(mainAxisAlignment: MainAxisAlignment.end, children: [
 PageRegenerateAllButton(
 onRegenerateAll: () async {
 final confirmed = await showRegenerateAllConfirmation(context);
 if (confirmed && mounted) {
 await _regenerateAllRecommendations();
 }
 },
 isLoading: _generating,
 tooltip: 'Regenerate all AI recommendations',
 ),
 const SizedBox(width: 8),
 ElevatedButton(onPressed: _openAdd, child: const Text('Add')),
 ]),
 const SizedBox(height: 12),
 Expanded(
 child: Card(
 child: Padding(
 padding: const EdgeInsets.all(12),
 child: ListView.builder(
 itemCount: _items.length,
 itemBuilder: (context, index) {
 final item = _items[index];
 return ListTile(title: Text(item['recommendation'] ?? ''));
 },
 ),
 ),
 ),
 ),
 ]),
 ),
 );
 }
}
