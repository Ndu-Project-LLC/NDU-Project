import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:ndu_project/services/api_config_secure.dart';
// Use relative import to ensure the library is part of this compilation unit
import 'package:ndu_project/utils/diagram_model.dart';

// Dreamflow env bindings (must exist with these exact names)
// Do not rename: Dreamflow injects values via --dart-define at build time
const String apiKey = String.fromEnvironment('OPENAI_PROXY_API_KEY');
const String endpoint = String.fromEnvironment('OPENAI_PROXY_ENDPOINT');

/// Central configuration for OpenAI API access.
/// Uses GPT-4o — OpenAI's smartest model with the best reasoning capabilities.
class OpenAiConfig {
  static String get _trimmedEnvEndpoint => endpoint.trim().isEmpty
      ? ''
      : endpoint.trim().replaceAll(RegExp(r'/+$'), '');

  /// API key preference: environment overrides user-provided runtime key.
  static String get apiKeyValue {
    if (apiKey.trim().isNotEmpty) return apiKey.trim();
    return SecureAPIConfig.apiKey ?? '';
  }

  /// Base endpoint for OpenAI API requests.
  ///
  /// When a client-side API key is available, calls OpenAI directly at
  /// api.openai.com/v1. The browser's region determines whether OpenAI
  /// accepts the request — if the user's browser is in a supported region,
  /// direct calls work fine.
  ///
  /// When no client-side key is available, falls back to the Cloud Function
  /// proxy (SecureAPIConfig.baseUrl) which holds the key server-side.
  static String get baseEndpoint {
    if (_trimmedEnvEndpoint.isNotEmpty) return _trimmedEnvEndpoint;
    // If we have a client-side key, call OpenAI directly
    if (apiKeyValue.isNotEmpty) {
      return 'https://api.openai.com/v1';
    }
    // No client-side key — use the Cloud Function proxy
    return SecureAPIConfig.baseUrl;
  }

  /// Model used for OpenAI API requests — GPT-4o.
  static String get model => SecureAPIConfig.model;

  /// OpenAI API version (kept for backward compat).
  static String get openaiApiVersion => SecureAPIConfig.openaiApiVersion;

  // Consider configured if we have an API key OR if we're using the Cloud
  // Function proxy (which holds the key server-side). The proxy is the
  // default production path — the app doesn't need a client-side key.
  static bool get isConfigured => true;

  /// Determine if we're using a proxy endpoint (not needed for OpenAI).
  static bool get _isProxyEndpoint => false;

  /// OpenAI Chat Completions API endpoint.
  static Uri messagesUri() {
    return Uri.parse('$baseEndpoint/chat/completions');
  }

  /// Alias for backward compatibility.
  static Uri chatUri() => messagesUri();

  /// Alias for backward compatibility.
  static Uri responsesUri() => messagesUri();

  /// Wraps a request body map for the OpenAI Chat Completions API.
  /// Normalizes request body to OpenAI format if needed.
  static Map<String, dynamic> wrapBody(Map<String, dynamic> body) {
    final result = Map<String, dynamic>.from(body);

    // If body has a top-level 'system' param (legacy style), move it
    // into the messages array as a system message (OpenAI style)
    if (result.containsKey('system') && !result.containsKey('messages')) {
      final system = result.remove('system');
      result['messages'] = [
        {'role': 'system', 'content': system},
      ];
    } else if (result.containsKey('system')) {
      final system = result.remove('system');
      final messages = List<Map<String, dynamic>>.from(
        (result['messages'] as List? ?? []).map((m) =>
            Map<String, dynamic>.from(m as Map)),
      );
      messages.insert(0, {'role': 'system', 'content': system});
      result['messages'] = messages;
    }

    // Convert max_tokens to max_tokens (OpenAI uses same name)
    // Already correct for OpenAI format

    // Remove legacy-specific fields (no-op for OpenAI, but cleans up any
    // leftover fields from older request formats)
    // No legacy anthropic_version to remove (OpenAI-only project)

    // Convert max_completion_tokens to max_tokens (OpenAI Chat Completions
    // uses max_tokens, not max_completion_tokens which is Responses API only)
    if (result.containsKey('max_completion_tokens')) {
      result['max_tokens'] = result.remove('max_completion_tokens');
    }
    if (result.containsKey('max_output_tokens')) {
      result['max_tokens'] = result.remove('max_output_tokens');
    }

    // Ensure max_tokens exists with a reasonable default
    if (!result.containsKey('max_tokens')) {
      result['max_tokens'] = 1200;
    }

    // Ensure model is set
    if (!result.containsKey('model') || (result['model'] as String?)?.isEmpty == true) {
      result['model'] = model;
    }

    return result;
  }

