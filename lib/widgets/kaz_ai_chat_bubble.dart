import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:ndu_project/openai/openai_config.dart';
import 'package:ndu_project/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// KAZ AI Chat Bubble — World-Class AI + Support Agent Interface
// Features:
//   • Persistent conversation history (Firestore + local cache)
//   • Multi-turn AI context with full conversation history
//   • Support agent chat tab with ticket creation
//   • Tabbed UI: AI Assistant | Support Agent
//   • Message grouping by date, timestamps, avatars, typing indicators
//   • Clear history, search, and conversation management
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class KazAiChatBubble extends StatelessWidget {
  const KazAiChatBubble({super.key, this.positioned = true});

  final bool positioned;

  /// Public static method to open the KAZ AI chat dialog from anywhere.
  static void openChat(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.15),
      barrierDismissible: true,
      barrierLabel: 'Close chat',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) =>
          const _KazAiChatPopup(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.15, 0.15),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bubble = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => openChat(context),
        borderRadius: BorderRadius.circular(32),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFC812),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFC812).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.chat_bubble_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );

    if (!positioned) return bubble;

    return Positioned(
      bottom: 90,
      right: 24,
      child: bubble,
    );
  }

  void _openKazAiChat(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.15),
      barrierDismissible: true,
      barrierLabel: 'Close chat',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) =>
          const _KazAiChatPopup(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.15, 0.15),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Chat Message Model — serializable for Firestore + local cache
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

