/// [LocalAiEngine] — the code-level content generator.
///
/// When [AiMode.isLocal] is on, no request leaves the device. This engine
/// answers an OpenAI-shaped chat-completion request the same way a model
/// would: it reads the prompt's system/user messages, works out what shape of
/// answer the caller is parsing for, and synthesizes deterministic, on-topic
/// content in that shape.
///
/// It is *not* a language model — it is a rules engine that mimics one at the
/// contract level so every AI surface in the app keeps working with no
/// provider, no key, no network:
///
///   1. If the caller asked for JSON (`response_format: json_object` or a
///      prompt that says "return JSON"), the engine finds the JSON template
///      the prompt declares and fills it with plausible, context-aware values.
///   2. Otherwise it returns a short, structured prose answer.
///
/// Output is deterministic: the same request always produces the same answer,
/// which is what makes local-mode screens testable end to end.
library;

import 'dart:convert';

/// Which part of the project the request is about. Detected from the prompt so
/// generated content reads like the real subject rather than generic filler.
enum _Domain { cost, risk, solution, wbs, schedule, governance, generic }

/// Context distilled from a prompt, used to keep generated content on topic.
class _PromptContext {
  _PromptContext(this.prompt, this.topic, this.seed, this.domain);

  final String prompt;
  final String topic;
  final int seed;
  final _Domain domain;

  String get subject => topic;
}

class LocalAiEngine {
  LocalAiEngine._();

  static const String _disclaimer =
      '⚠️ AI-generated content — validate with a qualified Subject Matter Expert before baseline.';

  /// Builds the full OpenAI-style chat-completion body a caller expects, with
  /// the synthesized answer in `choices[0].message.content`.
  static Map<String, dynamic> chatResponse(Map<String, dynamic> request) {
    return {
      'id': 'local-${_fnv1a(jsonEncode(request)).toRadixString(16)}',
      'object': 'chat.completion',
      'model': 'ndu-local-generator',
      'choices': [
        {
          'index': 0,
          'finish_reason': 'stop',
          'message': {
            'role': 'assistant',
            'content': completion(request),
          },
        },
      ],
      'usage': const {
        'prompt_tokens': 0,
        'completion_tokens': 0,
        'total_tokens': 0,
      },
      // Let callers (and tests) see that this answer was produced in code.
      'ndu_local_generation': true,
    };
  }

  /// Returns the assistant content string for [request].
  static String completion(Map<String, dynamic> request) {
    final messages = (request['messages'] as List?) ?? const [];
    final system = _roleText(messages, 'system');
    final user = _roleText(messages, 'user');
    final prompt = [system, user].where((s) => s.trim().isNotEmpty).join('\n\n');

    if (prompt.trim().isEmpty) {
      return _disclaimer;
    }

    if ((request['purpose'] ?? '').toString() == 'autocomplete') {
      return _autocompleteAnswer(prompt);
    }

    // Prefer the user message for topic detection — system prompts carry
    // generic role text that would otherwise leak into generated content.
    final ctx = _contextFor(prompt, user.trim().isEmpty ? prompt : user);
    if (_wantsJson(request, prompt)) {
      return _jsonAnswer(ctx);
    }
    return _proseAnswer(ctx);
  }

  /// Inline autocomplete expects newline-separated continuations, not prose.
  static String _autocompleteAnswer(String prompt) {
    final subject = _extractTopic(prompt);
    return '${_variant(0)} scope for $subject, aligned to the current plan.\n'
        '${_variant(1)} milestones with named owners and review gates.\n'
        '${_variant(2)} risks addressed through supplier and resource '
        'contingency at each phase.';
  }

  // ── Request inspection ────────────────────────────────────────────────────

  static String _roleText(List messages, String role) {
    final buffer = StringBuffer();
    for (final message in messages) {
      if (message is! Map) continue;
      if ((message['role'] ?? '').toString() != role) continue;
      final content = message['content'];
      if (content is String) {
        buffer.writeln(content);
      } else if (content is List) {
        for (final part in content) {
          if (part is Map && part['text'] != null) {
            buffer.writeln(part['text']);
          }
        }
      }
    }
    return buffer.toString().trim();
  }

  static bool _wantsJson(Map<String, dynamic> request, String prompt) {
    final format = request['response_format'];
    if (format is Map && (format['type'] ?? '').toString() == 'json_object') {
      return true;
    }
    if (format is String && format.toLowerCase() == 'json') return true;
    final lower = prompt.toLowerCase();
    return lower.contains('json') ||
        lower.contains('return only valid') ||
        lower.contains('exact structure') ||
        lower.contains('respond with a json');
  }