  /// Returns headers for OpenAI API requests.
  ///
  /// When using the Cloud Function proxy (default production path), we
  /// don't send an Authorization header — the proxy adds it server-side
  /// with the secret key. When a client-side key is provided (via
  /// env-config.js or Settings), we send it for direct OpenAI calls.
  static Map<String, String> headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (apiKeyValue.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKeyValue';
    }
    return headers;
  }

  /// Extracts text content from an OpenAI API response.
  /// OpenAI returns: { "choices": [ { "message": { "content": "..." } } ] }
  static String extractContent(Map<String, dynamic> data) {
    // OpenAI Chat Completions format
    final choices = data['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map<String, dynamic>) {
        final message = first['message'];
        if (message is Map<String, dynamic>) {
          final messageContent = message['content'];
          if (messageContent is String) return messageContent;
          if (messageContent is List) {
            return messageContent
                .map((e) => e is Map<String, dynamic> ? (e['text'] ?? '') : (e ?? ''))
                .join();
          }
        }
        final text = first['text'];
        if (text is String) return text;
      }
    }

    // Try output format (OpenAI Responses API)
    final output = data['output'];
    if (output is List) {
      final buffer = StringBuffer();
      for (final entry in output) {
        if (entry is Map<String, dynamic>) {
          final entryContent = entry['content'];
          if (entryContent is List) {
            for (final item in entryContent) {
              if (item is Map<String, dynamic>) {
                final type = item['type'];
                final text = item['text'];
                if (text is String && (type == 'output_text' || type == 'text')) {
                  buffer.write(text);
                }
              }
            }
          }
        }
      }
      if (buffer.isNotEmpty) return buffer.toString();
    }

    return '';
  }

  /// Helpful diagnostic used by UI to provide actionable error messages
  static String? configurationWarning() {
    if (!kIsWeb) return null;
    if (_isProxyEndpoint) return null; // ok, using proxy
    // On web with direct OpenAI endpoint: likely to hit CORS
    return 'OpenAI proxy endpoint not configured. Using direct OpenAI endpoint may fail due to CORS. Set OPENAI_PROXY_ENDPOINT to your Cloud Function URL (do not append a path).';
  }
}

class OpenAiNotConfiguredException implements Exception {
  const OpenAiNotConfiguredException();

  @override
  String toString() =>
      'AI service is starting up. Please try again in a moment.';
}

/// Lightweight autocomplete service backed by OpenAI Chat Completions API.
class OpenAiAutocompleteService {
  OpenAiAutocompleteService._internal({http.Client? client})
      : _client = client ?? http.Client();

