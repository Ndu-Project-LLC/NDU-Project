import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ndu_project/services/activity_log_service.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/rich_text_editing_controller.dart';
import 'package:ndu_project/utils/text_sanitizer.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
class PlanningAiNotesCard extends StatefulWidget {
  const PlanningAiNotesCard({
    super.key,
    required this.title,
    required this.sectionLabel,
    required this.noteKey,
    required this.checkpoint,
    this.description,
    this.fieldKey,
    this.errorText,
    this.onChanged,
    this.fallbackText,
    this.hintText = 'Capture the key decisions and details for this section...',
    this.autoGenerateMaxTokens = 900,
    this.autoGenerateTemperature = 0.5,
  });

  final String title;
  final String sectionLabel;
  final String noteKey;
  final String checkpoint;
  final String? description;
  final Key? fieldKey;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final String? fallbackText;
  final String hintText;
  final int autoGenerateMaxTokens;
  final double autoGenerateTemperature;

  @override
  State<PlanningAiNotesCard> createState() => _PlanningAiNotesCardState();
}

class _PlanningAiNotesCardState extends State<PlanningAiNotesCard> {
  final _saveDebounce = _Debouncer();
  String _currentText = '';
  late TextEditingController _controller;
  bool _didInit = false;
  bool _saving = false;
  DateTime? _lastSavedAt;
  String? _undoBeforeAi;
  bool _generating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    ApiKeyManager.initializeApiKey();
    final data = ProjectDataHelper.getData(context);
    final stored = data.planningNotes[widget.noteKey] ?? '';
    final fallback = widget.fallbackText ?? '';
    _currentText = stored.trim().isNotEmpty ? stored.trim() : fallback.trim();
    _controller = RichTextEditingController(text: _currentText);
    _didInit = true;
  }

  @override
  void dispose() {
    _saveDebounce.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    final trimmed = value.trim();
    _currentText = trimmed;
    final provider = ProjectDataHelper.getProvider(context);
    provider.updateField(
      (data) => data.copyWith(
        planningNotes: {
          ...data.planningNotes,
          widget.noteKey: trimmed,
        },
      ),
    );
    widget.onChanged?.call(trimmed);
    // Keep controller in sync
    if (_controller.text != value) _controller.text = value;
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveDebounce.run(() async {
      if (!mounted) return;
      await _saveNow();
    });
  }

  Future<void> _regenerate() async {
    if (_generating) return;
    final data = ProjectDataHelper.getData(context);
    final section = widget.sectionLabel.trim();
    final sectionLower = section.toLowerCase();
    final useExecutiveContext = sectionLower.contains('executive') ||
        sectionLower.contains('execution');
    final contextText = useExecutiveContext
        ? ProjectDataHelper.buildExecutivePlanContext(data,
            sectionLabel: section)
        : ProjectDataHelper.buildFepContext(data, sectionLabel: section);
    if (contextText.trim().isEmpty) return;

    setState(() => _generating = true);
    _undoBeforeAi = _controller.text;
    try {
      final ai = OpenAiServiceSecure();
      final text = await ai.generateFepSectionText(
        section: section,
        context: contextText,
        maxTokens: widget.autoGenerateMaxTokens,
        temperature: widget.autoGenerateTemperature,
      );
      if (!mounted) return;
      final cleaned = TextSanitizer.sanitizeAiRichText(text).trim();
      if (cleaned.isEmpty) return;
      _controller.text = cleaned;
      _handleChanged(cleaned);
      await _saveNow();
      final projectId = data.projectId?.trim() ?? '';
      if (projectId.isNotEmpty) {
        await ActivityLogService.instance.logCheckpointActivity(
          projectId: projectId,
          checkpoint: widget.checkpoint,
          action: 'Generated AI content',
          details: {
            'page': widget.sectionLabel,
            'noteKey': widget.noteKey,
          },
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Regenerate failed: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _undo() {
    final prev = _undoBeforeAi;
    if (prev == null) return;
    _undoBeforeAi = null;
    _controller.text = prev;
    _handleChanged(prev);
    _saveNow();
  }

  Future<void> _saveNow() async {
    if (_saving) return;
    setState(() => _saving = true);
    final success = await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: widget.checkpoint,
      showSnackbar: false,
      dataUpdater: (data) => data.copyWith(
        planningNotes: {
          ...data.planningNotes,
          widget.noteKey: _currentText.trim(),
        },
      ),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (success) {
        _lastSavedAt = DateTime.now();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final savedAt = _lastSavedAt;
    final hasError = (widget.errorText ?? '').trim().isNotEmpty;
    final borderColor =
        hasError ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB);
    return Container(
      key: widget.fieldKey,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 18, offset: Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4CC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Color(0xFFF59E0B), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827)),
                ),
              ),
              IconButton(
                tooltip: 'Regenerate (AI)',
                onPressed: _generating ? null : _regenerate,
                icon: _generating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh,
                        size: 18, color: Color(0xFFD97706)),
              ),
              IconButton(
                tooltip: 'Undo last AI regenerate',
                onPressed: _undoBeforeAi == null ? null : _undo,
                icon:
                    const Icon(Icons.undo, size: 18, color: Color(0xFF6B7280)),
              ),
              if (_saving)
                _StatusChip(label: 'Saving...', color: const Color(0xFF64748B))
              else if (savedAt != null)
                _StatusChip(
                  label:
                      'Saved ${TimeOfDay.fromDateTime(savedAt).format(context)}',
                  color: const Color(0xFF16A34A),
                  background: const Color(0xFFECFDF3),
                ),
            ],
          ),
          if ((widget.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              widget.description!,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
            ),
          ],
          const SizedBox(height: 16),
          VoiceTextField(
            controller: _controller,
            onChanged: _handleChanged,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: widget.hintText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: hasError
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFFFD700),
                  width: 1.6,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            ),
            style: const TextStyle(fontSize: 14),
          ),
          if (hasError) ...[
            const SizedBox(height: 6),
            Text(
              widget.errorText!,
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(
      {required this.label, required this.color, this.background});

  final String label;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _Debouncer {
  _Debouncer({Duration? delay})
      : delay = delay ?? const Duration(milliseconds: 700);

  final Duration delay;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