  /// Distils the prompt's subject so generated text is not generic filler.
  static _PromptContext _contextFor(String prompt, String topicSource) {
    final topic = _extractTopic(topicSource);
    return _PromptContext(prompt, topic, _fnv1a(prompt), _detectDomain(prompt));
  }

  /// Scores the prompt against each domain's vocabulary and takes the winner.
  static _Domain _detectDomain(String prompt) {
    final p = prompt.toLowerCase();
    int score(List<String> words) => words.where(p.contains).length;

    final scores = <_Domain, int>{
      _Domain.cost: score(const [
        'rate', 'quantity', 'cost', 'estimate', 'budget', 'subcategory',
        'contingency', 'allowance',
      ]),
      _Domain.risk: score(const [
        'risk', 'mitigation', 'likelihood', 'severity', 'threat',
      ]),
      _Domain.solution: score(const [
        'solution', 'option', 'alternative', 'approach being considered',
      ]),
      _Domain.wbs: score(const [
        'wbs', 'work breakdown', 'deliverable', 'level 1', 'level1',
        'breakdown structure',
      ]),
      _Domain.schedule: score(const [
        'activity', 'duration', 'schedule', 'milestone', 'start date',
        'finish date', 'critical path',
      ]),
      _Domain.governance: score(const [
        'governance', 'charter', 'stakeholder', 'raci', 'approval', 'objective',
      ]),
    };

    _Domain best = _Domain.generic;
    var bestScore = 0;
    scores.forEach((domain, value) {
      if (value > bestScore) {
        best = domain;
        bestScore = value;
      }
    });
    return best;
  }