enum _MessageSource { ai, user, supportAgent, system }

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.source,
    required this.timestamp,
    this.id = '',
    this.isRead = true,
  });

  final String id;
  final String text;
  final _MessageSource source;
  final DateTime timestamp;
  final bool isRead;

  bool get isUser => source == _MessageSource.user;
  bool get isAi => source == _MessageSource.ai;
  bool get isSupportAgent => source == _MessageSource.supportAgent;
  bool get isSystem => source == _MessageSource.system;

  String get sourceKey {
    switch (source) {
      case _MessageSource.user: return 'user';
      case _MessageSource.ai: return 'ai';
      case _MessageSource.supportAgent: return 'support_agent';
      case _MessageSource.system: return 'system';
    }
  }

  static _MessageSource sourceFromKey(String key) {
    switch (key) {
      case 'user': return _MessageSource.user;
      case 'ai': return _MessageSource.ai;
      case 'support_agent': return _MessageSource.supportAgent;
      case 'system': return _MessageSource.system;
      default: return _MessageSource.system;
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id.isNotEmpty ? id : timestamp.millisecondsSinceEpoch.toString(),
    'text': text,
    'source': sourceKey,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
  };

  static _ChatMessage fromMap(Map<String, dynamic> map) => _ChatMessage(
    id: map['id']?.toString() ?? '',
    text: map['text']?.toString() ?? '',
    source: sourceFromKey(map['source']?.toString() ?? 'system'),
    timestamp: map['timestamp'] is Timestamp
        ? (map['timestamp'] as Timestamp).toDate()
        : DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
    isRead: map['isRead'] == true,
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Support Ticket Model
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _SupportTicket {
  const _SupportTicket({
    required this.id,
    required this.subject,
    required this.status,
    required this.createdAt,
    this.agentName = '',
    this.lastMessage = '',
  });

  final String id;
  final String subject;
  final String status;
  final DateTime createdAt;
  final String agentName;
  final String lastMessage;

  Map<String, dynamic> toMap() => {
    'id': id,
    'subject': subject,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'agentName': agentName,
    'lastMessage': lastMessage,
  };

  static _SupportTicket fromMap(Map<String, dynamic> map) => _SupportTicket(
    id: map['id']?.toString() ?? '',
    subject: map['subject']?.toString() ?? '',
    status: map['status']?.toString() ?? 'open',
    createdAt: map['createdAt'] is Timestamp
        ? (map['createdAt'] as Timestamp).toDate()
        : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    agentName: map['agentName']?.toString() ?? '',
    lastMessage: map['lastMessage']?.toString() ?? '',
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Chat Persistence Service — Firestore + SharedPreferences cache
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _ChatPersistence {
  static const _aiCacheKey = 'kaz_ai_chat_cache';
  static const _supportCacheKey = 'kaz_support_chat_cache';
  static const _maxCacheMessages = 200;

  static String? _userId() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  static DocumentReference<Map<String, dynamic>> _docRef() {
    final uid = _userId() ?? 'anonymous';
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('kaz_chat')
        .doc('history');
  }

  // ── Save AI messages ──────────────────────────────────────────────────
  static Future<void> saveAiMessages(List<_ChatMessage> messages) async {
    // Save to local cache immediately
    await _saveToLocal(_aiCacheKey, messages);
    // Save to Firestore in background
    try {
      final trimmed = messages.length > _maxCacheMessages
          ? messages.sublist(messages.length - _maxCacheMessages)
          : messages;
      await _docRef().set({
        'aiMessages': trimmed.map((m) => m.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('KAZ AI Firestore save error: $e');
    }
  }

  // ── Save Support messages ─────────────────────────────────────────────
  static Future<void> saveSupportMessages(List<_ChatMessage> messages) async {
    await _saveToLocal(_supportCacheKey, messages);
    try {
      final trimmed = messages.length > _maxCacheMessages
          ? messages.sublist(messages.length - _maxCacheMessages)
          : messages;
      await _docRef().set({
        'supportMessages': trimmed.map((m) => m.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('KAZ Support Firestore save error: $e');
    }
  }

  // ── Load AI messages ──────────────────────────────────────────────────
  static Future<List<_ChatMessage>> loadAiMessages() async {
    // Try Firestore first, fall back to local cache
    try {
      final doc = await _docRef().get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final list = data['aiMessages'];
        if (list is List && list.isNotEmpty) {
          final messages = list
              .whereType<Map>()
              .map((e) => _ChatMessage.fromMap(Map<String, dynamic>.from(e)))
              .toList();
          // Update local cache
          await _saveToLocal(_aiCacheKey, messages);
          return messages;
        }
      }
    } catch (e) {
      debugPrint('KAZ AI Firestore load error: $e');
    }
    // Fall back to local cache
    return _loadFromLocal(_aiCacheKey);
  }

  // ── Load Support messages ─────────────────────────────────────────────
  static Future<List<_ChatMessage>> loadSupportMessages() async {
    try {
      final doc = await _docRef().get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final list = data['supportMessages'];
        if (list is List && list.isNotEmpty) {
          final messages = list
              .whereType<Map>()
              .map((e) => _ChatMessage.fromMap(Map<String, dynamic>.from(e)))
              .toList();
          await _saveToLocal(_supportCacheKey, messages);
          return messages;
        }
      }
    } catch (e) {
      debugPrint('KAZ Support Firestore load error: $e');
    }
    return _loadFromLocal(_supportCacheKey);
  }

  // ── Clear history ─────────────────────────────────────────────────────
  static Future<void> clearAiHistory() async {
    await _clearLocal(_aiCacheKey);
    try {
      await _docRef().set({
        'aiMessages': [],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> clearSupportHistory() async {
    await _clearLocal(_supportCacheKey);
    try {
      await _docRef().set({
        'supportMessages': [],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Local cache helpers ───────────────────────────────────────────────
  static Future<void> _saveToLocal(String key, List<_ChatMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trimmed = messages.length > _maxCacheMessages
          ? messages.sublist(messages.length - _maxCacheMessages)
          : messages;
      final json = jsonEncode(trimmed.map((m) => m.toMap()).toList());
      await prefs.setString(key, json);
    } catch (e) {
      debugPrint('KAZ AI local cache save error: $e');
    }
  }

  static Future<List<_ChatMessage>> _loadFromLocal(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map>()
          .map((e) => _ChatMessage.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('KAZ AI local cache load error: $e');
      return [];
    }
  }

  static Future<void> _clearLocal(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Main Chat Popup — Tabbed interface: AI Assistant | Support
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _KazAiChatPopup extends StatefulWidget {
  const _KazAiChatPopup();

  @override
  State<_KazAiChatPopup> createState() => _KazAiChatPopupState();
}

class _KazAiChatPopupState extends State<_KazAiChatPopup>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _aiInputController = TextEditingController();
  final ScrollController _aiScrollController = ScrollController();
  final ScrollController _supportScrollController = ScrollController();
  final TextEditingController _supportInputController = TextEditingController();

  List<_ChatMessage> _aiMessages = [];
  List<_ChatMessage> _supportMessages = [];
  bool _isAiLoading = false;
  bool _isSupportLoading = false;
  bool _isHistoryLoading = true;
  int _activeTab = 0;

  // Support ticket state
  final _ticketSubjectController = TextEditingController();
  final _ticketDescController = TextEditingController();
  bool _showTicketForm = true;
  _SupportTicket? _activeTicket;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() => _activeTab = _tabController.index);
    });
    _loadChatHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _aiInputController.dispose();
    _aiScrollController.dispose();
    _supportScrollController.dispose();
    _supportInputController.dispose();
    _ticketSubjectController.dispose();
    _ticketDescController.dispose();
    super.dispose();
  }

  // ── Load persisted history ────────────────────────────────────────────
  Future<void> _loadChatHistory() async {
    final aiHistory = await _ChatPersistence.loadAiMessages();
    final supportHistory = await _ChatPersistence.loadSupportMessages();

    if (!mounted) return;
    setState(() {
      _aiMessages = aiHistory;
      _supportMessages = supportHistory;
      _isHistoryLoading = false;
    });

    // If AI chat is empty, seed welcome message
    if (_aiMessages.isEmpty) {
      _addAiMessage(_ChatMessage(
        text: 'Hi! I\'m **KAZ AI**, your intelligent project management assistant. I remember our conversations and learn from context. How can I help you today?',
        source: _MessageSource.ai,
        timestamp: DateTime.now(),
      ));
    }

    // If support has history, show conversation (not ticket form)
    if (_supportMessages.isNotEmpty) {
      setState(() => _showTicketForm = false);
    }

    _scrollToBottom(_aiScrollController);
    _scrollToBottom(_supportScrollController);
  }

  // ── AI Chat ───────────────────────────────────────────────────────────
  void _addAiMessage(_ChatMessage message) {
    setState(() => _aiMessages.add(message));
    _ChatPersistence.saveAiMessages(_aiMessages);
  }

  Future<void> _sendAiMessage() async {
    final text = _aiInputController.text.trim();
    if (text.isEmpty || _isAiLoading) return;

    _aiInputController.clear();
    _addAiMessage(_ChatMessage(
      text: text,
      source: _MessageSource.user,
      timestamp: DateTime.now(),
    ));
    _scrollToBottom(_aiScrollController);

    setState(() => _isAiLoading = true);

    try {
      final response = await _getAiResponse(text);
      if (!mounted) return;
      setState(() => _isAiLoading = false);
      _addAiMessage(_ChatMessage(
        text: response,
        source: _MessageSource.ai,
        timestamp: DateTime.now(),
      ));
      _scrollToBottom(_aiScrollController);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAiLoading = false);
      _addAiMessage(_ChatMessage(
        text: 'I encountered an error processing your request. Please try again.',
        source: _MessageSource.system,
        timestamp: DateTime.now(),
      ));
      _scrollToBottom(_aiScrollController);
    }
  }

  /// Multi-turn AI response with full conversation history
  Future<String> _getAiResponse(String userMessage) async {
    if (!OpenAiConfig.isConfigured) {
      return "I'm connecting to the AI service. Please try again in a moment and I'll be ready to help.";
    }

    try {
      final uri = OpenAiConfig.chatUri();
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${OpenAiConfig.apiKeyValue}',
      };

      // Build full conversation history for multi-turn context
      final messages = <Map<String, String>>[
        {
          'role': 'system',
          'content': 'You are KAZ AI, a world-class project management assistant with deep expertise in '
              'construction, engineering, software delivery, and operations management. You provide concise, '
              'actionable advice enriched with industry best practices. You have access to the full conversation '
              'history and can reference previous discussions. Keep responses under 200 words. Use markdown '
              'formatting for clarity (bold, lists, code). When appropriate, suggest specific frameworks, '
              'methodologies, or metrics the user can apply.',
        },
      ];

      // Add conversation history (last 20 messages for context window efficiency)
      final historyStart = _aiMessages.length > 20 ? _aiMessages.length - 20 : 0;
      for (var i = historyStart; i < _aiMessages.length; i++) {
        final msg = _aiMessages[i];
        if (msg.isSystem) continue;
        messages.add({
          'role': msg.isUser ? 'user' : 'assistant',
          'content': msg.text,
        });
      }

      final body = jsonEncode(OpenAiConfig.wrapBody({
        'model': OpenAiConfig.model,
        'temperature': 0.7,
        'max_completion_tokens': 800,
        'messages': messages,
      }));

      final response = await http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 401) {
        return 'Invalid API key. Please check your OpenAI configuration in **Settings**.';
      }
      if (response.statusCode == 429) {
        return 'API quota exceeded. Please check your OpenAI billing or try again shortly.';
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return 'I encountered a server error (${response.statusCode}). Please try again.';
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      final content = (choices != null && choices.isNotEmpty)
          ? (choices.first['message']?['content'] as String?) ?? ''
          : '';
      return content.trim();
    } catch (e) {
      return 'I\'m having trouble connecting right now. Please try again in a moment.';
    }
  }

  // ── Support Chat ──────────────────────────────────────────────────────
  void _addSupportMessage(_ChatMessage message) {
    setState(() => _supportMessages.add(message));
    _ChatPersistence.saveSupportMessages(_supportMessages);
  }

  Future<void> _createSupportTicket() async {
    final subject = _ticketSubjectController.text.trim();
    final desc = _ticketDescController.text.trim();
    if (subject.isEmpty) return;

    final ticketId = 'TK-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';

    setState(() {
      _activeTicket = _SupportTicket(
        id: ticketId,
        subject: subject,
        status: 'open',
        createdAt: DateTime.now(),
        agentName: '',
        lastMessage: desc.isNotEmpty ? desc : subject,
      );
      _showTicketForm = false;
    });

    // System message
    _addSupportMessage(_ChatMessage(
      text: 'Support ticket **#$ticketId** created: "$subject"\n\nA support agent will be with you shortly. You can continue the conversation below.',
      source: _MessageSource.system,
      timestamp: DateTime.now(),
    ));

    // Save ticket to Firestore
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('support_tickets')
          .doc(ticketId)
          .set({
        ..._activeTicket!.toMap(),
        'messages': _supportMessages.map((m) => m.toMap()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Support ticket save error: $e');
    }

    _ticketSubjectController.clear();
    _ticketDescController.clear();
    _scrollToBottom(_supportScrollController);
  }

  Future<void> _sendSupportMessage() async {
    final text = _supportInputController.text.trim();
    if (text.isEmpty || _isSupportLoading) return;

    _supportInputController.clear();
    _addSupportMessage(_ChatMessage(
      text: text,
      source: _MessageSource.user,
      timestamp: DateTime.now(),
    ));
    _scrollToBottom(_supportScrollController);

    // Simulate support agent acknowledgment
    setState(() => _isSupportLoading = true);
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() => _isSupportLoading = false);

    _addSupportMessage(_ChatMessage(
      text: 'Thank you for your message. A support agent has been notified and will respond shortly. Your ticket is being reviewed.',
      source: _MessageSource.supportAgent,
      timestamp: DateTime.now(),
    ));

    // Update Firestore ticket
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      if (_activeTicket != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('support_tickets')
            .doc(_activeTicket!.id)
            .set({
          'messages': _supportMessages.map((m) => m.toMap()).toList(),
          'lastMessage': text,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Support message save error: $e');
    }

    _scrollToBottom(_supportScrollController);
  }

  // ── Clear history ─────────────────────────────────────────────────────
  void _clearAiHistory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear AI Chat History'),
        content: const Text('This will permanently delete all conversation history with KAZ AI. This action cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () {
              setState(() {
                _aiMessages.clear();
                _addAiMessage(_ChatMessage(
                  text: 'Hi! I\'m **KAZ AI**, your intelligent project management assistant. I remember our conversations and learn from context. How can I help you today?',
                  source: _MessageSource.ai,
                  timestamp: DateTime.now(),
                ));
              });
              _ChatPersistence.clearAiHistory();
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _clearSupportHistory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Support Chat History'),
        content: const Text('This will permanently delete all support chat history. This action cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () {
              setState(() {
                _supportMessages.clear();
                _showTicketForm = true;
                _activeTicket = null;
              });
              _ChatPersistence.clearSupportHistory();
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  // ── Scroll helpers ────────────────────────────────────────────────────
  void _scrollToBottom(ScrollController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients) {
        controller.animateTo(
          controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // BUILD — Main Chat Popup
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    final popupWidth = isSmallScreen ? screenSize.width * 0.96 : 420.0;
    final popupHeight = isSmallScreen ? screenSize.height * 0.82 : 580.0;

    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsets.only(
          right: isSmallScreen ? 8 : 24,
          bottom: isSmallScreen ? 16 : 166,
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: popupWidth,
            height: popupHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 48,
                  offset: const Offset(0, 16),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: const Color(0xFFFFC812).withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                children: [
                  _buildHeader(theme, scheme),
                  _buildTabBar(theme, scheme),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildAiChatTab(theme, scheme),
                        _buildSupportTab(theme, scheme),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────
  Widget _buildHeader(ThemeData theme, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFC812), Color(0xFFFF9800)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.25),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                ),
                child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KAZ AI',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4ADE80),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _activeTab == 0 ? 'AI Assistant Online' : 'Support Agent',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.history_rounded, color: Colors.white, size: 20),
                onPressed: _activeTab == 0 ? _clearAiHistory : _clearSupportHistory,
                tooltip: 'Clear history',
                splashRadius: 20,
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Close',
                iconSize: 22,
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────────────
  Widget _buildTabBar(ThemeData theme, ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: const Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFFFF9800),
        unselectedLabelColor: const Color(0xFF94A3B8),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        indicatorColor: const Color(0xFFFFC812),
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        dividerHeight: 0,
        tabs: [
          Tab(
            height: 40,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.psychology_rounded, size: 18),
                const SizedBox(width: 8),
                const Text('AI Assistant'),
              ],
            ),
          ),
          Tab(
            height: 40,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.support_agent_rounded, size: 18),
                const SizedBox(width: 8),
                const Text('Support'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // AI CHAT TAB
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildAiChatTab(ThemeData theme, ColorScheme scheme) {
    if (_isHistoryLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFFFC812)),
            ),
            SizedBox(height: 16),
            Text('Loading conversation history...', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Message list
        Expanded(
          child: ListView.builder(
            controller: _aiScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: _aiMessages.length,
            itemBuilder: (context, index) {
              final msg = _aiMessages[index];
              final showAvatar = index == 0 ||
                  _aiMessages[index - 1].source != msg.source;
              final showTimestamp = index == 0 ||
                  msg.timestamp.difference(_aiMessages[index - 1].timestamp).inMinutes > 5;

              return Column(
                children: [
                  if (showTimestamp)
                    _buildDateDivider(msg.timestamp, theme),
                  _ChatBubble(
                    message: msg,
                    scheme: scheme,
                    theme: theme,
                    showAvatar: showAvatar,
                  ),
                ],
              );
            },
          ),
        ),

        // Typing indicator
        if (_isAiLoading)
          _buildTypingIndicator(theme, scheme, 'KAZ AI'),

        // Input bar
        _buildInputBar(
          controller: _aiInputController,
          onSend: _sendAiMessage,
          isLoading: _isAiLoading,
          hintText: 'Ask KAZ AI anything...',
          scheme: scheme,
          theme: theme,
        ),
      ],
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SUPPORT TAB
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildSupportTab(ThemeData theme, ColorScheme scheme) {
    if (_isHistoryLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFFABD00)),
            ),
            SizedBox(height: 16),
            Text('Loading support history...', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Active ticket badge
        if (_activeTicket != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFABD00).withOpacity(0.06),
              border: Border(bottom: BorderSide(color: const Color(0xFFFABD00).withOpacity(0.2))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _activeTicket!.status == 'open'
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _activeTicket!.status.toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFB8860B)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '#${_activeTicket!.id} ${_activeTicket!.subject}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_showTicketForm)
                  TextButton(
                    onPressed: () => setState(() => _showTicketForm = false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('View Chat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),

        // Either show ticket form or chat
        Expanded(
          child: _showTicketForm && _supportMessages.isEmpty
              ? _buildTicketForm(theme, scheme)
              : _buildSupportChatView(theme, scheme),
        ),

        // Input bar for support chat (not ticket form)
        if (!_showTicketForm || _supportMessages.isNotEmpty)
          _buildInputBar(
            controller: _supportInputController,
            onSend: _sendSupportMessage,
            isLoading: _isSupportLoading,
            hintText: 'Type a message to support...',
            scheme: scheme,
            theme: theme,
            accentColor: const Color(0xFFFABD00),
          ),
      ],
    );
  }

  // ── Support Ticket Form ───────────────────────────────────────────────
  Widget _buildTicketForm(ThemeData theme, ColorScheme scheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFABD00), Color(0xFFFFD54F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFFABD00).withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.support_agent_rounded, color: Color(0xFF1A1A1A), size: 28),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Contact Support',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'Create a ticket and chat directly with our support team',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),

          // Subject field
          const Text('Subject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569), letterSpacing: 0.3)),
          const SizedBox(height: 8),
          VoiceTextField(
            controller: _ticketSubjectController,
            decoration: InputDecoration(
              hintText: 'Brief description of your issue',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFFABD00), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),

          // Description field
          const Text('Details (optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569), letterSpacing: 0.3)),
          const SizedBox(height: 8),
          VoiceTextField(
            controller: _ticketDescController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Provide additional context about your issue...',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFFABD00), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _createSupportTicket,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Create Ticket & Start Chat', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1A1A1A))),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFABD00),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Info box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Color(0xFFFABD00).withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Color(0xFFFABD00).withOpacity(0.2)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: Color(0xFFB8860B)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your conversation with support agents is fully persisted. You can close and return to it at any time. Average response time is under 5 minutes.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF92650B), height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Support Chat View ─────────────────────────────────────────────────
  Widget _buildSupportChatView(ThemeData theme, ColorScheme scheme) {
    return Column(
      children: [
        // New ticket button
        if (!_showTicketForm)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showTicketForm = true;
                      _activeTicket = null;
                    });
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: const Text('New Ticket', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFABD00),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_supportMessages.length} messages',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

        // Messages
        Expanded(
          child: ListView.builder(
            controller: _supportScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _supportMessages.length,
            itemBuilder: (context, index) {
              final msg = _supportMessages[index];
              final showAvatar = index == 0 ||
                  _supportMessages[index - 1].source != msg.source;
              final showTimestamp = index == 0 ||
                  msg.timestamp.difference(_supportMessages[index - 1].timestamp).inMinutes > 5;

              return Column(
                children: [
                  if (showTimestamp)
                    _buildDateDivider(msg.timestamp, theme),
                  _ChatBubble(
                    message: msg,
                    scheme: scheme,
                    theme: theme,
                    showAvatar: showAvatar,
                  ),
                ],
              );
            },
          ),
        ),

        // Typing indicator for support
        if (_isSupportLoading)
          _buildTypingIndicator(theme, scheme, 'Support Agent', color: const Color(0xFFFABD00)),
      ],
    );
  }

  // ── Shared UI Components ──────────────────────────────────────────────

  Widget _buildDateDivider(DateTime timestamp, ThemeData theme) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    String label;
    final diff = today.difference(msgDate).inDays;
    if (diff == 0) {
      label = 'Today';
    } else if (diff == 1) {
      label = 'Yesterday';
    } else if (diff < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      label = days[timestamp.weekday - 1];
    } else {
      label = '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(ThemeData theme, ColorScheme scheme, String label, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: (color ?? const Color(0xFFFFC812)).withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color ?? const Color(0xFFFFC812)),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$label is typing...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: (color ?? scheme.primary).withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar({
    required TextEditingController controller,
    required VoidCallback onSend,
    required bool isLoading,
    required String hintText,
    required ColorScheme scheme,
    required ThemeData theme,
    Color? accentColor,
  }) {
    final color = accentColor ?? const Color(0xFFFFC812);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(color: const Color(0xFFE2E8F0).withOpacity(0.5)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: VoiceTextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                style: const TextStyle(fontSize: 14, height: 1.4),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading ? null : onSend,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  isLoading ? Icons.hourglass_empty_rounded : Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Chat Bubble Widget — Individual Message Renderer
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.scheme,
    required this.theme,
    this.showAvatar = true,
  });

  final _ChatMessage message;
  final ColorScheme scheme;
  final ThemeData theme;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final isSystem = message.isSystem;

    if (isSystem) return _buildSystemMessage();

    final baseStyle = theme.textTheme.bodyMedium?.copyWith(
      color: isUser ? const Color(0xFF1E293B) : scheme.onSurface,
      height: 1.5,
      fontSize: 13,
    );
    final markdownStyle = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: baseStyle,
      strong: baseStyle?.copyWith(fontWeight: FontWeight.w700),
      em: baseStyle?.copyWith(fontStyle: FontStyle.italic),
      listBullet: baseStyle,
      code: baseStyle?.copyWith(
        fontFamily: appFontFamily,
        backgroundColor: scheme.surfaceContainerHighest.withOpacity(0.6),
        fontSize: 12,
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: showAvatar ? 14 : 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            _buildAvatar(showAvatar: showAvatar),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: _bubbleColor(),
                    borderRadius: _bubbleBorderRadius(),
                    boxShadow: isUser
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: MarkdownBody(
                    data: message.text,
                    styleSheet: markdownStyle,
                    selectable: true,
                    shrinkWrap: true,
                  ),
                ),
                if (showAvatar)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _formatTime(message.timestamp),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            _buildAvatar(showAvatar: showAvatar, isUser: true),
          ],
        ],
      ),
    );
  }

  Widget _buildSystemMessage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Flexible(
                child: MarkdownBody(
                  data: message.text,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF475569), height: 1.4),
                  ),
                  selectable: true,
                  shrinkWrap: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar({required bool showAvatar, bool isUser = false}) {
    if (!showAvatar) return const SizedBox(width: 36);

    if (isUser) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF2563EB).withOpacity(0.12),
          border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2), width: 1.5),
        ),
        child: const Icon(Icons.person_rounded, color: Color(0xFF2563EB), size: 16),
      );
    }

    // AI or Support avatar
    final isSupport = message.isSupportAgent;
    final bgColor = isSupport ? const Color(0xFFFABD00) : const Color(0xFFFFC812);
    final icon = isSupport ? Icons.support_agent_rounded : Icons.auto_awesome_rounded;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isSupport
            ? LinearGradient(colors: [const Color(0xFFFABD00), const Color(0xFFFFD54F)])
            : LinearGradient(colors: [const Color(0xFFFFC812), const Color(0xFFFF9800)]),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }

  Color _bubbleColor() {
    if (message.isUser) return const Color(0xFF2563EB).withOpacity(0.1);
    if (message.isSupportAgent) return Color(0xFFFABD00).withOpacity(0.06);
    return const Color(0xFFF8FAFC);
  }

  BorderRadiusGeometry _bubbleBorderRadius() {
    final isUser = message.isUser;
    return BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
      bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
