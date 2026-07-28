 import 'package:flutter/material.dart';
 import 'package:flutter/services.dart';
 import 'package:ndu_project/services/api_key_manager.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
class ApiKeyInputDialog extends StatefulWidget {
  const ApiKeyInputDialog({super.key});

  @override
  State<ApiKeyInputDialog> createState() => _ApiKeyInputDialogState();
}

class _ApiKeyInputDialogState extends State<ApiKeyInputDialog> {
  final TextEditingController _apiKeyController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isObscured = true;
  bool _isLoading = false;
  bool _isPlaceholder = false;

  static const String _placeholderMask = '••••••••••••••••';

  @override
  void initState() {
    super.initState();
    // If a key is already configured, show a masked placeholder
    // and allow users to paste over it directly.
    if (ApiKeyManager.isConfigured) {
      _apiKeyController.text = _placeholderMask;
      _isPlaceholder = true;
      // Select all so the next paste/typing replaces the whole value.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _apiKeyController.selection = TextSelection(baseOffset: 0, extentOffset: _apiKeyController.text.length);
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.security, color: Colors.blue),
          SizedBox(width: 8),
          Text('Configure OpenAI API Key'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To enable AI-powered solution generation, please enter your OpenAI API key:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            VoiceTextField(
              controller: _apiKeyController,
              focusNode: _focusNode,
              obscureText: _isObscured,
              enableSuggestions: false,
              autocorrect: false,
              keyboardType: TextInputType.visiblePassword,
              onTap: () {
                // If showing placeholder, keep text selected for quick paste-over.
                if (_isPlaceholder) {
                  _apiKeyController.selection = TextSelection(baseOffset: 0, extentOffset: _apiKeyController.text.length);
                }
              },
              onChanged: (_) {
                // Once user starts editing, it's no longer a placeholder.
                if (_isPlaceholder && _apiKeyController.text != _placeholderMask) {
                  setState(() => _isPlaceholder = false);
                }
              },
              decoration: InputDecoration(
                labelText: 'OpenAI API Key',
                hintText: 'sk-proj-...',
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: _isObscured ? 'Show' : 'Hide',
                      icon: Icon(_isObscured ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _isObscured = !_isObscured),
                    ),
                    IconButton(
                      tooltip: 'Paste',
                      icon: const Icon(Icons.content_paste),
                      onPressed: () async {
                        try {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          final text = (data?.text ?? '').trim();
                          if (text.isNotEmpty) {
                            setState(() {
                              _apiKeyController.text = text;
                              _apiKeyController.selection = TextSelection.collapsed(offset: text.length);
                              _isPlaceholder = false;
                            });
                          }
                        } catch (_) {}
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('How to get your API key:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text('1. Go to platform.openai.com'),
                  Text('2. Sign in to your account'),
                  Text('3. Navigate to API Keys section'),
                  Text('4. Create a new API key'),
                  Text('5. Copy and paste it here'),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Skip'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveApiKey,
          child: _isLoading 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save & Continue'),
        ),
      ],
    );
  }

  Future<void> _saveApiKey() async {
    final apiKey = _apiKeyController.text.trim();
    
    // If still showing placeholder or empty, prompt for a real key
    if (apiKey.isEmpty || apiKey == _placeholderMask) {
      _showError('Please enter an API key');
      return;
    }

    if (!apiKey.startsWith('sk-')) {
      _showError('API key should start with "sk-"');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiKeyManager.persistForCurrentUser(apiKey);
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API key saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _showError('Failed to save API key: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}