  static final OpenAiAutocompleteService instance =
      OpenAiAutocompleteService._internal();

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 12);
  static const double _temperature = 0.35;

  Future<List<String>> fetchSuggestions({
    required String fieldName,
    required String currentText,
    String context = '',
    int maxSuggestions = 3,
  }) async {
    if (currentText.trim().isEmpty) return const [];
    if (!OpenAiConfig.isConfigured) {
      throw const OpenAiNotConfiguredException();
    }

    final uri = OpenAiConfig.responsesUri();
    final headers = OpenAiConfig.headers();

    final payload = {
      'model': OpenAiConfig.model,
      'temperature': _temperature,
      'max_tokens': 300,
      'system': 'You help business analysts finish their writing. Provide up to $maxSuggestions polished continuation suggestions that extend the user\'s draft. Do not repeat the existing text, do not number or bullet responses, and avoid placeholders. Return each suggestion on its own line.',
      'messages': [
        {
          'role': 'user',
          'content': 'Field: $fieldName\nCurrent draft: """${_escape(currentText)}"""\nAdditional context: """${_escape(context)}"""\nReturn up to $maxSuggestions unique continuations, each on its own line.'
        }
      ],
    };

    try {
      final warn = OpenAiConfig.configurationWarning();
      if (warn != null) {
        debugPrint('OpenAI configuration warning: $warn (endpoint=${OpenAiConfig.baseEndpoint})');
      }
      final response = await _client
          .post(uri, headers: headers, body: jsonEncode(OpenAiConfig.wrapBody(payload)))
          .timeout(_timeout);

      if (response.statusCode == 429) {
        throw Exception('OpenAI rate limit reached. Please try again shortly.');
      }
      if (response.statusCode == 401) {
        throw Exception('OpenAI API key not accepted. Please check the key in Settings or contact support.');
      }
      if (response.statusCode == 403) {
        final body = response.body;
        if (body.contains('unsupported_country_region_territory')) {
          throw Exception('OpenAI is not available in your region. Please use a VPN or contact support.');
        }
        throw Exception('OpenAI access denied (${response.statusCode}). Please check your API key.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'OpenAI request failed (${response.statusCode}): ${response.body}',
        );
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final combined = OpenAiConfig.extractContent(data).trim();
      final suggestions = combined
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .take(maxSuggestions)
          .toList();

      if (suggestions.isNotEmpty) return suggestions;

      return _fallbackSuggestions(currentText, maxSuggestions);
    } on TimeoutException {
      throw Exception('OpenAI request timed out. Please retry in a moment.');
    } on FormatException catch (e) {
      throw Exception('Failed to parse OpenAI response: $e');
    }
  }

  static List<String> _fallbackSuggestions(String currentText, int count) {
    final trimmed = currentText.trim();
    if (trimmed.isEmpty) return const [];

    final lastSentenceBreak = trimmed.lastIndexOf(RegExp(r'[.!?]\s'));
    final seed = lastSentenceBreak == -1
        ? trimmed
        : trimmed.substring(lastSentenceBreak + 1).trim();

    final base = seed.isEmpty ? 'The initiative' : seed;

    final patterns = <String>[
      '$base will deliver measurable value by aligning stakeholders and clarifying success metrics.',
      '$base includes a phased rollout with checkpoints to reduce delivery risk and accelerate adoption.',
      '$base secures executive sponsorship, ensuring funding, governance, and rapid decision-making support.',
    ];

    return patterns.take(count).toList();
  }

  static String _escape(String value) => value.replaceAll('"""', '"""');
}

/// Diagram generation service. Returns a simple node/edge model suitable for lightweight rendering.
class OpenAiDiagramService {
  OpenAiDiagramService._internal();
  static final OpenAiDiagramService instance = OpenAiDiagramService._internal();

