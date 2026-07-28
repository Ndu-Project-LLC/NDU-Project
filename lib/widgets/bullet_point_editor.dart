import 'package:flutter/material.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
class BulletPointEditor extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<String> items;
  final ValueChanged<List<String>> onChanged;
  final String hintText;
  final int maxItems;

  const BulletPointEditor({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
    required this.onChanged,
    this.hintText = 'Add an item...',
    this.maxItems = 10,
  });

  @override
  State<BulletPointEditor> createState() => _BulletPointEditorState();
}

class _BulletPointEditorState extends State<BulletPointEditor> {
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = widget.items
        .map((e) => TextEditingController(text: e))
        .toList();
    if (_controllers.isEmpty) {
      _controllers.add(TextEditingController());
    }
  }

  @override
  void didUpdateWidget(covariant BulletPointEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      // Only rebuild controllers if the external list has completely changed length or content mismatch
      // This is a naive check; ideally we trust the local controllers until saved.
      // For now, we assume parent state management.
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _updateParent() {
    final values = _controllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    widget.onChanged(values);
  }

  void _addItem() {
    if (_controllers.length >= widget.maxItems) return;
    setState(() {
      _controllers.add(TextEditingController());
    });
  }

  void _removeItem(int index) {
    if (_controllers.length <= 1) {
      _controllers[0].clear();
      _updateParent();
      return;
    }
    setState(() {
      _controllers[index].dispose();
      _controllers.removeAt(index);
    });
    _updateParent();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title.isNotEmpty) ...[
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.subtitle!,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _controllers.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 14, right: 8),
                  child: Icon(Icons.circle, size: 6, color: Color(0xFF94A3B8)),
                ),
                Expanded(
                  child: VoiceTextField(
                    controller: _controllers[index],
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    onChanged: (_) => _updateParent(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _removeItem(index),
                  icon: const Icon(Icons.close,
                      size: 20, color: Color(0xFF94A3B8)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            );
          },
        ),
        if (_controllers.length < widget.maxItems)
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 4),
            child: TextButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add item'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }
}