  static String _extractTopic(String prompt) {
    final patterns = <RegExp>[
      RegExp(r'section\s+"([^"]{3,80})"', caseSensitive: false),
      RegExp(r'for\s+"([^"]{3,80})"\s+section', caseSensitive: false),
      RegExp(r'section[:\s]+([A-Z][A-Za-z0-9 &/\-]{2,60})'),
      // Prose prompts: "... the rollout approach for ..." → "rollout".
      RegExp(r'\b(?:the|a|an)\s+([a-z][a-z0-9\-]{3,24})\s+'
          r'(?:approach|plan|process|strategy|section|phase|summary|outline|'
          r'analysis|design|schedule|budget|risk|scope|rollout)\b'),
      RegExp(r'project\s*name\s*[:\-]\s*([^\n]{2,80})', caseSensitive: false),
      RegExp(r'project\s*[:\-]\s*([^\n]{2,80})', caseSensitive: false),
      RegExp(r'"([A-Z][^"]{2,60})"\s+section', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(prompt);
      final value = match?.group(1)?.trim();
      if (value != null && value.isNotEmpty) return _titleCase(value);
    }

    // Fall back to the first quoted phrase that reads like a heading.
    final quoted = RegExp(r'"([A-Z][^"]{3,60})"').firstMatch(prompt);
    if (quoted != null) return _titleCase(quoted.group(1)!.trim());

    return 'the project';
  }

  // ── JSON answers ──────────────────────────────────────────────────────────

  static String _jsonAnswer(_PromptContext ctx) {
    final template = _findJsonTemplate(ctx.prompt);
    final Object? payload = template != null
        ? _fill(template, '', ctx, 0)
        : _genericJson(ctx);
    return jsonEncode(payload);
  }

  /// Finds the JSON object template the prompt declares.
  ///
  /// Prompts in this app consistently end with an "exact structure" block such
  /// as `{"suggestions": [{"title": "", "description": ""}]}`. We scan for
  /// balanced `{...}` blocks that parse as JSON and take the last one, which is
  /// the requested schema rather than an earlier example.
  static Object? _findJsonTemplate(String prompt) {
    final candidates = _balancedJsonBlocks(prompt);
    for (final candidate in candidates.reversed) {
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map && decoded.isNotEmpty) return decoded;
      } catch (_) {
        // Not a parseable template — keep looking.
      }
    }
    return null;
  }

  static List<String> _balancedJsonBlocks(String text) {
    final blocks = <String>[];
    for (var i = 0; i < text.length; i++) {
      if (text[i] != '{') continue;
      var depth = 0;
      var inString = false;
      var escaped = false;
      for (var j = i; j < text.length; j++) {
        final c = text[j];
        if (inString) {
          if (escaped) {
            escaped = false;
          } else if (c == r'\') {
            escaped = true;
          } else if (c == '"') {
            inString = false;
          }
          continue;
        }
        if (c == '"') {
          inString = true;
        } else if (c == '{') {
          depth++;
        } else if (c == '}') {
          depth--;
          if (depth == 0) {
            blocks.add(text.substring(i, j + 1));
            // Skip past the whole block so its nested objects are not also
            // collected as candidates — we only want top-level templates.
            i = j;
            break;
          }
        }
      }
    }
    return blocks;
  }

  /// Recursively fills a decoded JSON template with plausible values.
  static Object? _fill(Object? template, String key, _PromptContext ctx, int index) {
    if (template is Map) {
      final out = <String, Object?>{};
      for (final entry in template.entries) {
        final k = entry.key.toString();
        out[k] = _fill(entry.value, k, ctx, index);
      }
      return out;
    }
    if (template is List) {
      final count = _listCountFor(key);
      if (template.isEmpty) {
        return List.generate(
          count,
          (i) => _valueFor(key, ctx, i),
        );
      }
      final itemTemplate = template.first;
      return List.generate(
        count,
        (i) => _fill(itemTemplate, key, ctx, i),
      );
    }
    if (template is num) return _numberFor(key, ctx, index);
    if (template is bool) return true;
    return _valueFor(key, ctx, index, hint: template?.toString());
  }

  static int _listCountFor(String key) {
    final k = key.toLowerCase();
    if (k.contains('recommendation') ||
        k.contains('risk') ||
        k.contains('benefit') ||
        k.contains('suggestion') ||
        k.contains('solution') ||
        k.contains('item') ||
        k.contains('step')) {
      return 3;
    }
    return 2;
  }

  static num _numberFor(String key, _PromptContext ctx, int index) {
    final k = key.toLowerCase();
    if (k.contains('year')) return index + 1;
    if (k.contains('percent') || k.contains('roi') || k.contains('rate_of')) {
      return 12;
    }
    if (k.contains('rate') || k.contains('hourly') || k.contains('price')) {
      return 120 + (ctx.seed % 7) * 5;
    }
    if (k.contains('quantity') || k.contains('count') || k.contains('hours')) {
      return 40 + index * 8;
    }
    if (k.contains('cost') ||
        k.contains('amount') ||
        k.contains('budget') ||
        k.contains('total') ||
        k.contains('savings') ||
        k.contains('value')) {
      return 25000 + (ctx.seed % 11) * 2500 + index * 1500;
    }
    if (k.contains('low')) return 95;
    if (k.contains('high')) return 175;
    if (k.contains('probability') || k.contains('likelihood')) return 0.4;
    if (k.contains('score') || k.contains('weight')) return 3 + index;
    return 1 + index;
  }

  /// Produces a plausible string for [key]. Known keys (ids, enums, units)
  /// return valid literals; everything else returns on-topic prose.
  static String _valueFor(
    String key,
    _PromptContext ctx,
    int index, {
    String? hint,
  }) {
    final k = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    // A template string containing '|' is an enum description (e.g.
    // "high|medium|low") — pick a valid option rather than inventing text.
    final enumValue = _enumFromHint(hint);
    if (enumValue != null) return enumValue;

    // Structural / literal fields first.
    if (k == 'id' || (k.endsWith('id') && k != 'valid')) {
      final slug = _slug(ctx.subject);
      return '${slug.isEmpty ? 'item' : slug}-${index + 1}';
    }
    if (k == 'unit') return index.isEven ? 'hours' : 'lump';
    if (k == 'currency') return 'USD';
    if (k == 'confidence' || k == 'confidencelevel') {
      return const ['HIGH', 'MEDIUM', 'LOW'][index % 3];
    }
    if (k == 'risk' || k == 'risklevel' || k == 'severity') {
      return const ['LOW', 'MEDIUM', 'HIGH'][index % 3];
    }
    if (k == 'priority') return const ['P1', 'P2', 'P3'][index % 3];
    if (k == 'status') return const ['Planned', 'In Progress', 'At Risk'][index % 3];
    if (k == 'timeframe' || k == 'period' || k == 'horizon') {
      return const ['0-3 months', '3-6 months', '6-12 months'][index % 3];
    }
    if (k == 'from' || k == 'to') {
      // Diagram edges reference the ids the node list generates.
      return '${_slug(ctx.subject)}-${k == 'from' ? 1 : 2}';
    }
    if (k.endsWith('node')) {
      return '${_slug(ctx.subject)}-${index + 1}';
    }
    final subject = ctx.subject;

    // A template item's fields all share one index (see [_fill]), so the
    // description and rationale stay consistent with the heading above them.
    if (k.contains('title') ||
        k.contains('name') ||
        k.contains('label') ||
        k.contains('solution') ||
        k.contains('subcategory')) {
      return _headingFor(ctx.domain, subject, index);
    }
    if (k.contains('description') ||
        k.contains('detail') ||
        k.contains('summary')) {
      return _describeFor(ctx.domain, _headingFor(ctx.domain, subject, index));
    }
    if (k.contains('rationale') || k.contains('reason') || k.contains('why')) {
      return _rationaleFor(
          ctx.domain, _headingFor(ctx.domain, subject, index));
    }
    if (k.contains('recommendation') ||
        k.contains('suggestedaction') ||
        k.contains('action') ||
        k.contains('mitigation')) {
      return 'Assign an owner and review gate for $subject: '
          '${_variant(index).toLowerCase()} mitigation before the next checkpoint.';
    }
    if (k.contains('risk')) {
      return '${_variant(index)} exposure in $subject could delay the '
          'critical path if left unmanaged.';
    }
    if (k.contains('strength')) {
      return '${_variant(index)} foundation is already in place for $subject.';
    }
    if (k.contains('concern') || k.contains('gap') || k.contains('issue')) {
      return 'Verify ${_variant(index).toLowerCase()} coverage for $subject '
          'before baseline.';
    }
    if (k.contains('text') ||
        k.contains('content') ||
        k.contains('insight') ||
        k.contains('assessment') ||
        k.contains('objective') ||
        k.contains('notes') ||
        k.contains('summary')) {
      return 'For "$subject", current information supports ${_variant(index).toLowerCase()} '
          'planning with measurable checkpoints and named owners.';
    }
    if (k.contains('edge') || k.contains('relationship') || k.contains('condition')) {
      return const ['enables', 'requires', 'if approved', 'triggers'][index % 4];
    }
    if (k.contains('role') || k.contains('owner') || k.contains('assignee')) {
      return const [
        'Project Manager',
        'Technical Lead',
        'Quality Manager',
      ][index % 3];
    }

    return '${_variant(index)} $subject';
  }

  static String? _enumFromHint(String? hint) {
    if (hint == null || !hint.contains('|')) return null;
    final parts = hint
        .split('|')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    return parts.first;
  }

  /// Last-resort JSON when the prompt declares no usable template. Keeps the
  /// shapes most of this app's parsers tolerate (a `text` field plus a small
  /// list of structured items).
  static Map<String, dynamic> _genericJson(_PromptContext ctx) {
    final keys = _quotedKeys(ctx.prompt);
    if (keys.isNotEmpty) {
      final out = <String, dynamic>{};
      for (final key in keys.take(8)) {
        out[key] = _valueFor(key, ctx, 0);
      }
      out['source'] = 'KAZ AI';
      out['disclaimer'] = _disclaimer;
      return out;
    }
    return {
      'text': _proseAnswer(ctx),
      'source': 'KAZ AI',
      'disclaimer': _disclaimer,
    };
  }

  /// Keys the prompt itself mentions, e.g. `"title"`, `"description"`.
  static List<String> _quotedKeys(String prompt) {
    final seen = <String>{};
    final keys = <String>[];
    for (final match in RegExp(r'"([A-Za-z][A-Za-z0-9_]{1,28})"\s*:').allMatches(prompt)) {
      final key = match.group(1)!;
      if (seen.add(key)) keys.add(key);
    }
    return keys;
  }

  // ── Prose answers ─────────────────────────────────────────────────────────

  static String _proseAnswer(_PromptContext ctx) {
    final subject = ctx.subject;
    return 'Here is a working position on **$subject**, generated from the '
        'current project context.\n\n'
        '• **Scope** — ${_variant(0)} delivery covering the essential scope, '
        'with explicit acceptance criteria for $subject.\n'
        '• **Approach** — sequence the work around ${_variant(1).toLowerCase()} '
        'readiness, then validate at a single named checkpoint before '
        'committing to the next phase.\n'
        '• **Risks** — the main exposure is ${_variant(2).toLowerCase()} '
        'coverage; assign an owner and review it at each gate.\n\n'
        'Next step: confirm the owner, the acceptance criteria, and the '
        'review date for $subject.\n\n'
        '$_disclaimer';
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static const List<String> _variants = [
    'Foundation',
    'Integration',
    'Governance',
    'Assurance',
    'Rollout',
    'Readiness',
    'Optimization',
    'Continuity',
  ];

  static String _variant(int index) => _variants[index % _variants.length];

  /// Domain-appropriate item headings, so a cost breakdown reads like a cost
  /// breakdown and a risk list reads like a risk list.
  static const Map<_Domain, List<String>> _headingBanks = {
    _Domain.cost: [
      'Project Management',
      'PMO Support',
      'Safety, Health & Environment',
      'Quality Assurance & Control',
      'Engineering & Design',
      'Procurement & Logistics',
      'Construction & Installation',
      'Commissioning & Handover',
      'Contingency Reserve',
      'Training & Change Management',
    ],
    _Domain.risk: [
      'Scope Creep',
      'Resource Unavailability',
      'Supplier Delay',
      'Integration Failure',
      'Regulatory Non-compliance',
      'Data Migration Errors',
      'Skills Gap',
      'Budget Overrun',
      'Stakeholder Misalignment',
      'Technology Obsolescence',
    ],
    _Domain.solution: [
      'Greenfield Build',
      'Phased Modernization',
      'Managed Service Model',
      'Platform Consolidation',
      'Hybrid Delivery',
    ],
    _Domain.wbs: [
      'Engineering & Design',
      'Procurement',
      'Construction',
      'Commissioning',
      'Project Management',
      'Quality Management',
      'Health & Safety',
      'Project Closeout',
    ],
    _Domain.schedule: [
      'Design Review',
      'Procurement Lead Time',
      'Site Mobilization',
      'Installation Window',
      'Integration Testing',
      'User Acceptance Testing',
      'Go-Live Readiness',
      'Post-Implementation Review',
    ],
    _Domain.governance: [
      'Scope Definition',
      'Approval Gate',
      'Change Control',
      'Benefit Realization',
      'Stakeholder Alignment',
    ],
  };

  static String _headingFor(_Domain domain, String subject, int index) {
    final bank = _headingBanks[domain];
    if (bank == null || bank.isEmpty) return '${_variant(index)} $subject';
    if (index < bank.length) return bank[index];
    // Past the end of the bank, stay plausible instead of repeating verbatim.
    return '${bank[index % bank.length]} — ${_variant(index)} $subject';
  }

  static String _describeFor(_Domain domain, String heading) {
    switch (domain) {
      case _Domain.cost:
        return 'Cost line for $heading covering the required effort, priced at '
            'a rate benchmarked against comparable projects.';
      case _Domain.risk:
        return '$heading could affect schedule, cost, or quality if it '
            'materialises without a mitigation owner.';
      case _Domain.solution:
        return 'A $heading option that meets the objectives with a distinct '
            'cost, risk, and timeline profile.';
      case _Domain.wbs:
        return 'Deliverable scope for $heading, decomposed to work-package '
            'level with clear acceptance criteria.';
      case _Domain.schedule:
        return 'Scheduled window for $heading, sequenced against its '
            'predecessors and the critical path.';
      case _Domain.governance:
        return 'Governance expectation for $heading, with a named owner and an '
            'explicit review gate.';
      case _Domain.generic:
        return 'Working detail for $heading covering scope, delivery sequence, '
            'and acceptance criteria.';
    }
  }

  static String _rationaleFor(_Domain domain, String heading) {
    switch (domain) {
      case _Domain.cost:
        return 'Benchmarked against comparable projects; validate against '
            'current market rates.';
      case _Domain.risk:
        return 'Derived from comparable delivery failures and the current '
            'project context.';
      case _Domain.solution:
        return 'Balances cost, risk, and time-to-value against the other '
            'options considered.';
      case _Domain.wbs:
        return 'Reflects standard industry decomposition for this scope.';
      case _Domain.schedule:
        return 'Sequenced to respect lead times and dependency constraints.';
      case _Domain.governance:
        return 'Aligns with the governance baseline and approval thresholds.';
      case _Domain.generic:
        return 'Standard practice for $heading; confirm with the project team.';
    }
  }

  static String _titleCase(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed
        .split(RegExp(r'\s+'))
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  static String _slug(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  /// Stable FNV-1a hash so generated content is identical across runs and
  /// platforms (unlike `String.hashCode`, which is not guaranteed stable).
  static int _fnv1a(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit & 0xff;
      hash = (hash * 0x01000193) & 0xffffffff;
      hash ^= (unit >> 8) & 0xff;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }
}