  Future<DiagramModel> generateDiagram({
    required String section,
    required String contextText,
    int maxTokens = 1200,
    String? refinementHint,
  }) async {
    if (!OpenAiConfig.isConfigured) {
      // Fallback: single-node diagram using section name
      return DiagramModel(nodes: [DiagramNode(id: 'start', label: section)], edges: const []);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final prompt = _diagramPrompt(section: section, context: contextText, refinementHint: refinementHint);
    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': 0.5,
      'max_tokens': maxTokens,
      'system': '''You are an expert strategic planning architect specializing in executive-level project visualization. Your diagrams are exceptional because they:
1. Show REASONING and LOGIC, not just process steps
2. Illustrate strategic thinking with decision criteria and branching paths
3. Highlight dependencies, risks, and validation checkpoints
4. Connect objectives to outcomes through clear cause-effect chains
5. Use specific, contextual labels derived from the actual project content

You create diagrams that executives and stakeholders can use to understand the "WHY" behind each step, not just the "WHAT". Every node and edge must serve a strategic purpose. Generic placeholders are never acceptable.

Always return ONLY a valid JSON object with nodes and edges arrays.''',
      'messages': [
        {
          'role': 'user',
          'content': prompt,
        }
      ],
    }));

    try {
      final response = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 16));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('OpenAI diagram error ${response.statusCode}: ${response.body}');
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content = OpenAiConfig.extractContent(data);
      // Extract JSON from the response (may be wrapped in markdown code block)
      final jsonStr = _extractJson(content);
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      return _parseDiagram(parsed);
    } catch (e) {
      debugPrint('OpenAI diagram generation failed: $e');
      // Fallback contextual diagram based on section
      return _createFallbackDiagram(section);
    }
  }

  /// Extracts JSON from a string that may contain markdown code fences.
  static String _extractJson(String text) {
    // Try to find JSON within markdown code blocks
    final codeBlockRegex = RegExp(r'```(?:json)?\s*\n?([\s\S]*?)\n?```');
    final match = codeBlockRegex.firstMatch(text);
    if (match != null) {
      return match.group(1)?.trim() ?? text.trim();
    }
    // Try to find raw JSON object
    final jsonStart = text.indexOf('{');
    final jsonEnd = text.lastIndexOf('}');
    if (jsonStart >= 0 && jsonEnd > jsonStart) {
      return text.substring(jsonStart, jsonEnd + 1);
    }
    return text.trim();
  }

  String _diagramPrompt({required String section, required String context, String? refinementHint}) {
    final s = _sanitize(section);
    final c = _sanitize(context);
    final hintLine = refinementHint != null ? '\nUser Refinement: ${_refinementHintText(refinementHint)}\n' : '';
    return '''
You are generating a REASONING DIAGRAM for the "$s" section. This must be an exceptional, thought-provoking visual that demonstrates strategic thinking—NOT a generic flowchart.

DIAGRAM REQUIREMENTS:
1. Show REASONING CHAINS: Each node should represent a logical step in strategic thinking (e.g., "Assess Current State" → "Identify Gaps" → "Evaluate Options" → "Select Approach")
2. Include DECISION POINTS with clear criteria (e.g., "Risk Threshold?" with branches showing "High" or "Acceptable")
3. Show DEPENDENCIES and PREREQUISITES: What must happen before each phase can begin
4. Include KEY CONSIDERATIONS at critical junctures (e.g., "Budget Constraints", "Timeline Pressures", "Stakeholder Alignment")
5. Represent CAUSE-EFFECT relationships: Show how one decision impacts subsequent phases
6. Include VALIDATION checkpoints: Points where progress is verified before proceeding

For "$s" specifically, the diagram should illustrate:
- Strategic objectives driving the execution plan
- Critical success factors and how they're addressed
- Risk mitigation decision points
- Resource allocation reasoning
- Phase dependencies and sequencing rationale
- Go/No-Go decision criteria

Return ONLY valid JSON with this exact structure:
{
  "nodes": [
    {"id": "unique_id", "label": "Descriptive Label (max 5 words)", "type": "start|objective|analysis|decision|action|validation|milestone|risk|output|end"}
  ],
  "edges": [
    {"from": "source_id", "to": "target_id", "label": "relationship or condition"}
  ]
}

Guidelines:
- 8–15 nodes for comprehensive reasoning flow
- Labels must be SPECIFIC to the content, never generic (e.g., "Validate Resource Capacity" not "Check Resources")
- Edge labels should describe WHY the connection exists (e.g., "if approved", "enables", "requires", "triggers")
- Include at least 2 decision nodes with branching paths
- Include at least 1 validation/checkpoint node
- Show parallel tracks where activities can occur simultaneously
- End with measurable outcomes, not just "End"

User Context for "$s":
"""
$c
"""
$hintLine
Generate a diagram that demonstrates STRATEGIC REASONING for executing this plan, not just process steps.
''';
  }

  DiagramModel _parseDiagram(Map<String, dynamic> map) {
    final rawNodes = (map['nodes'] as List? ?? []).whereType<Map>().toList();
    final rawEdges = (map['edges'] as List? ?? []).whereType<Map>().toList();
    final nodes = <DiagramNode>[];
    for (var i = 0; i < rawNodes.length; i++) {
      final m = rawNodes[i] as Map<String, dynamic>;
      final idRaw = (m['id'] ?? '').toString().trim();
      final id = idRaw.isEmpty ? 'n${i + 1}' : idRaw;
      nodes.add(DiagramNode(
        id: id,
        label: (m['label'] ?? '').toString().trim(),
        type: (m['type'] ?? 'process').toString().trim(),
      ));
    }
    final edges = rawEdges
        .map((m) => DiagramEdge(
              from: (m['from'] ?? '').toString().trim(),
              to: (m['to'] ?? '').toString().trim(),
              label: (m['label'] ?? '').toString().trim(),
            ))
        .where((e) => e.from.isNotEmpty && e.to.isNotEmpty)
        .toList();
    if (nodes.isEmpty) {
      return const DiagramModel(nodes: [DiagramNode(id: 'start', label: 'Start')], edges: []);
    }
    return DiagramModel(nodes: nodes, edges: edges);
  }

  String _sanitize(String v) => v.replaceAll('"', '\\"');

  String _refinementHintText(String hint) {
    switch (hint) {
      case 'more_decisions':
        return 'Add more decision nodes with branching criteria, and show alternative paths.';
      case 'simplify':
        return 'Simplify the diagram. Reduce to 5-7 key nodes, merge related steps, focus on the main flow.';
      case 'focus_risks':
        return 'Emphasize risk nodes, risk mitigations, and decision points where risks are evaluated.';
      case 'timelines':
        return 'Add milestone nodes and sequence indicators to show temporal progression and phase durations.';
      default:
        return hint;
    }
  }

  /// Creates a contextual fallback diagram when API fails
  DiagramModel _createFallbackDiagram(String section) {
    final sectionLower = section.toLowerCase();

    // Executive Plan Outline specific fallback
    if (sectionLower.contains('executive') || sectionLower.contains('outline')) {
      return const DiagramModel(
        nodes: [
          DiagramNode(id: 'objectives', label: 'Define Strategic Objectives', type: 'objective'),
          DiagramNode(id: 'assess', label: 'Assess Current State', type: 'analysis'),
          DiagramNode(id: 'gaps', label: 'Identify Capability Gaps', type: 'analysis'),
          DiagramNode(id: 'decision', label: 'Feasibility Check', type: 'decision'),
          DiagramNode(id: 'approach', label: 'Select Execution Approach', type: 'action'),
          DiagramNode(id: 'resources', label: 'Allocate Resources', type: 'action'),
          DiagramNode(id: 'validate', label: 'Stakeholder Validation', type: 'validation'),
          DiagramNode(id: 'plan', label: 'Finalize Execution Plan', type: 'milestone'),
          DiagramNode(id: 'outcomes', label: 'Defined Success Metrics', type: 'output'),
        ],
        edges: [
          DiagramEdge(from: 'objectives', to: 'assess', label: 'drives'),
          DiagramEdge(from: 'assess', to: 'gaps', label: 'reveals'),
          DiagramEdge(from: 'gaps', to: 'decision', label: 'informs'),
          DiagramEdge(from: 'decision', to: 'approach', label: 'if viable'),
          DiagramEdge(from: 'approach', to: 'resources', label: 'requires'),
          DiagramEdge(from: 'resources', to: 'validate', label: 'enables'),
          DiagramEdge(from: 'validate', to: 'plan', label: 'if approved'),
          DiagramEdge(from: 'plan', to: 'outcomes', label: 'produces'),
        ],
      );
    }

    // Strategy related sections
    if (sectionLower.contains('strategy')) {
      return const DiagramModel(
        nodes: [
          DiagramNode(id: 'vision', label: 'Strategic Vision', type: 'objective'),
          DiagramNode(id: 'analyze', label: 'Market Analysis', type: 'analysis'),
          DiagramNode(id: 'options', label: 'Evaluate Options', type: 'decision'),
          DiagramNode(id: 'select', label: 'Strategy Selection', type: 'action'),
          DiagramNode(id: 'implement', label: 'Implementation Roadmap', type: 'milestone'),
        ],
        edges: [
          DiagramEdge(from: 'vision', to: 'analyze', label: 'guides'),
          DiagramEdge(from: 'analyze', to: 'options', label: 'enables'),
          DiagramEdge(from: 'options', to: 'select', label: 'informs'),
          DiagramEdge(from: 'select', to: 'implement', label: 'produces'),
        ],
      );
    }

    // Default reasoning-based fallback
    return DiagramModel(
      nodes: [
        DiagramNode(id: 'start', label: 'Define $section Goals', type: 'objective'),
        const DiagramNode(id: 'analyze', label: 'Analyze Requirements', type: 'analysis'),
        const DiagramNode(id: 'evaluate', label: 'Evaluate Approaches', type: 'decision'),
        const DiagramNode(id: 'plan', label: 'Develop Action Plan', type: 'action'),
        const DiagramNode(id: 'validate', label: 'Validation Checkpoint', type: 'validation'),
        DiagramNode(id: 'outcome', label: '$section Complete', type: 'output'),
      ],
      edges: const [
        DiagramEdge(from: 'start', to: 'analyze', label: 'requires'),
        DiagramEdge(from: 'analyze', to: 'evaluate', label: 'enables'),
        DiagramEdge(from: 'evaluate', to: 'plan', label: 'informs'),
        DiagramEdge(from: 'plan', to: 'validate', label: 'requires'),
        DiagramEdge(from: 'validate', to: 'outcome', label: 'confirms'),
      ],
    );
  }
}
