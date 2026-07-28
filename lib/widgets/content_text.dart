import 'package:flutter/material.dart';
import 'package:ndu_project/providers/app_content_provider.dart';
import 'package:ndu_project/models/app_content_model.dart';
import 'package:ndu_project/services/app_content_service.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:provider/provider.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
/// Widget that displays content from Firestore with real-time updates
/// Usage:
/// ```dart
/// ContentText(
///   contentKey: 'welcome_message',
///   fallback: 'Welcome to the app',
///   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
/// )
/// ```
class ContentText extends StatelessWidget {
  const ContentText({
    super.key,
    required this.contentKey,
    this.fallback = '',
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String contentKey;
  final String fallback;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    // Use Selector to only rebuild when this specific content key changes
    return Selector<AppContentProvider, String>(
      selector: (_, provider) => provider.getDisplayContent(contentKey, fallback: fallback),
      builder: (_, content, __) => Text(
        content,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}

/// Widget builder that provides access to content values
/// Usage:
/// ```dart
/// ContentBuilder(
///   builder: (context, getContent) {
///     return Text(getContent('my_key', fallback: 'Default'));
///   },
/// )
/// ```
class ContentBuilder extends StatelessWidget {
  const ContentBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, String Function(String key, {String fallback}) getContent) builder;

  @override
  Widget build(BuildContext context) {
    final contentProvider = Provider.of<AppContentProvider>(context);
    return builder(context, contentProvider.getDisplayContent);
  }
}

/// Editable version of ContentText that can be clicked in edit mode
/// Usage:
/// ```dart
/// EditableContentText(
///   contentKey: 'welcome_message',
///   fallback: 'Welcome to the app',
///   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
/// )
/// ```
class EditableContentText extends StatelessWidget {
  const EditableContentText({
    super.key,
    required this.contentKey,
    this.fallback = '',
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.category = 'general',
  });

  final String contentKey;
  final String fallback;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final String category;

  @override
  Widget build(BuildContext context) {
    // Use Selector to only rebuild when edit mode or content changes
    return Selector<AppContentProvider, ({bool isEditMode, bool isStaticEditMode, String content})>(
      selector: (_, provider) => (
        isEditMode: provider.isEditMode,
        isStaticEditMode: provider.isStaticEditMode,
        content: provider.getDisplayContent(contentKey, fallback: fallback),
      ),
      builder: (context, data, _) => _buildContent(context, data.isEditMode || data.isStaticEditMode, data.isStaticEditMode, data.content),
    );
  }

  Widget _buildContent(BuildContext context, bool isEditMode, bool isStaticEditMode, String content) {
    final canEdit = AdminEditToggle.isAdmin();

    if (!isEditMode || !canEdit) {
      return Text(
        content,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    // In edit mode, make it clickable with visual indicator
    final accent = isStaticEditMode ? const Color(0xFFB45309) : Colors.blue;
    return InkWell(
      onTap: () => _showEditDialog(context, isStaticEditMode: isStaticEditMode),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: accent.withOpacity(0.3), width: 1),
          borderRadius: BorderRadius.circular(4),
          color: accent.withOpacity(0.05),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                content,
                style: style,
                textAlign: textAlign,
                maxLines: maxLines,
                overflow: overflow,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit, size: 14, color: accent.withOpacity(0.7)),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, {required bool isStaticEditMode}) {
    final provider = context.read<AppContentProvider>();
    showDialog(
      context: context,
      builder: (ctx) => _ContentEditDialog(
        contentKey: contentKey,
        currentValue: provider.getDisplayContent(contentKey, fallback: fallback),
        fallback: fallback,
        category: category,
        provider: provider,
        isStaticEditMode: isStaticEditMode,
        hasLocalOverride: provider.hasLocalOverride(contentKey),
      ),
    );
  }
}

/// Dialog for editing content
class _ContentEditDialog extends StatefulWidget {
  const _ContentEditDialog({
    required this.contentKey,
    required this.currentValue,
    required this.fallback,
    required this.category,
    required this.provider,
    required this.isStaticEditMode,
    required this.hasLocalOverride,
  });

  final String contentKey;
  final String currentValue;
  final String fallback;
  final String category;
  final AppContentProvider provider;
  final bool isStaticEditMode;
  final bool hasLocalOverride;

  @override
  State<_ContentEditDialog> createState() => _ContentEditDialogState();
}

class _ContentEditDialogState extends State<_ContentEditDialog> {
  late final TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isStaticEditMode ? 'Edit Static Content' : 'Edit Content'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Key: ${widget.contentKey}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 8),
            Text('Category: ${widget.category}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            if (widget.isStaticEditMode) ...[
              const SizedBox(height: 8),
              const Text(
                'Static edits are stored locally on this device and do not sync to the backend.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            VoiceTextField(
              controller: _controller,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Content Value',
                border: OutlineInputBorder(),
                helperText: 'Edit the text that will be displayed',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (widget.isStaticEditMode && widget.hasLocalOverride)
          TextButton(
            onPressed: _isSaving ? null : _resetOverride,
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Reset'),
          ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveContent,
          child: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _saveContent() async {
    final newValue = _controller.text.trim();
    if (newValue.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Content cannot be empty')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (widget.isStaticEditMode) {
        await widget.provider.saveStaticOverride(widget.contentKey, newValue);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Static content updated on this device')),
          );
        }
        return;
      }

      // Check if content exists in Firestore
      final existingId = await _findContentId(widget.contentKey);

      if (existingId != null) {
        // Update existing
        final success = await widget.provider.updateContent(
          existingId,
          AppContent(
            id: existingId,
            key: widget.contentKey,
            value: newValue,
            category: widget.category,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        if (success && mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Content updated successfully')),
          );
        }
      } else {
        // Create new
        final id = await widget.provider.addContent(
          AppContent(
            id: '',
            key: widget.contentKey,
            value: newValue,
            category: widget.category,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        if (id != null && mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Content created successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving content: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _resetOverride() async {
    setState(() => _isSaving = true);
    try {
      await widget.provider.removeStaticOverride(widget.contentKey);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Static override removed')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<String?> _findContentId(String key) async {
    try {
      final content = await AppContentService.getAllContent();
      final match = content.where((c) => c.key == key).firstOrNull;
      return match?.id;
    } catch (e) {
      return null;
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
