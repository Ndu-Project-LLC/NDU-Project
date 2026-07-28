import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ndu_project/openai/openai_config.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/models/design_phase_models.dart';
import 'package:ndu_project/models/staffing_row.dart';
import 'package:ndu_project/models/meeting_row.dart';

// Remove markdown bold markers commonly produced by the model (e.g. *text* or **text**)
String _stripAsterisks(String s) => s.replaceAll('*', '');

/// Strips markdown code fences (```json ... ```) and extracts raw JSON text.
/// OpenAI may wrap JSON responses in markdown code blocks, so this ensures
/// jsonDecode receives clean JSON.
String _extractJson(String text) {
  final codeBlockRegex = RegExp(r'```(?:json)?\s*\n?([\s\S]*?)\n?```');
  final match = codeBlockRegex.firstMatch(text);
  if (match != null) return match.group(1)?.trim() ?? text.trim();
  final jsonStart = text.indexOf('{');
  final jsonEnd = text.lastIndexOf('}');
  if (jsonStart >= 0 && jsonEnd > jsonStart) return text.substring(jsonStart, jsonEnd + 1);
  return text.trim();
}

/// Approximate USD-to-target exchange rates for AI prompt hints.
/// These are rough mid-2025 rates used ONLY to instruct the AI model to
/// convert values — they are NOT used for client-side conversion.
const Map<String, double> _usdToCurrencyRates = {
  'USD': 1.0,
  'EUR': 0.92,
  'GBP': 0.79,
  'JPY': 155.0,
  'CNY': 7.25,
  'CAD': 1.37,
  'AUD': 1.53,
  'CHF': 0.89,
  'INR': 83.5,
  'KRW': 1360.0,
  'BRL': 5.05,
  'MXN': 17.2,
  'ZAR': 18.5,
  'SGD': 1.35,
  'HKD': 7.82,
  'NOK': 10.8,
  'SEK': 10.6,
  'DKK': 6.88,
  'PLN': 4.02,
  'RUB': 92.0,
  'TRY': 32.5,
  'AED': 3.67,
  'SAR': 3.75,
  'THB': 36.2,
  'IDR': 15900.0,
  'MYR': 4.72,
  'PHP': 58.5,
  'VND': 25200.0,
  'NGN': 1550.0,
  'EGP': 48.5,
  'ILS': 3.72,
  'CZK': 23.2,
  'HUF': 365.0,
  'NZD': 1.68,
  'ZMW': 27.5,
  'PKR': 278.0,
};

/// Returns a human-readable USD-to-currency rate hint for AI prompts.
String _usdRateHint(String currency) {
  final rate = _usdToCurrencyRates[currency.toUpperCase()] ?? 1.0;
  if (rate >= 100) return rate.toStringAsFixed(0);
  if (rate >= 10) return rate.toStringAsFixed(1);
  return rate.toStringAsFixed(2);
}

/// Returns a rough converted value hint for AI prompts.
String _convertHint(double usdAmount, String currency) {
  final rate = _usdToCurrencyRates[currency.toUpperCase()] ?? 1.0;
  final converted = usdAmount * rate;
  if (converted >= 1000000) return '${(converted / 1000000).toStringAsFixed(1)}M';
  if (converted >= 1000) return converted.toStringAsFixed(0);
  return converted.toStringAsFixed(converted % 1 == 0 ? 0 : 2);
}

/// Generates a currency conversion instruction block for AI prompts.
/// When the currency is not USD, tells the AI to convert all values.
String _currencyConversionInstruction(String currency) {
  if (currency.toUpperCase() == 'USD') return '';
  final rate = _usdToCurrencyRates[currency.toUpperCase()] ?? 1.0;
  return '\n- All monetary amounts MUST be expressed in $currency. Convert from USD equivalents using realistic exchange rates (1 USD ≈ ${_usdRateHint(currency)} $currency). Do NOT simply reuse USD numerical values — $currency has a different purchasing power and exchange rate. For example, if USD amount would be 10,000, the amount in $currency should be approximately ${_convertHint(10000, currency)}. Apply this conversion to every monetary amount in your response.';
}

enum _AiProjectType { physical, digital, hybrid, service, unknown }

enum _AiProjectScale { small, medium, large }

class _ResponseFormatUnsupportedException implements Exception {
  const _ResponseFormatUnsupportedException();
}

String _nduProjectSystemPrompt({
  required String specialistRole,
  String? extraRules,
  bool strictJson = false,
}) {
  final strictJsonRule = strictJson
      ? 'Return strict JSON only and match the requested schema exactly.'
      : 'Return only the content requested for the task.';
  final extra = (extraRules ?? '').trim();
  final now = DateTime.now();
  final currentDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final currentYear = now.year;

  return '''
You are an expert project manager assistant integrated into a project management platform called NDU Project. Your role is to generate accurate, relevant, and actionable project management content based on the project's name, description, scope, and any previously entered information.

IMPORTANT — Current date context: Today is $currentDate (year $currentYear). All date-sensitive content (schedules, timelines, deadlines, fiscal periods, forecasts) MUST reference the current date ($currentDate) as the reference point. Do NOT use any older year as the current year. Always generate dates, milestones, and time-bound references relative to today ($currentDate).

Before generating content, classify BOTH:
1) Project type:
- PHYSICAL / INFRASTRUCTURE: projects that require real-world construction, procurement of materials, equipment, or physical setup.
- DIGITAL / TECHNOLOGY: projects that are primarily software, platform, or system based.
- HYBRID: projects that require both physical setup and digital systems.
- SERVICE / OPERATIONAL: projects focused on launching or improving a service, process, or organisation.
2) Delivery starting point:
- GREENFIELD (from scratch): assume this by default when context is unclear.
- BROWNFIELD (existing physical operation/site): use when context clearly indicates existing assets/facilities/processes.
- DIGITAL ENHANCEMENT ONLY: use when context explicitly says physical setup already exists and the request is mostly digital/system improvement.

Rules for every response:
1. Default to GREENFIELD/from scratch unless the context clearly indicates otherwise.
2. If the context clearly states an existing operation/facility and asks mainly for digital enablement, avoid unnecessary physical setup recommendations.
3. If the project is HYBRID, sequence recommendations realistically (physical readiness + permits/procurement where needed, then digital integration/deployment).
4. Generate practical, specific, and actionable content that reflects real-world best practices for the detected project type and starting point.
5. For physical projects, include materials, permits, site readiness, equipment, staffing, and operational setup when relevant.
6. For digital projects, include technology stack, security, hosting, requirements, testing, integration, and deployment when relevant.
7. For hybrid and service projects, cover both operational and technical realities proportionally.
8. Do not suggest IT infrastructure for a purely physical project unless the context genuinely requires it.
9. Do not suggest construction materials or physical installation steps for a purely digital project.
10. Use up-to-date, non-deprecated practices and avoid generic filler.
11. If exact product/version currency is uncertain, prefer widely adopted latest-stable practices rather than outdated or end-of-life specifics.
12. Calibrate scope, timeline, and cost realism to project scale and context.
13. Make assumptions explicit when context is incomplete.
14. FINANCIAL REALISM IS CRITICAL: All monetary values, costs, benefits, staffing rates, and savings figures MUST be grounded in real-world market data for the detected project scale and geography. Small/local businesses (barbershops, salons, food trucks) have total monthly revenues of \$2K-\$15K — any suggested benefit exceeding 15% of that is unrealistic. Mid-size enterprises have department budgets of \$50K-\$200K. Large enterprises handle \$500K-\$5M+ per initiative. NEVER suggest values that would be impossible or absurd for the business size. When in doubt, err on the conservative side.
15. STAFFING REALISM: Monthly staff costs must reflect actual market rates. For small businesses in Africa: \$800-\$3,000/mo per role. For mid-size: \$2,000-\$8,000/mo. For large enterprises: \$5,000-\$15,000/mo for senior roles. Do NOT suggest \$10,000/mo for a barbershop staff member.
16. TIMELINE REALISM: Small projects take weeks to 3 months. Medium projects take 3-9 months. Large projects take 9-24+ months. Do NOT suggest a 12-month timeline for a simple booking app or a 2-week timeline for an enterprise ERP.
17. ANTI-HALLUCINATION (CRITICAL): NEVER invent facts, figures, vendor names, technologies, regulations, or team members that are not explicitly mentioned in the project context. If the context does not contain specific data (e.g., exact budget, specific software, named individuals), generate realistic placeholder labels marked as "[TBD]" or "[To be confirmed]" rather than fabricating values. Do NOT fabricate specific dollar amounts, dates, or technical specifications that are not grounded in the provided context. When uncertain, state "Data not available in current context" instead of inventing information.
18. CONTEXT FIDELITY: When the project context provides specific data (WBS structure, cost lines, staffing, schedule dates, risk registers), use ONLY that data. Do not add extra items, reorganize the data, or supplement it with invented details unless explicitly asked to generate recommendations.
19. WBS & COST TRACEABILITY: When generating cost estimates, schedule items, or resource plans, every line item MUST trace back to a WBS deliverable or a specific project context entry. If no WBS exists yet, clearly state that the items are draft estimates pending WBS alignment. Do NOT invent deliverable names or cost categories that are not in the project data.

Your current specialist role: $specialistRole.
$strictJsonRule
${extra.isEmpty ? '' : extra}
''';
}

class AiSolutionItem {
  final String title;
  final String description;

  AiSolutionItem({required this.title, required this.description});

  factory AiSolutionItem.fromMap(Map<String, dynamic> map) => AiSolutionItem(
        title: _stripAsterisks((map['title'] ?? '').toString().trim()),
        description:
            _stripAsterisks((map['description'] ?? '').toString().trim()),
      );
}

class AiCostItem {
  final String item;
  final String description;
  final double estimatedCost;
  final double roiPercent; // percent value, e.g., 15.0 means 15%
  final Map<int, double> npvByYear;
  final double npv; // default to selected baseline (5-year when available)

  AiCostItem({
    required this.item,
    required this.description,
    required this.estimatedCost,
    required this.roiPercent,
    required Map<int, double> npvByYear,
  })  : npvByYear = Map.unmodifiable({...npvByYear}),
        npv =
            npvByYear[5] ?? (npvByYear.isNotEmpty ? npvByYear.values.first : 0);

  double npvForYear(int years) => npvByYear[years] ?? npv;

  factory AiCostItem.fromMap(Map<String, dynamic> map) {
    final Map<int, double> parsedNpvs = {};

    double toD(v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      final s = v.toString().replaceAll(',', '').replaceAll('%', '').trim();
      return double.tryParse(s) ?? 0;
    }

    void addNpv(int year, dynamic value) {
      final parsed = toD(value);
      if (parsedNpvs.containsKey(year) || parsed == 0) return;
      parsedNpvs[year] = parsed;
    }

    final npvField = map['npv'];
    if (npvField is Map) {
      for (final entry in npvField.entries) {
        final key = entry.key.toString().replaceAll(RegExp(r'[^0-9]'), '');
        final year = int.tryParse(key);
        if (year != null) addNpv(year, entry.value);
      }
    } else {
      addNpv(5, npvField);
    }

    final npvByYearsField = map['npv_by_years'];
    if (npvByYearsField is Map) {
      for (final entry in npvByYearsField.entries) {
        final key = entry.key.toString().replaceAll(RegExp(r'[^0-9]'), '');
        final year = int.tryParse(key);
        if (year != null) addNpv(year, entry.value);
      }
    }

    if (parsedNpvs.isEmpty) addNpv(5, 0);

    return AiCostItem(
      item: (map['item'] ?? map['project_item'] ?? '').toString().trim(),
      description: (map['description'] ?? '').toString().trim(),
      estimatedCost: toD(map['estimated_cost']),
      roiPercent: toD(map['roi_percent']),
      npvByYear: parsedNpvs,
    );
  }
}

class RiskMitigationRequest {
  final String id;
  final String risk;
  final String solutionTitle;

  RiskMitigationRequest({
    required this.id,
    required this.risk,
    this.solutionTitle = '',
  });
}

class AiProjectValueInsights {
  final double estimatedProjectValue;
  final Map<String, String> benefits;

  AiProjectValueInsights(
      {required this.estimatedProjectValue, required this.benefits});

  factory AiProjectValueInsights.fromMap(Map<String, dynamic> map) {
    double toD(v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      final s = v.toString().replaceAll(',', '').replaceAll('%', '').trim();
      return double.tryParse(s) ?? 0;
    }

    final estimated = toD(map['estimated_value'] ?? map['project_value']);
    final benefitsRaw = map['benefits'];
    final parsedBenefits = <String, String>{};
    if (benefitsRaw is Map) {
      for (final entry in benefitsRaw.entries) {
        parsedBenefits[entry.key.toString()] =
            _stripAsterisks(entry.value.toString());
      }
    } else if (benefitsRaw is List) {
      for (final item in benefitsRaw) {
        if (item is Map && item.containsKey('category')) {
          parsedBenefits[item['category'].toString()] = _stripAsterisks(
              (item['details'] ?? item['value'] ?? '').toString());
        }
      }
    }
    return AiProjectValueInsights(
        estimatedProjectValue: estimated, benefits: parsedBenefits);
  }
}

class AiProjectGoalRecommendation {
  final String name;
  final String description;
  final String? framework;

  AiProjectGoalRecommendation({
    required this.name,
    required this.description,
    this.framework,
  });

  factory AiProjectGoalRecommendation.fromMap(Map<String, dynamic> map) {
    final rawName = map['name'] ?? map['goal_name'] ?? map['title'] ?? '';
    final rawDesc = map['description'] ?? map['details'] ?? map['text'] ?? '';
    final rawFramework =
        map['framework'] ?? map['methodology'] ?? map['approach'] ?? '';
    final name = _stripAsterisks(rawName.toString().trim());
    final description = _stripAsterisks(rawDesc.toString().trim());
    final framework = _stripAsterisks(rawFramework?.toString().trim() ?? '');
    return AiProjectGoalRecommendation(
      name: name,
      description: description,
      framework: (framework.isEmpty) ? null : framework,
    );
  }

  factory AiProjectGoalRecommendation.fallback({
    required String name,
    required String description,
    String? framework,
  }) {
    return AiProjectGoalRecommendation(
      name: name,
      description: description,
      framework: framework,
    );
  }
}

class AiProjectFrameworkAndGoals {
  final String framework;
  final List<AiProjectGoalRecommendation> goals;

  AiProjectFrameworkAndGoals({
    required this.framework,
    required this.goals,
  });

  factory AiProjectFrameworkAndGoals.fromMap(Map<String, dynamic> map) {
    final rawFramework =
        map['framework'] ?? map['overallFramework'] ?? map['methodology'] ?? '';
    final framework = _stripAsterisks(rawFramework.toString().trim());
    final rawGoals = map['goals'];
    final parsedGoals = <AiProjectGoalRecommendation>[];
    if (rawGoals is List) {
      for (final entry in rawGoals) {
        if (entry is Map<String, dynamic>) {
          parsedGoals.add(AiProjectGoalRecommendation.fromMap(entry));
        } else if (entry is String) {
          parsedGoals.add(AiProjectGoalRecommendation(
            name: '',
            description: _stripAsterisks(entry.trim()),
            framework: framework.isEmpty ? null : framework,
          ));
        }
      }
    } else if (rawGoals is Map<String, dynamic>) {
      parsedGoals.add(AiProjectGoalRecommendation.fromMap(rawGoals));
    }

    return AiProjectFrameworkAndGoals(
      framework: framework,
      goals: parsedGoals,
    );
  }

  factory AiProjectFrameworkAndGoals.fallback(String context) {
    final projectName = _extractProjectName(context);
    final assetName = projectName.isEmpty ? 'project' : projectName;
    final descriptions = [
      'Define a governance model and stakeholder alignment for $assetName to keep priorities clear and enable timely decisions.',
      'Deliver measurable outcomes around customer experience, regulation, or operational efficiency while reinforcing transparency for $assetName.',
      'Create delivery cadences (planning, review, launch) that keep teams accountable and surface risks early during $assetName implementation.',
    ];
    const frameworkOptions = ['Agile', 'Waterfall', 'Hybrid'];
    final goals = List.generate(3, (index) {
      return AiProjectGoalRecommendation.fallback(
        name: 'Goal ${index + 1}',
        description: descriptions[index % descriptions.length],
        framework: frameworkOptions[index % frameworkOptions.length],
      );
    });
    return AiProjectFrameworkAndGoals(framework: 'Hybrid', goals: goals);
  }
}

String _extractProjectName(String context) {
  final lines = context.split('\n');
  for (final line in lines) {
    final lower = line.toLowerCase();
    if (lower.startsWith('project name:')) {
      final value = line.substring(line.indexOf(':') + 1).trim();
      if (value.isNotEmpty) return value;
    }
  }
  return '';
}

class BenefitLineItemInput {
  final String category;
  final String title;
  final double unitValue;
  final double units;
  final String notes;

  BenefitLineItemInput({
    required this.category,
    required this.title,
    required this.unitValue,
    required this.units,
    this.notes = '',
  });

  double get total => unitValue * units;

  Map<String, dynamic> toJson() => {
        'category': category,
        'category_key': category,
        'title': title,
        'unit_value': unitValue,
        'units': units,
        'total': total,
        if (notes.trim().isNotEmpty) 'notes': notes.trim(),
      };
}

class AiBenefitSavingsSuggestion {
  final String lever;
  final String recommendation;
  final double projectedSavings;
  final String timeframe;
  final String confidence;
  final String rationale;

  AiBenefitSavingsSuggestion({
    required this.lever,
    required this.recommendation,
    required this.projectedSavings,
    required this.timeframe,
    required this.confidence,
    required this.rationale,
  });

  factory AiBenefitSavingsSuggestion.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toDouble();
      final sanitized = value.toString().replaceAll(RegExp(r'[^0-9\.-]'), '');
      return double.tryParse(sanitized) ?? 0;
    }

    String parseString(dynamic value) => value?.toString().trim() ?? '';

    return AiBenefitSavingsSuggestion(
      lever: _stripAsterisks(
          parseString(map['lever'] ?? map['title'] ?? map['scenario'])),
      recommendation: _stripAsterisks(parseString(
          map['recommendation'] ?? map['action'] ?? map['strategy'])),
      projectedSavings: parseDouble(
          map['projected_savings'] ?? map['savings'] ?? map['projected_value']),
      timeframe: _stripAsterisks(
          parseString(map['timeframe'] ?? map['horizon'] ?? map['period'])),
      confidence: _stripAsterisks(parseString(
          map['confidence'] ?? map['certainty'] ?? map['confidence_level'])),
      rationale: _stripAsterisks(
          parseString(map['rationale'] ?? map['notes'] ?? map['summary'])),
    );
  }
}

class OpenAiServiceSecure {
  final http.Client _client;
  static const int maxRetries = 1;
  static const Duration retryDelay = Duration(seconds: 1);
  static const Duration _interRequestDelay = Duration(milliseconds: 120);
  static Future<void> _serializedQueue = Future<void>.value();

  OpenAiServiceSecure({http.Client? client})
      : _client = client ?? http.Client();

  Future<T> _runSerialized<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _serializedQueue = _serializedQueue.catchError((_) {}).then((_) async {
      try {
        final result = await operation();
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        await Future<void>.delayed(_interRequestDelay);
      }
    });
    return completer.future;
  }

  Future<String> generateCompletion(
    String prompt, {
    int maxTokens = 1200,
    double temperature = 0.4,
  }) async {
    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty) return '';
    if (!OpenAiConfig.isConfigured) {
      throw const OpenAiNotConfiguredException();
    }

    return _runSerialized(() async {
      final uri = OpenAiConfig.chatUri();
      final headers = OpenAiConfig.headers();

      final body = jsonEncode(OpenAiConfig.wrapBody({
        'model': OpenAiConfig.model,
        'temperature': temperature,
        'max_completion_tokens': maxTokens,
        'messages': [
          {
            'role': 'system',
            'content': _nduProjectSystemPrompt(
              specialistRole:
                  'project planning assistant producing concise text output',
              extraRules:
                  'Follow the user request exactly and keep wording practical and specific.',
            ),
          },
          {'role': 'user', 'content': trimmedPrompt},
        ],
      }));

      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      return content.trim();
    });
  }

  // Generate a concise section text for Front End Planning pages based on full project context.
  // Returns a rich paragraph suitable for a multi-line TextField. If API is not configured,
  // falls back to a short heuristic summary from the provided context.
  Future<String> generateFepSectionText({
    required String section,
    required String context,
    int maxTokens = 900,
    double temperature = 0.5,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) return '';
    if (!OpenAiConfig.isConfigured) {
      throw const OpenAiNotConfiguredException();
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final prompt = _fepSectionPrompt(section: section, context: trimmedContext);
    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'senior delivery planner drafting crisp, actionable section write-ups',
            strictJson: true,
          ),
        },
        {
          'role': 'user',
          'content': prompt,
        }
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 14));
      if (response.statusCode == 401) throw Exception('Invalid API key');
      if (response.statusCode == 429) throw Exception('API quota exceeded');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;
      final text =
          (parsed['text'] ?? parsed['section'] ?? parsed['content'] ?? '')
              .toString()
              .trim();
      final cleanText = _stripAsterisks(text);
      if (cleanText.isNotEmpty) return cleanText;
      // If missing expected key, try to flatten other fields to text
      if (parsed.isNotEmpty) {
        return parsed.values
            .map((v) => _stripAsterisks(v.toString()))
            .join('\n')
            .trim();
      }
      return '';
    } catch (e) {
      // Surface the error to callers so the UI can show a clear failure state
      rethrow;
    }
  }

  /// Rewrite / polish an existing block of text using the project context.
  /// The AI is instructed to:
  ///   - fix grammar, spelling, and punctuation
  ///   - tighten wording without changing meaning
  ///   - preserve the user's intent and any technical terms / proper nouns
  ///   - keep the original tone (professional, neutral)
  ///   - return ONLY the rewritten text in JSON: `{"text": "..."}`
  Future<String> rewriteExistingText({
    required String section,
    required String currentText,
    required String projectContext,
    int maxTokens = 900,
    double temperature = 0.4,
  }) async {
    final trimmedText = currentText.trim();
    if (trimmedText.isEmpty) return '';
    if (!OpenAiConfig.isConfigured) {
      throw const OpenAiNotConfiguredException();
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final prompt = '''
You are a senior editor for an enterprise project management workspace. Rewrite the user's existing text for the "$section" section so that it is clearer, more professional, and grammatically correct.

Rules:
- Preserve the user's intent and meaning. Do NOT introduce new facts not present in the original text or project context.
- Keep all proper nouns, technical terms, numbers, dates, and acronyms exactly as written.
- Tighten wordy phrasing and fix grammar, spelling, and punctuation.
- Keep the tone professional and neutral.
- Do NOT add headers, bullet markers, or formatting that wasn't in the original unless needed for clarity.
- Return ONLY valid JSON: {"text": "<rewritten text here>"}

Project context (for reference only — do not invent):
"""
${_escape(projectContext)}
"""

Original text to rewrite:
"""
${_escape(trimmedText)}
"""
''';

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'senior editor polishing user-written project documentation',
            strictJson: true,
            extraRules:
                'Preserve the user\'s voice and intent. Make minimal, high-value edits.',
          ),
        },
        {
          'role': 'user',
          'content': prompt,
        }
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 14));
      if (response.statusCode == 401) throw Exception('Invalid API key');
      if (response.statusCode == 429) throw Exception('API quota exceeded');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content = OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;
      final text = (parsed['text'] ??
              parsed['section'] ??
              parsed['content'] ??
              '')
          .toString()
          .trim();
      final cleanText = _stripAsterisks(text);
      return cleanText;
    } catch (e) {
      rethrow;
    }
  }

  Future<QualitySeedBundle> generateQualitySeedBundle({
    required String context,
    required String section,
    int maxTokens = 1200,
    double temperature = 0.45,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) {
      return QualitySeedBundle.empty();
    }
    if (!OpenAiConfig.isConfigured) {
      return _fallbackQualitySeedBundle(trimmedContext, section);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a quality management specialist. Generate realistic, actionable QA/QC planning data and return only JSON matching the requested schema.'
        },
        {
          'role': 'user',
          'content':
              _qualitySeedPrompt(section: section, context: trimmedContext),
        }
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 401) throw Exception('Invalid API key');
      if (response.statusCode == 429) throw Exception('API quota exceeded');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = _decodeJsonSafely(content);
      if (parsed == null) {
        return _fallbackQualitySeedBundle(trimmedContext, section);
      }

      final standards = _parseQualityStandards(parsed['standards']);
      final objectives = _parseQualityObjectives(parsed['objectives']);
      final workflowControls =
          _parseQualityWorkflowControls(parsed['workflowControls']);
      final audits = _parseQualityAuditPlan(parsed['auditPlan']);

      final dashboardRaw =
          (parsed['dashboardConfig'] is Map) ? parsed['dashboardConfig'] : {};
      final kpiRaw = (parsed['kpiTargets'] is Map) ? parsed['kpiTargets'] : {};
      final targetRaw = (dashboardRaw is Map &&
              dashboardRaw['targetTimeToResolutionDays'] != null)
          ? dashboardRaw['targetTimeToResolutionDays']
          : kpiRaw['targetTimeToResolutionDays'];
      final targetDays = _toDouble(targetRaw);

      return QualitySeedBundle(
        standards: standards,
        objectives: objectives,
        workflowControls: workflowControls,
        auditPlan: audits,
        dashboardConfig: QualityDashboardConfig(
          targetTimeToResolutionDays: targetDays <= 0 ? 15 : targetDays,
          allowManualMetricsOverride: true,
          maxTrendPoints: 12,
        ),
      );
    } catch (e) {
      debugPrint('generateQualitySeedBundle failed: $e');
      return _fallbackQualitySeedBundle(trimmedContext, section);
    }
  }

  List<Map<String, dynamic>> _asMapList(dynamic raw) {
    if (raw is! List) return const [];
    final result = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is Map) {
        result.add(Map<String, dynamic>.from(item));
      }
    }
    return result;
  }

  List<QualityStandard> _parseQualityStandards(dynamic raw) {
    return _asMapList(raw)
        .map((entry) {
          return QualityStandard(
            id: (entry['id'] ?? DateTime.now().microsecondsSinceEpoch)
                .toString(),
            name: _stripAsterisks(
                (entry['name'] ?? entry['standard'] ?? '').toString().trim()),
            source: _stripAsterisks(
                (entry['source'] ?? entry['framework'] ?? '')
                    .toString()
                    .trim()),
            category:
                _stripAsterisks((entry['category'] ?? '').toString().trim()),
            description:
                _stripAsterisks((entry['description'] ?? '').toString().trim()),
            applicability: _stripAsterisks(
                (entry['applicability'] ?? entry['appliesTo'] ?? '')
                    .toString()
                    .trim()),
          );
        })
        .where((s) => s.name.isNotEmpty)
        .toList();
  }

  List<QualityObjective> _parseQualityObjectives(dynamic raw) {
    return _asMapList(raw)
        .map((entry) {
          return QualityObjective(
            id: (entry['id'] ?? DateTime.now().microsecondsSinceEpoch)
                .toString(),
            title: _stripAsterisks(
                (entry['title'] ?? entry['objective'] ?? '').toString().trim()),
            acceptanceCriteria: _stripAsterisks(
                (entry['acceptanceCriteria'] ?? entry['criteria'] ?? '')
                    .toString()
                    .trim()),
            successMetric: _stripAsterisks(
                (entry['successMetric'] ?? entry['metric'] ?? '')
                    .toString()
                    .trim()),
            targetValue: _stripAsterisks(
                (entry['targetValue'] ?? entry['target'] ?? '')
                    .toString()
                    .trim()),
            currentValue: _stripAsterisks(
                (entry['currentValue'] ?? '').toString().trim()),
            owner: _stripAsterisks((entry['owner'] ?? '').toString().trim()),
            linkedRequirement: _stripAsterisks(
                (entry['linkedRequirement'] ?? '').toString().trim()),
            linkedWbs:
                _stripAsterisks((entry['linkedWbs'] ?? '').toString().trim()),
            status:
                _stripAsterisks((entry['status'] ?? 'Draft').toString().trim()),
          );
        })
        .where((o) => o.title.isNotEmpty)
        .toList();
  }

  List<QualityWorkflowControl> _parseQualityWorkflowControls(dynamic raw) {
    return _asMapList(raw)
        .map((entry) {
          return QualityWorkflowControl(
            id: (entry['id'] ?? DateTime.now().microsecondsSinceEpoch)
                .toString(),
            type: _parseWorkflowType(entry['type']),
            name: _stripAsterisks((entry['name'] ?? '').toString().trim()),
            method: _stripAsterisks((entry['method'] ?? '').toString().trim()),
            tools: _stripAsterisks((entry['tools'] ?? '').toString().trim()),
            checklist:
                _stripAsterisks((entry['checklist'] ?? '').toString().trim()),
            frequency:
                _stripAsterisks((entry['frequency'] ?? '').toString().trim()),
            owner: _stripAsterisks((entry['owner'] ?? '').toString().trim()),
            standardsReference: _stripAsterisks(
                (entry['standardsReference'] ?? '').toString().trim()),
          );
        })
        .where((w) => w.name.isNotEmpty)
        .toList();
  }

  List<QualityAuditEntry> _parseQualityAuditPlan(dynamic raw) {
    return _asMapList(raw)
        .map((entry) {
          return QualityAuditEntry(
            id: (entry['id'] ?? DateTime.now().microsecondsSinceEpoch)
                .toString(),
            title: _stripAsterisks((entry['title'] ?? '').toString().trim()),
            scope: _stripAsterisks((entry['scope'] ?? '').toString().trim()),
            plannedDate:
                _stripAsterisks((entry['plannedDate'] ?? '').toString().trim()),
            completedDate: _stripAsterisks(
                (entry['completedDate'] ?? '').toString().trim()),
            owner: _stripAsterisks((entry['owner'] ?? '').toString().trim()),
            result: _parseAuditResultStatus(entry['result']),
            findings:
                _stripAsterisks((entry['findings'] ?? '').toString().trim()),
            notes: _stripAsterisks((entry['notes'] ?? '').toString().trim()),
          );
        })
        .where((a) => a.title.isNotEmpty)
        .toList();
  }

  String _normalizeQualityToken(dynamic raw) {
    return raw
            ?.toString()
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[\s_-]+'), '') ??
        '';
  }

  QualityWorkflowType _parseWorkflowType(dynamic raw) {
    final token = _normalizeQualityToken(raw);
    if (token == 'qc' || token == 'qualitycontrol') {
      return QualityWorkflowType.qc;
    }
    return QualityWorkflowType.qa;
  }

  AuditResultStatus _parseAuditResultStatus(dynamic raw) {
    final token = _normalizeQualityToken(raw);
    switch (token) {
      case 'pass':
      case 'passed':
        return AuditResultStatus.pass;
      case 'conditional':
      case 'warning':
        return AuditResultStatus.conditional;
      case 'fail':
      case 'failed':
        return AuditResultStatus.fail;
      default:
        return AuditResultStatus.pending;
    }
  }

  QualitySeedBundle _fallbackQualitySeedBundle(String context, String section) {
    final scopeTag = section.trim().isEmpty ? 'Project' : section.trim();
    return QualitySeedBundle(
      standards: [
        QualityStandard(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: 'ISO 9001-aligned process controls',
          source: 'ISO 9001',
          category: 'Quality Management',
          description:
              'Define process ownership, documented procedures, and recurring audits.',
          applicability: scopeTag,
        ),
        QualityStandard(
          id: DateTime.now()
              .add(const Duration(microseconds: 1))
              .microsecondsSinceEpoch
              .toString(),
          name: 'Project acceptance criteria governance',
          source: 'Stakeholder requirements',
          category: 'Acceptance',
          description:
              'Maintain measurable acceptance criteria per deliverable and verify before sign-off.',
          applicability: scopeTag,
        ),
      ],
      objectives: [
        QualityObjective(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: 'Reduce defect leakage',
          acceptanceCriteria:
              'Defects identified in QA are resolved before release gates.',
          successMetric: 'Defect leakage rate',
          targetValue: '< 5%',
          currentValue: '',
          owner: '',
          linkedRequirement: '',
          linkedWbs: '',
          status: 'Draft',
        ),
        QualityObjective(
          id: DateTime.now()
              .add(const Duration(microseconds: 1))
              .microsecondsSinceEpoch
              .toString(),
          title: 'Improve audit readiness',
          acceptanceCriteria:
              'All planned quality audits executed and documented on schedule.',
          successMetric: 'Planned audit completion',
          targetValue: '100%',
          currentValue: '',
          owner: '',
          linkedRequirement: '',
          linkedWbs: '',
          status: 'Draft',
        ),
      ],
      workflowControls: [
        QualityWorkflowControl(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          type: QualityWorkflowType.qa,
          name: 'Peer review and checklist verification',
          method: 'Review deliverables against agreed standards and templates',
          tools: 'Review checklist, issue log',
          checklist: 'Definition of done + quality checklist',
          frequency: 'Weekly',
          owner: '',
          standardsReference: 'ISO 9001, project QA guide',
        ),
        QualityWorkflowControl(
          id: DateTime.now()
              .add(const Duration(microseconds: 1))
              .microsecondsSinceEpoch
              .toString(),
          type: QualityWorkflowType.qc,
          name: 'Inspection and audit sampling',
          method: 'Inspect completed outputs and run quality audits',
          tools: 'Inspection sheets, audit logs',
          checklist: 'QC inspection criteria',
          frequency: 'Bi-weekly',
          owner: '',
          standardsReference: 'Internal QC protocol',
        ),
      ],
      auditPlan: [
        QualityAuditEntry(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: 'Requirements quality audit',
          scope: 'Requirements and acceptance criteria completeness',
          plannedDate: '',
          completedDate: '',
          owner: '',
          result: AuditResultStatus.pending,
          findings: '',
          notes:
              'Seeded from project context: ${_excerpt(_stripAsterisks(context), 120)}',
        ),
      ],
      dashboardConfig: const QualityDashboardConfig(
        targetTimeToResolutionDays: 15,
        allowManualMetricsOverride: true,
        maxTrendPoints: 12,
      ),
    );
  }

  /// Analyzes current quality data and provides AI-powered recommendations
  Future<QualityAiAnalysis> analyzeQualityGaps({
    required String context,
    required QualityManagementData currentQuality,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) {
      return QualityAiAnalysis.empty();
    }
    if (!OpenAiConfig.isConfigured) {
      return QualityAiAnalysis.fallback();
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final currentState = [
      'CURRENT QUALITY STATE:',
      '- Objectives: ${currentQuality.objectives.length} defined',
      '- Standards: ${currentQuality.standards.length} listed',
      '- Workflow Controls: ${currentQuality.workflowControls.length}',
      '- Audit Entries: ${currentQuality.auditPlan.length} planned',
      '- Corrective Actions: ${currentQuality.correctiveActions.length}',
      '',
      'ANALYSIS REQUESTED:',
      '1. Identify missing quality requirements or gaps',
      '2. Recommend quality activities based on project type',
      '3. Suggest applicable standards and best practices',
      '4. Detect gaps in acceptance criteria',
      '5. Highlight quality risks and likely sources of rework',
      '6. Recommend quality KPIs specific to this project',
    ].join('\n');

    final fullContext = '$context\n\n$currentState';

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': 0.4,
      'max_completion_tokens': 1500,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': 'You are an expert Quality Management consultant. Analyze quality data and provide actionable recommendations. Return ONLY valid JSON.'
        },
        {
          'role': 'user',
          'content': fullContext,
        }
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 45));
      if (response.statusCode == 401) throw Exception('Invalid API key');
      if (response.statusCode == 429) throw Exception('API quota exceeded');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('OpenAI error ${response.statusCode}: ${response.body}');
      }

      final parsed = jsonDecode(response.body);
      return QualityAiAnalysis.fromJson(parsed);
    } catch (e) {
      debugPrint('analyzeQualityGaps failed: $e');
      return QualityAiAnalysis.fallback();
    }
  }


  // Generate structured Scope items (Within Scope, Out of Scope)
  Future<Map<String, List<String>>> generateProjectScope({
    required String context,
    int maxTokens = 800,
    double temperature = 0.5,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) return {'in': [], 'out': []};
    if (!OpenAiConfig.isConfigured) return {'in': [], 'out': []};

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a senior project manager. Extract or generate a list of "Within Scope" and "Out of Scope" items based on the project context. Return JSON with keys "within_scope" and "out_of_scope" as arrays of strings.'
        },
        {
          'role': 'user',
          'content': 'Project Context:\n$trimmedContext',
        }
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 14));
      if (response.statusCode >= 300) return {'in': [], 'out': []};

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;

      List<String> toList(dynamic val) {
        if (val is List) {
          return val.map((e) => _stripAsterisks(e.toString())).toList();
        }
        return [];
      }

      return {
        'in': toList(parsed['within_scope']),
        'out': toList(parsed['out_of_scope']),
      };
    } catch (e) {
      debugPrint('Error generating scope: $e');
      return {'in': [], 'out': []};
    }
  }

  // Generate structured Risks and Constraints
  Future<Map<String, dynamic>> generateDetailedRisks({
    required String context,
    int maxTokens = 1000,
    double temperature = 0.5,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) return {'risks': [], 'constraints': []};
    if (!OpenAiConfig.isConfigured) return {'risks': [], 'constraints': []};

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a risk manager. Identify key risks (with impact/mitigation) and constraints. Return JSON with "risks": [{ "name": "...", "impact": "High/Medium/Low", "mitigation": "..." }] and "constraints": ["..."].'
        },
        {
          'role': 'user',
          'content': 'Project Context:\n$trimmedContext',
        }
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 14));
      if (response.statusCode >= 300) return {'risks': [], 'constraints': []};

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;

      List<RiskRegisterItem> risks = [];
      if (parsed['risks'] is List) {
        risks = (parsed['risks'] as List).map((r) {
          final map = r as Map<String, dynamic>;
          return RiskRegisterItem(
            riskName: _stripAsterisks(map['name']?.toString() ?? ''),
            impactLevel: _stripAsterisks(map['impact']?.toString() ?? 'Medium'),
            mitigationStrategy:
                _stripAsterisks(map['mitigation']?.toString() ?? ''),
          );
        }).toList();
      }

      List<String> constraints = [];
      if (parsed['constraints'] is List) {
        constraints = (parsed['constraints'] as List)
            .map((e) => _stripAsterisks(e.toString()))
            .toList();
      }

      return {'risks': risks, 'constraints': constraints};
    } catch (e) {
      debugPrint('Error generating risks: $e');
      return {'risks': [], 'constraints': []};
    }
  }

  Future<Map<String, String>> generateRiskMitigationPlans({
    required List<RiskMitigationRequest> risks,
    required String context,
    int maxTokens = 900,
    double temperature = 0.5,
  }) async {
    final trimmedRisks = risks
        .map((r) => RiskMitigationRequest(
            id: r.id,
            risk: r.risk.trim(),
            solutionTitle: r.solutionTitle.trim()))
        .where((r) => r.risk.isNotEmpty)
        .toList();

    if (trimmedRisks.isEmpty) return {};

    if (!OpenAiConfig.isConfigured) {
      return _fallbackMitigationPlans(trimmedRisks);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final prompt = _buildMitigationPrompt(trimmedRisks, context);

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a pragmatic project risk manager. Provide a concise mitigation plan for each supplied risk. Return only a JSON object with key "mitigations" whose value is an array of objects containing "id" and "plan".'
        },
        {
          'role': 'user',
          'content': prompt,
        }
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 14));
      if (response.statusCode >= 300) {
        return _fallbackMitigationPlans(trimmedRisks);
      }

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;

      final mitigations = <String, String>{};
      if (parsed['mitigations'] is List) {
        for (final item in parsed['mitigations'] as List) {
          if (item is Map) {
            final id = item['id']?.toString();
            final plan = _stripAsterisks(item['plan']?.toString() ?? '');
            if (id != null && plan.trim().isNotEmpty) {
              mitigations[id] = plan.trim();
            }
          }
        }
      }
      return mitigations.isEmpty
          ? _fallbackMitigationPlans(trimmedRisks)
          : mitigations;
    } catch (e) {
      debugPrint('generateRiskMitigationPlans failed: $e');
      return _fallbackMitigationPlans(trimmedRisks);
    }
  }

  String _buildMitigationPrompt(
    List<RiskMitigationRequest> risks,
    String context,
  ) {
    final buffer = StringBuffer();
    if (context.trim().isNotEmpty) {
      buffer.writeln('Project context:');
      buffer.writeln(context.trim());
      buffer.writeln();
    }
    buffer.writeln('Risks requiring mitigation:');
    for (final risk in risks) {
      buffer.writeln('- ID: ${risk.id}');
      if (risk.solutionTitle.isNotEmpty) {
        buffer.writeln('  Solution: ${risk.solutionTitle}');
      }
      buffer.writeln('  Risk: ${risk.risk}');
    }
    buffer.writeln();
    buffer.writeln(
        'For each risk, provide one practical plan that outlines the immediate mitigation steps, ownership, and cadence.');
    return buffer.toString();
  }

  Map<String, String> _fallbackMitigationPlans(
      List<RiskMitigationRequest> risks) {
    final fallback = <String, String>{};
    for (final risk in risks) {
      final base = risk.risk.isNotEmpty ? risk.risk : 'the listed risk';
      fallback[risk.id] =
          'Document mitigation actions for "$base", assign an owner, and monitor progress weekly.';
    }
    return fallback;
  }

  // Generate Technical Requirements (IT and Infra)
  Future<Map<String, dynamic>> generateTechnicalRequirements({
    required String context,
    int maxTokens = 1000,
    double temperature = 0.5,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) return {};
    if (!OpenAiConfig.isConfigured) return {};

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a technical architect. Identify IT and Infrastructure requirements. Return JSON with "it": { "hardware": "...", "software": "...", "network": "..." } and "infra": { "space": "...", "power": "...", "connectivity": "..." }.'
        },
        {
          'role': 'user',
          'content': 'Project Context:\n$trimmedContext',
        }
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 14));
      if (response.statusCode >= 300) return {};

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;

      final itMap = parsed['it'] as Map<String, dynamic>? ?? {};
      final infraMap = parsed['infra'] as Map<String, dynamic>? ?? {};

      final it = ITConsiderationsData(
        hardwareRequirements:
            _stripAsterisks(itMap['hardware']?.toString() ?? ''),
        softwareRequirements:
            _stripAsterisks(itMap['software']?.toString() ?? ''),
        networkRequirements:
            _stripAsterisks(itMap['network']?.toString() ?? ''),
      );

      final infra = InfrastructureConsiderationsData(
        physicalSpaceRequirements:
            _stripAsterisks(infraMap['space']?.toString() ?? ''),
        powerCoolingRequirements:
            _stripAsterisks(infraMap['power']?.toString() ?? ''),
        connectivityRequirements:
            _stripAsterisks(infraMap['connectivity']?.toString() ?? ''),
      );

      return {'it': it, 'infra': infra};
    } catch (e) {
      debugPrint('Error generating tech reqs: $e');
      return {};
    }
  }

  // Generate structured planning items (Scope, Assumptions, Constraints)
  Future<List<PlanningDashboardItem>> generatePlanningItems({
    required String section,
    required String context,
    int maxTokens = 1000,
    double temperature = 0.5,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) return [];

    if (!OpenAiConfig.isConfigured) {
      return _planningItemsFallback(section, trimmedContext);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final prompt = '''
You are a senior project manager. Based on the project context below, generate a list of specific, actionable items for the "$section" section.
Return ONLY a JSON object with a single key "items", which is a list of objects. Each object must have:
- "description": A clear, concise statement (max 20 words).
- "title": A short 3-5 word summary (optional, can be empty).

Context:
$trimmedContext

Rules:
- Generate 3-7 high-quality items.
- Focus on specific details relevant to the project type, not generic statements.
- For "Within Scope": lists specific deliverables.
- For "Out of Scope": lists specific exclusions.
- For "Assumptions": lists key dependencies or conditions.
- For "Constraints": lists budget, timeline, or resource limitations.
''';

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'project planning analyst generating scope and planning entries',
            strictJson: true,
            extraRules:
                'Return only a JSON object that matches the requested schema.',
          ),
        },
        {'role': 'user', 'content': prompt}
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;

      final rawItems = parsed['items'] as List?;
      if (rawItems == null) return [];

      final generated = rawItems.map((item) {
        final map = item as Map<String, dynamic>;
        return PlanningDashboardItem(
          title: _stripAsterisks((map['title'] ?? '').toString()),
          description: _stripAsterisks((map['description'] ?? '').toString()),
          isAiGenerated: true,
        );
      }).toList();

      return _normalizePlanningItems(generated, section: section);
    } catch (e) {
      debugPrint('Error generating planning items: $e');
      return _normalizePlanningItems(
        _planningItemsFallback(section, trimmedContext),
        section: section,
      );
    }
  }

  /// Generate a concise AI project objective summary (max 5 sentences).
  Future<String> generateProjectObjectiveSummary({
    required String context,
    int maxTokens = 360,
    double temperature = 0.4,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) return '';
    if (!OpenAiConfig.isConfigured) return '';

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final prompt = '''
You are a senior project planning assistant. Using the project context below, write a concise project objective summary.
Requirements:
- 3 to 5 complete sentences, maximum 5 sentences.
- No bullet points or numbering.
- Focus on measurable actions and targets required to accomplish the project.
- Reference goals, milestones, scope, and constraints when relevant.
- Use clear, direct language.

Context:
$trimmedContext

Return ONLY valid JSON: {"objective": "..." }
''';

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a project planning assistant. Return only valid JSON.'
        },
        {'role': 'user', 'content': prompt},
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;
      final objective = _stripAsterisks(
        (parsed['objective'] ?? '').toString().trim(),
      );
      return objective;
    } catch (e) {
      debugPrint('Error generating project objective summary: $e');
      return '';
    }
  }

  // Generate structured execution plan fields for plan input cards.
  Future<Map<String, String>> generateExecutionPlanSectionFields({
    required String section,
    required String context,
    required Map<String, String> fields,
    int maxTokens = 900,
    double temperature = 0.4,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty || fields.isEmpty) return {};
    if (!OpenAiConfig.isConfigured) return {};

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final fieldLines = fields.entries
        .map((entry) => '- ${entry.key}: ${entry.value}'.trim())
        .join('\n');

    final prompt = '''
You are a senior project delivery planner. Fill in the execution plan inputs for "$section".
Return ONLY a valid JSON object with keys exactly matching the field keys below.
Each value should be 1-3 concise sentences (max 40 words) using concrete, actionable details.
Avoid bullet lists, headings, or repeating the label.

Field keys and guidance:
$fieldLines

Project Context:
$trimmedContext
''';

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'execution planning specialist generating structured execution section inputs',
            strictJson: true,
            extraRules:
                'Return only a JSON object with keys exactly matching the requested field keys.',
          ),
        },
        {'role': 'user', 'content': prompt},
      ],
    }));

    String normalize(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      if (value is List) {
        return value.map((e) => e.toString()).join(' ');
      }
      if (value is Map) {
        return value.values.map((e) => e.toString()).join(' ');
      }
      return value.toString();
    }

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;

      final rawFields = parsed['fields'] is Map
          ? (parsed['fields'] as Map).cast<String, dynamic>()
          : parsed;

      final results = <String, String>{};
      for (final key in fields.keys) {
        final value = rawFields[key];
        final text = _stripAsterisks(normalize(value)).trim();
        if (text.isNotEmpty) {
          results[key] = text;
        }
      }

      return results;
    } catch (e) {
      debugPrint('Error generating execution plan fields: $e');
      return {};
    }
  }

  String _normalizePlanningText(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  String _defaultPlanningTitle(String section, String description) {
    final lower = description.toLowerCase();

    if (section.contains('Within Scope')) return 'Scope Deliverable';
    if (section.contains('Out of Scope')) return 'Scope Exclusion';
    if (section.contains('Assumptions')) return 'Planning Assumption';
    if (section.contains('Project Objectives')) return 'Project Objective';
    if (section.contains('Success Criteria')) return 'Success Criterion';
    if (section.contains('Constraints')) {
      if (lower.contains('budget')) return 'Budget Constraint';
      if (lower.contains('timeline') || lower.contains('schedule')) {
        return 'Schedule Constraint';
      }
      if (lower.contains('resource')) return 'Resource Constraint';
      if (lower.contains('compliance') || lower.contains('regulator')) {
        return 'Compliance Constraint';
      }
      return 'Project Constraint';
    }

    final words = _normalizePlanningText(description)
        .split(' ')
        .where((word) => word.isNotEmpty)
        .take(4)
        .toList();
    return words.isEmpty ? section : words.join(' ');
  }

  List<PlanningDashboardItem> _normalizePlanningItems(
    List<PlanningDashboardItem> items, {
    required String section,
  }) {
    final seen = <String>{};
    final normalized = <PlanningDashboardItem>[];

    for (final item in items) {
      final description = _normalizePlanningText(item.description);
      if (description.isEmpty) continue;
      final title = _normalizePlanningText(item.title);
      final resolvedTitle =
          title.isEmpty ? _defaultPlanningTitle(section, description) : title;

      final signature = description.toLowerCase();
      if (!seen.add(signature)) continue;

      normalized.add(
        PlanningDashboardItem(
          id: item.id,
          title: resolvedTitle,
          description: description,
          createdAt: item.createdAt,
          isAiGenerated: item.isAiGenerated,
        ),
      );
    }

    return normalized;
  }

  bool _containsAnyKeyword(String context, List<RegExp> patterns) {
    for (final pattern in patterns) {
      if (pattern.hasMatch(context)) {
        return true;
      }
    }
    return false;
  }

  List<PlanningDashboardItem> _planningItemsFallback(
      String section, String context) {
    final lowerContext = context.toLowerCase();
    final isBakery = _containsAnyKeyword(lowerContext, [
      RegExp(r'\bbakery\b'),
      RegExp(r'\bfood\b'),
      RegExp(r'\brestaurant\b'),
      RegExp(r'\bcafe\b'),
      RegExp(r'\bkitchen\b'),
    ]);
    final isTech = _containsAnyKeyword(lowerContext, [
      RegExp(r'\bsoftware\b'),
      RegExp(r'\bapplication\b'),
      RegExp(r'\bmobile app\b'),
      RegExp(r'\bweb app\b'),
      RegExp(r'\bplatform\b'),
      RegExp(r'\bapi\b'),
      RegExp(r'\bdatabase\b'),
    ]);

    var suggestions = <Map<String, String>>[];

    if (section.contains('Within Scope')) {
      if (isBakery) {
        suggestions = [
          {
            'title': 'Kitchen Setup',
            'description': 'Kitchen equipment procurement and installation'
          },
          {
            'title': 'Interior Setup',
            'description': 'Interior design and seating area setup'
          },
          {
            'title': 'Menu Development',
            'description': 'Menu development, recipe trials, and tasting'
          },
          {
            'title': 'Staff Readiness',
            'description': 'Staff hiring, onboarding, and training program'
          },
          {
            'title': 'Safety Compliance',
            'description': 'Health and safety inspection compliance'
          },
        ];
      } else if (isTech) {
        suggestions = [
          {
            'title': 'User Management',
            'description': 'User authentication and profile management'
          },
          {
            'title': 'MVP Features',
            'description': 'Core feature implementation for MVP launch'
          },
          {
            'title': 'Data Layer',
            'description': 'Database schema design and setup'
          },
          {
            'title': 'Integrations',
            'description': 'API integration with third-party services'
          },
          {
            'title': 'Quality Assurance',
            'description': 'Unit and integration testing'
          },
        ];
      } else {
        suggestions = [
          {
            'title': 'Planning Phase',
            'description': 'Project initiation and planning activities'
          },
          {
            'title': 'Requirements',
            'description': 'Requirement gathering and analysis'
          },
          {
            'title': 'Design',
            'description': 'Design and prototyping deliverables'
          },
          {
            'title': 'Implementation',
            'description': 'Implementation and development work'
          },
          {
            'title': 'Handover',
            'description': 'Final delivery and operational handover'
          },
        ];
      }
    } else if (section.contains('Out of Scope')) {
      suggestions = [
        {
          'title': 'Marketing Activities',
          'description': 'Post-launch marketing campaigns'
        },
        {
          'title': 'Long-Term Support',
          'description': 'Long-term maintenance support under separate contract'
        },
        {
          'title': 'Unapproved Features',
          'description': 'Features not explicitly listed in the requirements'
        },
        {
          'title': 'Client Procurement',
          'description': 'Hardware procurement handled by client'
        },
      ];
    } else if (section.contains('Assumptions')) {
      suggestions = [
        {
          'title': 'Client Inputs',
          'description': 'Client provides content and branding assets on time'
        },
        {
          'title': 'Approvals',
          'description':
              'Regulatory approvals are obtained within standard timelines'
        },
        {
          'title': 'Stakeholder Access',
          'description': 'Key stakeholders are available for weekly reviews'
        },
        {
          'title': 'Funding',
          'description': 'Budget approval is secured before phase two'
        },
      ];
    } else if (section.contains('Constraints')) {
      suggestions = [
        {
          'title': 'Budget Constraint',
          'description': 'Budget is fixed at the initial estimate'
        },
        {
          'title': 'Schedule Constraint',
          'description': 'Timeline must meet the target launch window'
        },
        {
          'title': 'Resource Constraint',
          'description': 'Availability of specialized resources is limited'
        },
        {
          'title': 'Compliance Constraint',
          'description':
              'Execution must comply with local regulatory requirements'
        },
      ];
    } else if (section.contains('Project Objectives')) {
      suggestions = [
        {
          'title': 'Delivery Objective',
          'description':
              'Deliver the defined scope within approved timeline and budget'
        },
        {
          'title': 'Quality Objective',
          'description':
              'Meet acceptance criteria with minimal rework at handover'
        },
        {
          'title': 'Adoption Objective',
          'description':
              'Enable stakeholder readiness through training and transition support'
        },
      ];
    } else if (section.contains('Success Criteria')) {
      suggestions = [
        {
          'title': 'Schedule Performance',
          'description': 'Key milestones are completed by planned target dates'
        },
        {
          'title': 'Budget Performance',
          'description': 'Total spend remains within approved budget baseline'
        },
        {
          'title': 'Quality Performance',
          'description':
              'Final deliverables pass acceptance checks without critical defects'
        },
      ];
    }

    final fallbackItems = suggestions
        .map(
          (entry) => PlanningDashboardItem(
            title: entry['title'] ?? '',
            description: entry['description'] ?? '',
            isAiGenerated: true,
          ),
        )
        .toList();

    return _normalizePlanningItems(fallbackItems, section: section);
  }

  Future<DesignDeliverablesData> generateDesignDeliverables({
    required String context,
    int maxTokens = 1200,
    double temperature = 0.4,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) {
      return const DesignDeliverablesData();
    }

    if (!OpenAiConfig.isConfigured) {
      // Fallback
      return const DesignDeliverablesData(
        pipeline: [
          DesignDeliverablePipelineItem(
              label: 'Scope baseline and design inputs verified',
              status: 'In progress'),
          DesignDeliverablePipelineItem(
              label:
                  'Design package authored with traceable acceptance criteria',
              status: 'Pending'),
          DesignDeliverablePipelineItem(
              label: 'Review, approval, and handoff evidence completed',
              status: 'Pending'),
        ],
        register: [
          DesignDeliverableRegisterItem(
              name: 'DD-001 Requirements Traceability & Acceptance Matrix',
              owner: 'Business Analyst',
              status: 'In progress',
              due: 'Gate 1',
              risk: 'Medium'),
          DesignDeliverableRegisterItem(
              name: 'DD-002 Architecture Decision Pack & Solution Intent',
              owner: 'Architecture',
              status: 'In review',
              due: 'Build Readiness',
              risk: 'Medium'),
          DesignDeliverableRegisterItem(
              name: 'DD-003 Interface, Data, Security & NFR Design Spec',
              owner: 'Engineering',
              status: 'Pending',
              due: 'Transition Gate',
              risk: 'High'),
        ],
        approvals: [
          'Formal approval requires acceptance criteria, verification evidence, and accountable approver.',
          'Agile approval requires Definition of Done, sprint review evidence, and backlog traceability.'
        ],
        dependencies: [
          'Requirements baseline, architecture decisions, interface contracts, and design system assets.',
          'Quality, security, accessibility, and operational handoff reviewers.'
        ],
        handoffChecklist: [
          'Deliverable is versioned, traceable, reviewed, and linked to acceptance evidence.',
          'Open risks, assumptions, waivers, and change-control decisions are captured.'
        ],
      );
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': '''
You are a senior design delivery manager and product/program governance lead.
Create a rigorous design deliverables package suitable for waterfall stage gates, hybrid governance, Scrum/Kanban delivery, and scaled agile solution intent.
Ground the output in unique/verifiable deliverables, acceptance criteria, traceability, version/configuration control, quality review, accessibility/security/NFR evidence, stakeholder approval, change control, and operational handoff.
Return JSON with:
- "pipeline": [{ "label", "status" }]
- "register": [{ "name", "owner", "status", "due", "risk" }]
- "approvals": [string]
- "dependencies": [string]
- "handoffChecklist": [string]
Use concise professional language. Status should use In progress, Pending, In review, Approved, Complete, or Blocked. Risk should use Low, Medium, or High.
'''
        },
        {'role': 'user', 'content': 'Project Context:\n$trimmedContext'}
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode >= 300) return const DesignDeliverablesData();

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;

      final pipeline = (parsed['pipeline'] as List?)
              ?.map((e) => DesignDeliverablePipelineItem.fromJson(
                  e as Map<String, dynamic>))
              .toList() ??
          [];
      final register = (parsed['register'] as List?)
              ?.map((e) => DesignDeliverableRegisterItem.fromJson(
                  e as Map<String, dynamic>))
              .toList() ??
          [];
      final approvals =
          (parsed['approvals'] as List?)?.map((e) => e.toString()).toList() ??
              [];

      return DesignDeliverablesData(
        pipeline: pipeline,
        register: register,
        approvals: approvals,
        dependencies: (parsed['dependencies'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        handoffChecklist: (parsed['handoffChecklist'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            (parsed['handoff_checklist'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
    } catch (e) {
      debugPrint('Error generating design deliverables: $e');
      return const DesignDeliverablesData();
    }
  }

  // Generate Technical Alignment (Constraints, Mappings, Dependencies)
  Future<Map<String, dynamic>> generateTechnicalAlignment({
    required String context,
    int maxTokens = 1500,
    double temperature = 0.5,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) return {};
    if (!OpenAiConfig.isConfigured) return {};

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': '''
You are a senior enterprise architect and delivery-methodology advisor.
Create a rigorous technical alignment register that would satisfy waterfall stage gates, hybrid governance, Scrum/Kanban delivery, and scaled agile portfolio alignment.
Ground the response in requirements traceability, architecture decisions, interface control, non-functional requirements, data governance, security/privacy, observability, release readiness, operational support, risk ownership, and evidence-based approval.
Return JSON with:
- "constraints": [{ "constraint", "guardrail", "owner", "status" }]
- "mappings": [{ "requirement", "approach", "status" }]
- "dependencies": [{ "item", "detail", "owner", "status" }]
Use concise professional language. Status must be one of: Approved, Aligned, Ready, In review, Draft, Pending, At risk.
'''
        },
        {'role': 'user', 'content': 'Project Context:\n$trimmedContext'}
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 300) return {};

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;

      return parsed;
    } catch (e) {
      debugPrint('Error generating technical alignment: $e');
      return {};
    }
  }

  // Generate Specialized Design (Security, Performance, Integrations)
  Future<SpecializedDesignData> generateSpecializedDesign({
    required String context,
    int maxTokens = 1500,
    double temperature = 0.5,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) return SpecializedDesignData();
    if (!OpenAiConfig.isConfigured) return SpecializedDesignData();

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': '''
You are a security and performance data engineer. Suggest specialized design patterns.
Return JSON with:
- "security": [{ "pattern", "context", "implementation", "status" }]
- "performance": [{ "pattern", "metric", "optimization", "status" }]
- "integration": [{ "system", "method", "data_flow", "status" }]
- "notes": "Summary of critical specialized design considerations."
'''
        },
        {'role': 'user', 'content': 'Project Context:\n$trimmedContext'}
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 300) return SpecializedDesignData();

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;

      final security = (parsed['security'] as List?)
              ?.map((e) => SecurityPatternRow.fromMap(e))
              .toList() ??
          [];
      final performance = (parsed['performance'] as List?)
              ?.map((e) => PerformancePatternRow.fromMap(e))
              .toList() ??
          [];
      final integration = (parsed['integration'] as List?)
              ?.map((e) => IntegrationFlowRow.fromMap(e))
              .toList() ??
          [];
      final notes = _stripAsterisks((parsed['notes'] ?? '').toString());

      return SpecializedDesignData(
        notes: notes,
        securityPatterns: security,
        performancePatterns: performance,
        integrationFlows: integration,
      );
    } catch (e) {
      debugPrint('Error generating specialized design: $e');
      return SpecializedDesignData();
    }
  }

  // ignore: unused_element
  DesignDeliverablesData _parseDesignDeliverables(Map<String, dynamic> json) {
    List<String> toStringList(dynamic value) {
      if (value is List) {
        return value
            .map((e) => _stripAsterisks(e.toString().trim()))
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return const [];
    }

    List<DesignDeliverablePipelineItem> parsePipeline(dynamic value) {
      if (value is List) {
        return value
            .map((item) {
              final map = Map<String, dynamic>.from(item as Map);
              return DesignDeliverablePipelineItem(
                label: _stripAsterisks((map['label'] ?? '').toString().trim()),
                status:
                    _stripAsterisks((map['status'] ?? '').toString().trim()),
              );
            })
            .where((item) => item.label.isNotEmpty)
            .toList();
      }
      return const [];
    }

    List<DesignDeliverableRegisterItem> parseRegister(dynamic value) {
      if (value is List) {
        return value
            .map((item) {
              final map = Map<String, dynamic>.from(item as Map);
              return DesignDeliverableRegisterItem(
                name: _stripAsterisks((map['name'] ?? '').toString().trim()),
                owner: _stripAsterisks((map['owner'] ?? '').toString().trim()),
                status:
                    _stripAsterisks((map['status'] ?? '').toString().trim()),
                due: _stripAsterisks((map['due'] ?? '').toString().trim()),
                risk: _stripAsterisks((map['risk'] ?? '').toString().trim()),
              );
            })
            .where((item) => item.name.isNotEmpty)
            .toList();
      }
      return const [];
    }

    final metricsMap = json['metrics'] is Map
        ? Map<String, dynamic>.from(json['metrics'] as Map)
        : <String, dynamic>{};
    final metrics = DesignDeliverablesMetrics.fromJson(metricsMap);

    return DesignDeliverablesData(
      metrics: metrics,
      pipeline: parsePipeline(json['pipeline']),
      approvals: toStringList(json['approvals']),
      register: parseRegister(json['register']),
      dependencies: toStringList(json['dependencies']),
      handoffChecklist: toStringList(json['handoff']),
    );
  }

  // ignore: unused_element
  DesignDeliverablesData _designDeliverablesFallback(String context) {
    final project = _extractProjectName(context);
    final name = project.isNotEmpty ? project : 'Project';
    return DesignDeliverablesData(
      metrics: const DesignDeliverablesMetrics(
          active: 6, inReview: 3, approved: 2, atRisk: 1),
      pipeline: const [
        DesignDeliverablePipelineItem(
            label: 'Discovery & Research', status: 'In Review'),
        DesignDeliverablePipelineItem(
            label: 'Wireframes', status: 'In Progress'),
        DesignDeliverablePipelineItem(label: 'UI Design', status: 'Pending'),
        DesignDeliverablePipelineItem(label: 'Prototype', status: 'Pending'),
      ],
      approvals: [
        'Product sign-off aligned for $name',
        'Engineering review scheduled',
        'Accessibility review pending',
        'Brand compliance check queued',
      ],
      register: const [
        DesignDeliverableRegisterItem(
            name: 'Wireframe Pack',
            owner: 'UX Team',
            status: 'In Review',
            due: 'TBD',
            risk: 'Medium'),
        DesignDeliverableRegisterItem(
            name: 'UI Kit',
            owner: 'Design Ops',
            status: 'In Progress',
            due: 'TBD',
            risk: 'Low'),
        DesignDeliverableRegisterItem(
            name: 'Prototype',
            owner: 'Product',
            status: 'Pending',
            due: 'TBD',
            risk: 'High'),
        DesignDeliverableRegisterItem(
            name: 'Journey Maps',
            owner: 'Research',
            status: 'In Progress',
            due: 'TBD',
            risk: 'Medium'),
      ],
      dependencies: const [
        'Finalize IA and navigation taxonomy',
        'Confirm content strategy inputs',
        'Align analytics tracking requirements',
      ],
      handoffChecklist: const [
        'Component specs documented',
        'Accessibility annotations included',
        'Figma files shared with dev team',
        'Interaction guidelines attached',
      ],
    );
  }

  Future<AiProjectFrameworkAndGoals> suggestProjectFrameworkGoals({
    required String context,
    int maxTokens = 450,
    double temperature = 0.4,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) {
      throw Exception('No project context provided');
    }
    if (!OpenAiConfig.isConfigured) {
      throw const OpenAiNotConfiguredException();
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();
    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a senior project strategist helping to set the right delivery framework and goals. Always reply with JSON only and obey the required schema.'
        },
        {
          'role': 'user',
          'content': _projectFrameworkPrompt(trimmedContext),
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content = OpenAiConfig.extractContent(data);
      if (content.isNotEmpty) {
        final parsed = _decodeJsonSafely(content);
        if (parsed != null) {
          final result = AiProjectFrameworkAndGoals.fromMap(parsed);
          if (result.goals.length >= 3 && result.framework.isNotEmpty) {
            return result;
          }
          if (result.goals.isNotEmpty) {
            return result;
          }
        }
      }
    } catch (e) {
      // Let callers handle the failure and show an explicit error state
      rethrow;
    }
    throw Exception('OpenAI did not return framework goals');
  }

  // OPPORTUNITIES
  // Generates a structured list of project opportunities based on full project context.
  // Returns up to 12 rows suitable for the Opportunities table.
  // Returns up to 12 rows suitable for the Opportunities table.
  Future<List<OpportunityItem>> generateOpportunitiesFromContext(
      String context) async {
    final trimmed = context.trim();
    if (trimmed.isEmpty) throw Exception('No context provided');
    if (!OpenAiConfig.isConfigured) throw const OpenAiNotConfiguredException();

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': 0.55,
      'max_completion_tokens': 1200,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'program manager drafting tangible project opportunities from prior project context',
            strictJson: true,
            extraRules:
                'Draft practical, specific opportunities that fit the project type and current project context. Avoid generic business platitudes and include ownership, phase, and implementation detail when the context supports it.',
          )
        },
        {
          'role': 'user',
          'content': _opportunitiesPrompt(trimmed),
        }
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 14));
      if (response.statusCode == 401) throw Exception('Invalid API key');
      if (response.statusCode == 429) throw Exception('API quota exceeded');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;
      final list = (parsed['opportunities'] as List? ?? []);
      final result = <OpportunityItem>[];
      for (var idx = 0; idx < list.length; idx++) {
        final item = list[idx];
        if (item is! Map) continue;
        final map = item as Map<String, dynamic>;
        final opp = _stripAsterisks(
            (map['opportunity'] ?? map['title'] ?? '').toString().trim());
        if (opp.isEmpty) continue;
        final responsibleRole =
            (map['responsibleRole'] ?? map['stakeholder'] ?? map['role'] ?? '')
                .toString()
                .trim();
        final owner =
            (map['owner'] ?? map['assignedTo'] ?? '').toString().trim();
        final applicablePhase =
            (map['applicablePhase'] ?? map['phase'] ?? '').toString().trim();
        final status = (map['status'] ?? '').toString().trim();
        final implementationStrategy =
            (map['implementationStrategy'] ?? map['implementation'] ?? '')
                .toString()
                .trim();
        result.add(OpportunityItem(
          id: "${DateTime.now().microsecondsSinceEpoch}_$idx",
          opportunity: opp,
          discipline: (map['discipline'] ?? '').toString().trim(),
          stakeholder: responsibleRole,
          responsibleRole: responsibleRole,
          potentialCostSavings: (map['potentialCostSavings'] ??
                  map['potential_cost_savings'] ??
                  '')
              .toString()
              .trim(),
          potentialScheduleSavings: (map['potentialScheduleSavings'] ??
                  map['scheduleImpact'] ??
                  map['potential_cost_schedule_savings'] ??
                  '')
              .toString()
              .trim(),
          implementationStrategy: implementationStrategy,
          applicablePhase: applicablePhase,
          owner: owner,
          status: status.isNotEmpty ? status : 'Identified',
          assignedTo: owner,
          appliesTo: _phaseToOpportunityTags(applicablePhase),
          impact: (map['impact'] ?? 'Medium').toString().trim(),
        ));
      }
      if (result.isNotEmpty) return result.take(12).toList();
      throw Exception('OpenAI returned no opportunities');
    } catch (e) {
      rethrow;
    }
  }

  String _opportunitiesPrompt(String context) {
    final c = _escape(context);
    return '''
From the project context below, list concrete project opportunities that would benefit the initiative.
Each opportunity must match the exact project scope, preferred solution direction, geographic region, sector, and delivery constraints already defined in the context.
Use realistic patterns and benchmarks typically seen in similar projects for this project type and region.

Return ONLY valid JSON with this exact structure:
{
  "opportunities": [
    {
      "opportunity": "Concise opportunity statement",
      "potentialCostSavings": "Numeric or short label (e.g., 25,000)",
      "scheduleImpact": "Short time effect (e.g., 2 weeks faster)",
      "implementationStrategy": "How this opportunity would be implemented",
      "discipline": "Owning discipline (e.g., IT, Finance, Operations)",
      "responsibleRole": "Role accountable for delivery",
      "owner": "Specific owner or team member",
      "applicablePhase": "Initiation | Planning | Design | Execution | Launch | All",
      "status": "Identified | Proposed | Approved | In Progress | Closed",
      "potentialScheduleSavings": "Numeric/short label (e.g., 2 weeks)",
      "impact": "High / Medium / Low"
    }
  ]
}

Guidelines:
- Be specific and actionable (no placeholders).
- Do not output generic ideas unrelated to the provided scope.
- Ensure each row can transfer directly into an execution log with clear role and ownership.
- 5-12 items is ideal.

Project context:
"""
$c
"""
''';
  }

  List<String> _phaseToOpportunityTags(String phase) {
    final normalized = phase.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const <String>[];
    }
    if (normalized == 'all' || normalized == 'project wide') {
      return const <String>['Project Wide', 'Estimate', 'Schedule', 'Training'];
    }
    if (normalized == 'planning') {
      return const <String>['Estimate', 'Schedule'];
    }
    if (normalized == 'execution') {
      return const <String>['Schedule', 'Training'];
    }
    if (normalized == 'launch') {
      return const <String>['Training'];
    }
    return const <String>[];
  }

  String _fepSectionPrompt({required String section, required String context}) {
    final s = _escape(section);
    final c = _escape(context);
    return '''
Draft the Front End Planning section: "$s" from the project context below.

Return ONLY valid JSON with this exact structure:
{
  "text": "final write-up as plain text, with concise paragraphs and bullet points only when helpful"
}

Guidelines:
- Use the project's goals, risks, and milestones as constraints and inputs.
- Keep it 120–250 words when possible; be specific and actionable.
- Avoid placeholders, boilerplate, and generic fluff.
- Where helpful, use short lists (hyphen bullets) but keep structure minimal.

Project context:
"""
$c
"""
''';
  }

  String _qualitySeedPrompt(
      {required String section, required String context}) {
    final s = _escape(section);
    final c = _escape(context);
    return '''
Generate a structured quality planning seed bundle for "$s" using the project context.

Return ONLY valid JSON with this exact schema:
{
  "standards": [
    {"name": "", "source": "", "category": "", "description": "", "applicability": ""}
  ],
  "objectives": [
    {"title": "", "acceptanceCriteria": "", "successMetric": "", "targetValue": "", "currentValue": "", "owner": "", "linkedRequirement": "", "linkedWbs": "", "status": ""}
  ],
  "workflowControls": [
    {"type": "qa or qc", "name": "", "method": "", "tools": "", "checklist": "", "frequency": "", "owner": "", "standardsReference": ""}
  ],
  "auditPlan": [
    {"title": "", "scope": "", "plannedDate": "", "completedDate": "", "owner": "", "result": "pending", "findings": "", "notes": ""}
  ],
  "kpiTargets": {
    "targetTimeToResolutionDays": 15
  },
  "dashboardConfig": {
    "targetTimeToResolutionDays": 15
  }
}

Guidelines:
- Focus on actionable standards, measurable objectives, and practical QA/QC controls.
- Prefer concise, realistic entries with no placeholders.
- Include 3-8 items for each list where possible.
- Keep result values for audits as one of: pass, conditional, fail, pending.

Project context:
"""
$c
"""
''';
  }

  // Quick single-item estimate for inline AI suggestions in cost fields
  // Returns a numeric estimated cost in the provided currency (defaults to USD).
  Future<double> estimateCostForItem({
    required String itemName,
    String description = '',
    String assumptions = '',
    String currency = 'USD',
    String contextNotes = '',
    String estimationMode = 'cost_item',
    String basisFrequency = '',
  }) async {
    final String trimmed = itemName.trim();
    if (trimmed.isEmpty) return 0;

    if (!OpenAiConfig.isConfigured) throw const OpenAiNotConfiguredException();

    final combinedContext = '$trimmed $description $assumptions $contextNotes';
    final projectType = _detectProjectType(combinedContext);
    final projectScale = _detectProjectScale(combinedContext);
    final budgetAnchor = _extractLargestCurrencyAnchor(contextNotes);
    final domainHints = _financialDomainHints(
      context: combinedContext,
    );
    final scaleConstraints = _scaleFinancialConstraints(projectScale);

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final prompt = _singleItemEstimatePrompt(
      itemName: trimmed,
      description: description,
      assumptions: assumptions,
      currency: currency,
      contextNotes: contextNotes,
      projectType: projectType,
      budgetAnchor: budgetAnchor,
      estimationMode: estimationMode,
      basisFrequency: basisFrequency,
      domainHints: domainHints,
      scaleConstraints: scaleConstraints,
    );

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': 0.35,
      'max_completion_tokens': 300,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'senior cost analyst estimating a single financial line item accurately for the detected project domain',
            strictJson: true,
            extraRules:
                'Return JSON only with keys: estimated_cost (number), confidence (0..1), needs_more_context (boolean), rationale (string). Do not produce SaaS metrics for non-digital projects. Do not produce construction assumptions for purely digital projects.',
          )
        },
        {
          'role': 'user',
          'content': prompt,
        }
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 401) {
        throw Exception('Invalid API key');
      }
      if (response.statusCode == 429) {
        throw Exception('API quota exceeded');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;
      final dynamic value =
          parsed['estimated_cost'] ?? parsed['cost'] ?? parsed['value'];
      final estimated = _toDouble(value);
      final confidence =
          _toDouble(parsed['confidence'] ?? parsed['confidence_score']);
      final needsMoreContext = _toBool(
        parsed['needs_more_context'] ?? parsed['insufficient_context'],
      );

      if (!estimated.isFinite || estimated <= 0) return 0;
      if (needsMoreContext) return 0;
      if (confidence > 0 && confidence < 0.58) return 0;

      // Guardrail against generic placeholder values unless confidence is high.
      if (_looksGenericRoundNumber(estimated) && confidence < 0.82) {
        return 0;
      }

      if (budgetAnchor > 0 &&
          estimated > (budgetAnchor * 3) &&
          confidence < 0.7) {
        return 0;
      }

      // Post-processing: clamp to scale-appropriate maximum
      return _clampCostValue(estimated, projectScale);
    } catch (e) {
      rethrow;
    }
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(RegExp(r'[^0-9\.-]'), '');
    return double.tryParse(s) ?? 0;
  }

  bool _toBool(dynamic v) {
    if (v is bool) return v;
    final text = (v ?? '').toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }

// Removed small deterministic fallback helpers — API failures must surface to the UI.

  String _normalizeBenefitCategoryKey(String rawCategory) {
    final normalized = rawCategory
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return 'other';

    final direct = normalized.replaceAll(' ', '_');
    const knownKeys = <String>{
      'revenue',
      'cost_saving',
      'ops_efficiency',
      'productivity',
      'regulatory_compliance',
      'process_improvement',
      'brand_image',
      'stakeholder_commitment',
      'other',
    };
    if (knownKeys.contains(direct)) return direct;

    if (normalized.contains('revenue') ||
        normalized.contains('financial gain') ||
        normalized == 'financial') {
      return 'revenue';
    }
    if (normalized.contains('cost saving') ||
        normalized.contains('cost reduction') ||
        normalized.contains('cost avoid')) {
      return 'cost_saving';
    }
    if (normalized.contains('operational') ||
        normalized.contains('ops efficiency') ||
        normalized.contains('efficiency')) {
      return 'ops_efficiency';
    }
    if (normalized.contains('productivity') ||
        normalized.contains('throughput') ||
        normalized.contains('cycle time')) {
      return 'productivity';
    }
    if (normalized.contains('regulatory') ||
        normalized.contains('compliance') ||
        normalized.contains('risk reduction')) {
      return 'regulatory_compliance';
    }
    if (normalized.contains('process') || normalized.contains('workflow')) {
      return 'process_improvement';
    }
    if (normalized.contains('brand') ||
        normalized.contains('reputation') ||
        normalized.contains('perception') ||
        normalized.contains('customer experience')) {
      return 'brand_image';
    }
    if (normalized.contains('stakeholder') ||
        normalized.contains('shareholder') ||
        normalized.contains('investor')) {
      return 'stakeholder_commitment';
    }
    return 'other';
  }

  String _benefitCategoryDisplayLabel(String key) {
    switch (key) {
      case 'revenue':
        return 'Revenue';
      case 'cost_saving':
        return 'Cost Saving';
      case 'ops_efficiency':
        return 'Operational Efficiency';
      case 'productivity':
        return 'Productivity';
      case 'regulatory_compliance':
        return 'Regulatory & Compliance';
      case 'process_improvement':
        return 'Process Improvement';
      case 'brand_image':
        return 'Brand Image';
      case 'stakeholder_commitment':
        return 'Stakeholder Commitment';
      default:
        return 'Other';
    }
  }

  String _singleItemEstimatePrompt({
    required String itemName,
    required String description,
    required String assumptions,
    required String currency,
    required String contextNotes,
    required _AiProjectType projectType,
    required double budgetAnchor,
    required String estimationMode,
    required String basisFrequency,
    required String domainHints,
    String scaleConstraints = '',
  }) {
    final safeName = _escape(itemName);
    final safeDesc = _escape(description);
    final safeAssumptions = _escape(assumptions);
    final notes = contextNotes.trim().isEmpty ? 'None' : _escape(contextNotes);
    final typeLabel = _projectTypeLabel(projectType);
    final budgetNote =
        budgetAnchor > 0 ? budgetAnchor.toStringAsFixed(0) : 'Not available';
    final mode = estimationMode.trim().isEmpty ? 'cost_item' : estimationMode;
    final basis =
        basisFrequency.trim().isEmpty ? 'Not specified' : basisFrequency;
    final unitModeRules = mode == 'benefit_unit_value'
        ? '''
- This request is for a BENEFIT UNIT VALUE, not a full project total.
- Return the value for ONE unit only, grounded in the provided category/title/assumptions.
- Respect the selected basis frequency when interpreting the unit value: "$basis".
- If context is not enough for a reliable unit value, return estimated_cost as 0 and needs_more_context as true.
'''
        : '';
    final currencyInstruction = _currencyConversionInstruction(currency);
    return '''
Estimate a realistic one-off cost for a single project line item in $currency.

Return ONLY valid JSON like this example:
{
  "estimated_cost": 12345,
  "confidence": 0.84,
  "needs_more_context": false,
  "rationale": "Short reason"
}

Rules:
- Infer the likely project type and align the estimate to that domain.
- Avoid generic placeholder values (e.g., 100000, 250000, 500000) unless explicitly justified by quantities.
- Use context anchors, including project value and scope, before producing a number.
- If confidence is low, return estimated_cost as 0 and needs_more_context as true.
- For physical projects, avoid software lifecycle assumptions (MVP, sprint, API integration) unless explicitly stated.
- Keep the estimate realistic for the project stage and starting point.
$unitModeRules$currencyInstruction

Item: "$safeName"
Description: "$safeDesc"
Assumptions: "$safeAssumptions"
Additional context: "$notes"
Detected project type hint: "$typeLabel"
Largest numeric anchor found in context: "$budgetNote $currency"
Estimation mode: "$mode"
Domain guardrails:
$domainHints

$scaleConstraints
''';
  }

  // SUGGESTIONS
  Future<List<CostEstimateItem>> generateCostEstimateSuggestions({
    required String context,
    String currency = 'USD',
  }) async {
    final trimmed = context.trim();
    if (trimmed.isEmpty) throw Exception('No context provided');
    if (!OpenAiConfig.isConfigured) throw const OpenAiNotConfiguredException();
    final projectType = _detectProjectType(trimmed);
    final projectScale = _detectProjectScale(trimmed);
    final domainHints = _financialDomainHints(context: trimmed);
    final scaleConstraints = _scaleFinancialConstraints(projectScale);

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': 0.6,
      'max_completion_tokens': 1200,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'project cost estimator generating context-aware direct and indirect cost suggestions',
            strictJson: true,
            extraRules:
                'Return strict JSON only. Suggest practical cost items based on project type, scale, and prior context. Avoid generic placeholders. If context is weak, return an empty "items" array.',
          )
        },
        {
          'role': 'user',
          'content': _costSuggestionsPrompt(
            trimmed,
            projectType: projectType,
            domainHints: domainHints,
            scaleConstraints: scaleConstraints,
            currency: currency,
          ),
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 401) throw Exception('Invalid API key');
      if (response.statusCode == 429) throw Exception('API quota exceeded');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;

      final list = (parsed['items'] as List?)?.map((e) {
            final map = e as Map<String, dynamic>;
            final title = _stripAsterisks((map['title'] ?? '').toString());
            final notes = _stripAsterisks((map['notes'] ?? '').toString());
            final rawType = (map['costType'] ?? map['type'] ?? '').toString();
            return CostEstimateItem(
              title: title,
              amount: _toDouble(map['amount']),
              notes: notes,
              // Canonicalize to direct/indirect so UI filters always work.
              costType: _normalizeCostTypeValue(
                rawType,
                title: title,
                notes: notes,
              ),
            );
          }).toList() ??
          [];

      return _sanitizeCostEstimateSuggestions(
        list,
        projectType: projectType,
        projectScale: projectScale,
      );
    } catch (e) {
      rethrow;
    }
  }

  // ALLOWANCES
  Future<List<AllowanceItem>> generateAllowancesFromContext(
      String context) async {
    final trimmed = context.trim();
    if (trimmed.isEmpty) throw Exception('No context provided');
    if (!OpenAiConfig.isConfigured) throw const OpenAiNotConfiguredException();

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': 0.5,
      'max_completion_tokens': 1600,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'financial program manager proposing realistic allowance and contingency items',
            strictJson: true,
            extraRules:
                'Calibrate amounts and risk categories to the project scale, type, and geographic/regional risk profile in the provided context. Always consider regional hazards (hurricanes in the US Gulf Coast / Caribbean, typhoons in East/Southeast Asia, power instability in parts of Africa/South Asia, security/civil unrest in fragile regions, seismic activity in Pacific Rim, winter storms in North America/Europe, monsoon flooding in South Asia).',
          ),
        },
        {
          'role': 'user',
          'content': _allowancesPrompt(trimmed),
        }
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 18));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;
      final list = (parsed['items'] as List? ?? []);

      final result = <AllowanceItem>[];
      var counter = DateTime.now().microsecondsSinceEpoch;
for (final item in list) {
        if (item is! Map) continue;
        final map = item as Map<String, dynamic>;

        final name = _stripAsterisks(
            (map['name'] ?? map['title'] ?? '').toString().trim());
        if (name.isEmpty) continue;

        double amount = 0.0;
        if (map['amount'] is num) {
          amount = (map['amount'] as num).toDouble();
        } else {
          final amtStr =
              map['amount'].toString().replaceAll(',', '').replaceAll('\$', '');
          amount = double.tryParse(amtStr) ?? 0.0;
        }

        final appliesTo = (map['appliesTo'] as List? ?? [])
            .map((e) => e.toString().trim())
            .toList();

        // Auto-assign appliesTo if missing (based on prompt guidelines, but safe fallback)
        if (appliesTo.isEmpty) {
          appliesTo.add('Project Wide');
        }

        // Schedule impact weeks — numeric, optional
        double scheduleImpactWeeks = 0.0;
        if (map['scheduleImpactWeeks'] is num) {
          scheduleImpactWeeks = (map['scheduleImpactWeeks'] as num).toDouble();
        } else {
          scheduleImpactWeeks = double.tryParse(
                  map['scheduleImpactWeeks']?.toString() ?? '') ??
              0.0;
        }

        result.add(AllowanceItem(
          id: '${counter}_$result',
          name: name,
          type: (map['type'] ?? 'Other').toString(),
          amount: amount,
          appliesTo: appliesTo,
          notes: (map['notes'] ?? '').toString(),
          description: (map['description'] ?? '').toString(),
          estimatedCostOrQuantity:
              (map['estimatedCostOrQuantity'] ?? map['estimatedCostOrQty'] ?? '')
                  .toString(),
          scheduleImpact: (map['scheduleImpact'] ?? '').toString(),
          scheduleImpactWeeks: scheduleImpactWeeks,
          responsibleDiscipline:
              (map['responsibleDiscipline'] ?? map['discipline'] ?? '')
                  .toString(),
          assumptions: (map['assumptions'] ?? '').toString(),
          triggerContext: (map['triggerContext'] ?? map['trigger'] ?? '')
              .toString(),
        ));
        counter += 1;
      }
      if (result.isNotEmpty) return result;
      throw Exception('OpenAI returned no allowance items');
    } catch (e) {
      rethrow;
    }
  }

  String _allowancesPrompt(String context) {
    final c = _escape(context);
    return '''
Based on the project context below, suggest 4-7 specific Allowance or Contingency items — including basic allowances and contingencies for both COST and SCHEDULE.

CRITICAL: Factor in the project's LOCATION, REGION, and PROJECT TYPE to generate context-appropriate allowances. Examples of regional considerations:
- US Gulf Coast / Caribbean / SE US: hurricane season contingency, flood allowance, evacuation/remobilization
- East / Southeast Asia: typhoon contingency, monsoon flooding allowance, supply chain disruption
- West / Central Africa: power instability allowance (generator fuel, UPS), security escort contingency, customs delay
- South Asia: monsoon schedule allowance, civil unrest contingency, power backup
- Middle East: extreme heat schedule allowance (reduced productivity hours), security contingency
- Pacific Rim: seismic design allowance, tsunami contingency
- Europe / North America: winter weather schedule allowance, environmental compliance contingency
- Remote sites: logistics/mobilization allowance, communications infrastructure, medical evac

For EACH item, populate these fields:
- name: short item name (e.g. "Hurricane Schedule Contingency")
- type: one of Contingency, Training, Staffing, Tech, Other
- amount: numeric USD estimate (e.g. 25000)
- estimatedCostOrQuantity: human-readable cost or quantity (e.g. "\$25,000", "10% of base cost", "200 person-hours")
- scheduleImpact: short text describing schedule exposure (e.g. "Adds 2 weeks to commissioning after storm")
- scheduleImpactWeeks: numeric weeks of schedule allowance (e.g. 2, 0 if not applicable)
- responsibleDiscipline: which discipline owns this (e.g. "Project Controls", "Procurement", "Civil", "IT")
- appliesTo: array of strings (e.g. ["Schedule", "Estimate"])
- assumptions: brief assumptions underpinning the allowance
- triggerContext: WHY this allowance was suggested (e.g. "Hurricane exposure — Gulf Coast US", "Power instability — West Africa")
- notes: brief justification

Return ONLY valid JSON with this exact structure:
{
  "items": [
    {
      "name": "Hurricane Schedule Contingency",
      "type": "Contingency",
      "amount": 50000,
      "estimatedCostOrQuantity": "\$50,000",
      "scheduleImpact": "Up to 3 weeks delay during hurricane season",
      "scheduleImpactWeeks": 3,
      "responsibleDiscipline": "Project Controls",
      "appliesTo": ["Schedule", "Estimate"],
      "assumptions": "Assumes 1 named storm impact per construction season",
      "triggerContext": "Hurricane exposure — Gulf Coast US",
      "notes": "Covers demobilization/remobilization and storm protection"
    }
  ]
}

Project context:
"""
$c
"""
''';
  }

  String _costSuggestionsPrompt(
    String context, {
    required _AiProjectType projectType,
    required String domainHints,
    String scaleConstraints = '',
    String currency = 'USD',
  }) {
    final c = _escape(context);
    final typeLabel = _projectTypeLabel(projectType);
    final currencyInstruction = _currencyConversionInstruction(currency);
    return '''
Based on the project context below, suggest 3-5 realistic cost estimate items (mix of direct and indirect costs if appropriate).

Return ONLY valid JSON with this structure:
{
  "items": [
    {
      "title": "Item Name",
      "amount": 15000,
      "costType": "direct" or "indirect",
      "notes": "Brief explanation or assumption"
    }
  ]
}

Rules:
- When returning 2+ items, include both cost types: at least one "direct" and one "indirect".
- Align suggestions to the detected project type: $typeLabel.
- Avoid generic placeholders like 100000, 250000, or 500000.
- If context is insufficient, return {"items": []}.
- For physical projects, do not output software phases such as Discovery and Planning, MVP Build, Integration, or Data.
- Do not use SaaS-only metrics or terms (CAC/LTV/churn/MRR) unless the context explicitly indicates a SaaS/digital business model.
- All amounts in the JSON must be in $currency.$currencyInstruction

$scaleConstraints

Project Context:
"""
$c
"""

Domain guardrails:
$domainHints
''';
  }

  List<CostEstimateItem> _sanitizeCostEstimateSuggestions(
    List<CostEstimateItem> items, {
    required _AiProjectType projectType,
    _AiProjectScale projectScale = _AiProjectScale.medium,
  }) {
    final seen = <String>{};
    final filtered = <CostEstimateItem>[];
    for (final item in items) {
      final title = _stripAsterisks(item.title).trim();
      if (title.isEmpty) continue;
      final amount = item.amount;
      if (!amount.isFinite || amount <= 0) continue;
      if (_looksGenericRoundNumber(amount)) continue;
      if (projectType != _AiProjectType.digital &&
          _isSoftwarePhaseLabel('$title ${item.notes}')) {
        continue;
      }
      final key = '${title.toLowerCase()}|${amount.round()}';
      if (seen.contains(key)) continue;
      seen.add(key);
      final normalizedType = _normalizeCostTypeValue(
        item.costType,
        title: title,
        notes: item.notes,
      );
      filtered.add(
        CostEstimateItem(
          title: title,
          amount: _clampCostValue(amount, projectScale),
          notes: item.notes.trim(),
          costType: normalizedType,
        ),
      );
    }
    return filtered;
  }

  String _normalizeCostTypeValue(
    String raw, {
    required String title,
    required String notes,
  }) {
    final value = raw.trim().toLowerCase();
    if (value == 'direct' || value == 'indirect') return value;

    final merged = '$value ${title.toLowerCase()} ${notes.toLowerCase()}';
    const indirectSignals = [
      'indirect',
      'overhead',
      'admin',
      'administrative',
      'support',
      'training',
      'maintenance',
      'compliance',
      'license',
      'subscription',
      'insurance',
      'facility',
      'utilities',
      'governance',
    ];
    if (indirectSignals.any((signal) => merged.contains(signal))) {
      return 'indirect';
    }

    const directSignals = [
      'direct',
      'implementation',
      'delivery',
      'build',
      'construction',
      'equipment',
      'material',
      'labor',
      'development',
      'integration',
      'hardware',
      'software',
      'vendor',
      'contractor',
      'install',
      'deployment',
    ];
    if (directSignals.any((signal) => merged.contains(signal))) {
      return 'direct';
    }

    return 'direct';
  }

  // SOLUTIONS
  Future<List<AiSolutionItem>> generateSolutionsFromBusinessCase(
    String businessCase, {
    String contextNotes = '',
  }) async {
    if (businessCase.trim().isEmpty) throw Exception('Business case is empty');
    if (!OpenAiConfig.isConfigured) throw const OpenAiNotConfiguredException();

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final solutions = await _attemptSolutionsApiCall(
          businessCase,
          contextNotes: contextNotes,
        );
        if (solutions.isNotEmpty) return solutions;
      } catch (e) {
        if (attempt < maxRetries - 1) await Future.delayed(retryDelay);
        if (attempt == maxRetries - 1) rethrow;
      }
    }
    throw Exception('OpenAI returned no solutions');
  }

  Future<List<AiSolutionItem>> _attemptSolutionsApiCall(
    String businessCase, {
    String contextNotes = '',
  }) async {
    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();
    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': 0.7,
      'max_completion_tokens': 1000,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'project initiation assistant creating concise, business-friendly solution options',
            strictJson: true,
            extraRules:
                'When generating Potential Solutions, provide 2-3 genuinely distinct high-level approaches, not minor variations of the same idea. Prefer a greenfield/from-scratch setup for physical projects unless context clearly indicates an existing operation with digital-only enhancement needs.',
          )
        },
        {
          'role': 'user',
          'content': _solutionsPrompt(
            businessCase,
            contextNotes: contextNotes,
          )
        },
      ],
    }));

    final response = await _client
        .post(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 429) {
      throw Exception('API quota exceeded. Please check your OpenAI billing.');
    }
    if (response.statusCode == 401) {
      throw Exception('Invalid API key. Please check your OpenAI API key.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'OpenAI API error ${response.statusCode}: ${response.body}');
    }

    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final content =
        OpenAiConfig.extractContent(data);
    final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;
    final items = (parsed['solutions'] as List? ?? [])
        .map((e) => AiSolutionItem.fromMap(e as Map<String, dynamic>))
        .where((e) => e.title.isNotEmpty && e.description.isNotEmpty)
        .toList();
    return _normalizeSolutions(items);
  }

  // RISKS
  Future<Map<String, List<String>>> generateRisksForSolutions(
      List<AiSolutionItem> solutions,
      {String contextNotes = ''}) async {
    if (solutions.isEmpty) return {};
    if (!OpenAiConfig.isConfigured) throw const OpenAiNotConfiguredException();

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();
    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': 0.6,
      'max_completion_tokens': 1200,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'risk analyst listing crisp, non-overlapping delivery risks per solution',
            strictJson: true,
            extraRules:
                'For each provided solution, list three explicit risks. Do not use vague categories, filler text, or duplicate the same concern across solutions.',
          )
        },
        {'role': 'user', 'content': _risksPrompt(solutions, contextNotes)},
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;

      final List list = (parsed['risks'] as List? ?? []);
      final Map<String, List<String>> result = {};
      for (var idx = 0; idx < list.length; idx++) {
        final item = list[idx];
        final map = item as Map<String, dynamic>;
        final title = _stripAsterisks((map['solution'] ?? '').toString());
        final items = (map['items'] as List? ?? [])
            .map((e) => _stripAsterisks(e.toString()))
            .where((e) => e.trim().isNotEmpty)
            .take(3)
            .toList();
        if (title.isNotEmpty && items.isNotEmpty) result[title] = items;
      }
      return _mergeWithFallbackRisks(solutions, result);
    } catch (e) {
      rethrow;
    }
  }

  Map<String, List<String>> _mergeWithFallbackRisks(
      List<AiSolutionItem> solutions, Map<String, List<String>> generated) {
    final fallback = _fallbackRisks(solutions);
    final merged = <String, List<String>>{};
    for (final s in solutions) {
      final g = generated[s.title];
      merged[s.title] = (g != null && g.isNotEmpty)
          ? g.take(3).toList()
          : (fallback[s.title] ?? []);
    }
    return merged;
  }

  Map<String, List<String>> _fallbackRisks(List<AiSolutionItem> solutions) {
    // Provide solution-specific fallback risks to avoid identical risks across solutions
    final genericRiskPools = [
      [
        'Phased approach may extend overall timeline beyond stakeholder expectations.',
        'Handoff between phases creates potential for knowledge loss and rework.',
        'Early phases may require scope adjustments impacting later deliverables.'
      ],
      [
        'Hybrid integration complexity increases testing and validation effort.',
        'Legacy system dependencies may limit new technology capabilities.',
        'Technical debt from bridging old and new systems requires ongoing maintenance.'
      ],
      [
        'Vendor lock-in reduces flexibility for future changes and negotiations.',
        'External team coordination overhead impacts delivery velocity.',
        'Quality control challenges when work is distributed across organizations.'
      ],
      [
        'Aggressive timeline may compromise solution quality and testing coverage.',
        'Resource ramp-up time delays initial productivity and momentum.',
        'Stakeholder expectations misalignment leads to scope disputes.'
      ],
      [
        'Technology maturity risks if relying on emerging tools or frameworks.',
        'Skills gap in team requires training investment before productive work.',
        'Infrastructure provisioning delays block development progress.'
      ],
    ];

    final map = <String, List<String>>{};
    for (int i = 0; i < solutions.length; i++) {
      final s = solutions[i];
      // Assign different risk pools to different solutions
      map[s.title] = genericRiskPools[i % genericRiskPools.length];
    }
    return map;
  }

  // REQUIREMENTS GENERATION
  Future<List<Map<String, String>>> generateRequirementsFromBusinessCase(
      String businessCase) async {
    if (businessCase.trim().isEmpty) throw Exception('Business case is empty');
    if (!OpenAiConfig.isConfigured) throw const OpenAiNotConfiguredException();

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final requirements = await _attemptRequirementsApiCall(businessCase);
        if (requirements.isNotEmpty) return requirements;
      } catch (e) {
        if (attempt < maxRetries - 1) await Future.delayed(retryDelay);
        if (attempt == maxRetries - 1) rethrow;
      }
    }
    throw Exception('OpenAI returned no requirements');
  }

  Future<List<Map<String, String>>> _attemptRequirementsApiCall(
      String businessCase) async {
    Map<String, dynamic> data;
    try {
      data = await _postRequirementsRequest(
        businessCase,
        includeResponseFormat: true,
      );
    } on _ResponseFormatUnsupportedException {
      data = await _postRequirementsRequest(
        businessCase,
        includeResponseFormat: false,
      );
    }

    final extracted = _extractTextFromOpenAiPayload(data);
    Map<String, dynamic>? parsed;

    if (extracted != null) {
      parsed = _decodeJsonSafely(extracted);
      if (parsed == null) {
        final list = _decodeJsonListSafely(extracted);
        if (list != null) {
          return _normalizeRequirementItems(list).take(20).toList();
        }

        final fallback = _requirementsFromText(extracted);
        if (fallback.isNotEmpty) {
          return fallback.take(20).toList();
        }
      }
    } else if (data.containsKey('requirements')) {
      parsed = data;
    }

    if (parsed == null) {
      throw Exception('OpenAI returned invalid JSON for requirements.');
    }

    final list = parsed['requirements'] ?? parsed['items'];
    if (list is List) {
      return _normalizeRequirementItems(list).take(20).toList();
    }

    throw Exception('OpenAI returned no requirements.');
  }

  Future<Map<String, dynamic>> _postRequirementsRequest(
    String businessCase, {
    required bool includeResponseFormat,
  }) async {
    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();
    final payload = {
      'model': OpenAiConfig.model,
      'temperature': 0.7,
      'max_completion_tokens': 2000,
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'business analyst generating requirements from project context',
            strictJson: includeResponseFormat,
            extraRules:
                'Each requirement should be clear, specific, assigned where possible, and categorized by requirement type and implementation phase. If JSON is requested, return strict JSON only.',
          )
        },
        {'role': 'user', 'content': _requirementsPrompt(businessCase)},
      ],
    };
    if (includeResponseFormat) {
      payload['response_format'] = {'type': 'json_object'};
    }

    final response = await _client
        .post(uri, headers: headers, body: jsonEncode(OpenAiConfig.wrapBody(payload)))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 429) {
      throw Exception('API quota exceeded. Please check your OpenAI billing.');
    }
    if (response.statusCode == 401) {
      throw Exception('Invalid API key. Please check your OpenAI API key.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final bodyText = utf8.decode(response.bodyBytes).toLowerCase();
      if (response.statusCode == 400 && bodyText.contains('response_format')) {
        throw const _ResponseFormatUnsupportedException();
      }
      throw Exception(
          'OpenAI API error ${response.statusCode}: ${response.body}');
    }

    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  List<Map<String, String>> _normalizeRequirementItems(List<dynamic> items) {
    return items
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .map((item) {
          final requirement = _stripAsterisks(
              (item['requirement'] ?? item['text'] ?? '').toString().trim());
          final requirementType = _stripAsterisks((item['requirementType'] ??
                  item['requirement_type'] ??
                  item['type'] ??
                  'Functional')
              .toString()
              .trim());
          final discipline =
              _stripAsterisks((item['discipline'] ?? '').toString().trim());
          final role = _stripAsterisks(
              (item['role'] ?? item['ownerRole'] ?? '').toString().trim());
          final person = _stripAsterisks(
              (item['person'] ?? item['ownerPerson'] ?? item['assignee'] ?? '')
                  .toString()
                  .trim());
          final requirementSource = _stripAsterisks(
              (item['requirementSource'] ??
                      item['requirement_source'] ??
                      item['source'] ??
                      '')
                  .toString()
                  .trim());
          return {
            'requirement': requirement,
            'requirementType':
                requirementType.isEmpty ? 'Functional' : requirementType,
            'discipline': discipline,
            'role': role,
            'person': person,
            'phase': _normalizeRequirementPhase(item['phase'] ??
                item['implementationPhase'] ??
                item['implementation_phase']),
            'requirementSource': requirementSource,
          };
        })
        .where((e) => e['requirement']!.isNotEmpty)
        .toList();
  }

  List<Map<String, String>> _requirementsFromText(String content) {
    final lines = content
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => line.replaceAll(RegExp(r'^[\-\*\d\.\)\s]+'), ''))
        .where((line) => line.isNotEmpty)
        .toList();
    return lines
        .map((line) => {
              'requirement': _stripAsterisks(line),
              'requirementType': 'Functional',
              'discipline': '',
              'role': '',
              'person': '',
              'phase': 'Planning',
              'requirementSource': '',
            })
        .toList();
  }

  String? _extractTextFromOpenAiPayload(Map<String, dynamic> data) {
    // Delegate to OpenAiConfig.extractContent which handles both OpenAI and legacy formats
    final result = OpenAiConfig.extractContent(data);
    return result.isEmpty ? null : result;
  }

  List<dynamic>? _decodeJsonListSafely(String content) {
    // Strip markdown code fences that OpenAI may wrap around JSON arrays
    String cleaned = content.trim();
    final codeBlockRegex = RegExp(r'```(?:json)?\s*\n?([\s\S]*?)\n?```');
    final match = codeBlockRegex.firstMatch(cleaned);
    if (match != null) cleaned = match.group(1)?.trim() ?? cleaned;
    if (!cleaned.startsWith('[')) {
      // Try to find the first [ character
      final idx = cleaned.indexOf('[');
      if (idx >= 0) cleaned = cleaned.substring(idx);
      else return null;
    }
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is List) return decoded;
    } catch (_) {
      return null;
    }
    return null;
  }

  // Fallback requirements removed. OpenAI failures should surface to the UI.

  // TECHNOLOGIES
  Future<Map<String, List<String>>> generateTechnologiesForSolutions(
      List<AiSolutionItem> solutions,
      {String contextNotes = ''}) async {
    if (solutions.isEmpty) return {};
    if (!OpenAiConfig.isConfigured) throw const OpenAiNotConfiguredException();

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();
    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': 0.5,
      'max_completion_tokens': 1200,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'solutions architect identifying the core technologies or tools each solution genuinely needs',
            strictJson: true,
            extraRules:
                'For each solution, list 3-6 concrete technologies, frameworks, services, or tools. If a solution is primarily physical and does not genuinely need a digital stack, return an empty list for that solution instead of generic IT filler.',
          )
        },
        {
          'role': 'user',
          'content': _technologiesPrompt(solutions, contextNotes)
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;

      final List list = (parsed['technologies'] as List? ?? []);
      final Map<String, List<String>> result = {};
      for (var idx = 0; idx < list.length; idx++) {
        final item = list[idx];
        final map = item as Map<String, dynamic>;
        final title = _stripAsterisks((map['solution'] ?? '').toString());
        final items = (map['items'] as List? ?? [])
            .map((e) => _stripAsterisks(e.toString()))
            .where((e) => e.trim().isNotEmpty)
            .take(6)
            .toList();
        if (title.isNotEmpty && items.isNotEmpty) result[title] = items;
      }
      return _mergeWithFallbackTech(solutions, result);
    } catch (e) {
      rethrow;
    }
  }

  // Backwards-compatibility alias for any older calls with a typo
  Future<Map<String, List<String>>> generateTechnolofiesForSolutions(
          List<AiSolutionItem> solutions,
          {String contextNotes = ''}) =>
      generateTechnologiesForSolutions(solutions, contextNotes: contextNotes);

  Map<String, List<String>> _mergeWithFallbackTech(
      List<AiSolutionItem> solutions, Map<String, List<String>> generated) {
    final merged = <String, List<String>>{};
    for (final s in solutions) {
      final g = generated[s.title];
      merged[s.title] =
          (g != null && g.isNotEmpty) ? g.take(6).toList() : <String>[];
    }
    return merged;
  }

  // COST BREAKDOWN
  Future<Map<String, List<AiCostItem>>> generateCostBreakdownForSolutions(
    List<AiSolutionItem> solutions, {
    String contextNotes = '',
    String currency = 'USD',
  }) async {
    if (solutions.isEmpty) return {};
    if (!OpenAiConfig.isConfigured) {
      return _fallbackCostBreakdown(
        solutions,
        contextNotes: contextNotes,
      );
    }
    final domainHints =
        _financialDomainHints(context: contextNotes, solutions: solutions);

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();
    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': 0.45,
      'max_completion_tokens': 1400,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'cost analyst producing distinct, context-aware solution cost breakdowns',
            strictJson: true,
            extraRules:
                'Each solution must be distinct, grounded in its own scope, and should not reuse the same item list or the same costs across tabs. Do not use placeholder round values unless supported by quantities. If a solution is physical or infrastructure-led, avoid software lifecycle phases such as Discovery and Planning, MVP Build, Integration, or Data unless the context clearly requires them. Follow these financial domain guardrails:\n$domainHints',
          )
        },
        {
          'role': 'user',
          'content': _costBreakdownPrompt(
            solutions,
            contextNotes,
            currency,
            domainHints: domainHints,
          )
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 14));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;

      final List list = (parsed['cost_breakdown'] as List? ?? []);
      final Map<String, List<AiCostItem>> result = {};
      for (final entry in list) {
        final map = entry as Map<String, dynamic>;
        final title = _stripAsterisks((map['solution'] ?? '').toString());
        final itemsRaw = (map['items'] as List? ?? []);
        final items = itemsRaw
            .map((e) => AiCostItem.fromMap(e as Map<String, dynamic>))
            .where((e) => e.item.isNotEmpty)
            .toList();
        if (title.isNotEmpty && items.isNotEmpty) result[title] = items;
      }

      final sanitized = _sanitizeGeneratedCostBreakdown(
        solutions: solutions,
        generated: result,
        contextNotes: contextNotes,
      );

      return _mergeWithFallbackCost(
        solutions,
        sanitized,
        contextNotes: contextNotes,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('generateCostBreakdownForSolutions failed: $e');
      }
      return _fallbackCostBreakdown(
        solutions,
        contextNotes: contextNotes,
      );
    }
  }

  Map<String, List<AiCostItem>> _mergeWithFallbackCost(
    List<AiSolutionItem> solutions,
    Map<String, List<AiCostItem>> generated, {
    String contextNotes = '',
  }) {
    final fallback = _fallbackCostBreakdown(
      solutions,
      contextNotes: contextNotes,
    );
    final merged = <String, List<AiCostItem>>{};
    for (int i = 0; i < solutions.length; i++) {
      final solution = solutions[i];
      final generatedItems = generated[solution.title];
      merged[solution.title] =
          (generatedItems != null && generatedItems.isNotEmpty)
              ? generatedItems.take(5).toList()
              : (fallback[solution.title] ??
                  _fallbackCostItemsForSolution(
                    solution,
                    index: i,
                    contextNotes: contextNotes,
                  ));
    }
    return merged;
  }

  Map<String, List<AiCostItem>> _sanitizeGeneratedCostBreakdown({
    required List<AiSolutionItem> solutions,
    required Map<String, List<AiCostItem>> generated,
    required String contextNotes,
  }) {
    final normalized = <String, List<AiCostItem>>{};
    final seenItemCostPairs = <String>{};
    final usedSignatures = <String>{};

    for (int i = 0; i < solutions.length; i++) {
      final solution = solutions[i];
      final projectType = _detectProjectTypeForSolution(solution, contextNotes);
      final rawItems = List<AiCostItem>.from(
          generated[solution.title] ?? const <AiCostItem>[]);
      final seenNames = <String>{};
      final cleaned = <AiCostItem>[];

      for (int j = 0; j < rawItems.length; j++) {
        final raw = rawItems[j];
        final itemName = _stripAsterisks(raw.item).trim();
        if (itemName.isEmpty) continue;
        final description = _stripAsterisks(raw.description).trim();

        if (projectType != _AiProjectType.digital &&
            _isSoftwarePhaseLabel('$itemName $description')) {
          continue;
        }
        if (_isDomainMismatchForProjectType(
            '$itemName $description', projectType)) {
          continue;
        }

        final amount = raw.estimatedCost;
        if (!amount.isFinite || amount <= 0) continue;
        if (_looksGenericRoundNumber(amount)) continue;

        final nameKey = itemName.toLowerCase();
        if (seenNames.contains(nameKey)) continue;
        seenNames.add(nameKey);

        var normalizedCost = _normalizeEstimatedCost(amount);
        var npvByYear = Map<int, double>.from(raw.npvByYear);
        var pairKey = '$nameKey|${normalizedCost.toStringAsFixed(0)}';

        if (seenItemCostPairs.contains(pairKey)) {
          final adjustedCost = _nudgeDuplicateCost(
            normalizedCost,
            solutionIndex: i,
            itemIndex: j,
          );
          npvByYear = _scaleNpvByCost(
            npvByYear,
            normalizedCost,
            adjustedCost,
          );
          normalizedCost = adjustedCost;
          pairKey = '$nameKey|${normalizedCost.toStringAsFixed(0)}';
        }
        seenItemCostPairs.add(pairKey);

        cleaned.add(AiCostItem(
          item: itemName,
          description: description,
          estimatedCost: normalizedCost,
          roiPercent: _clampRoi(raw.roiPercent, projectType),
          npvByYear: _sanitizeNpv(npvByYear, normalizedCost, raw.roiPercent),
        ));
      }

      List<AiCostItem> chosen = cleaned;
      if (chosen.isEmpty) {
        chosen = _fallbackCostItemsForSolution(
          solution,
          index: i,
          contextNotes: contextNotes,
        );
      }

      var signature = chosen
          .map((e) =>
              '${e.item.toLowerCase()}|${e.estimatedCost.toStringAsFixed(0)}')
          .join(';');
      if (usedSignatures.contains(signature)) {
        chosen = _fallbackCostItemsForSolution(
          solution,
          index: i,
          contextNotes: contextNotes,
        );
        signature = chosen
            .map((e) =>
                '${e.item.toLowerCase()}|${e.estimatedCost.toStringAsFixed(0)}')
            .join(';');
      }

      usedSignatures.add(signature);
      normalized[solution.title] = chosen;
    }

    return normalized;
  }

  Map<String, List<AiCostItem>> _fallbackCostBreakdown(
    List<AiSolutionItem> solutions, {
    String contextNotes = '',
  }) {
    final map = <String, List<AiCostItem>>{};
    for (int i = 0; i < solutions.length; i++) {
      final solution = solutions[i];
      map[solution.title] = _fallbackCostItemsForSolution(
        solution,
        index: i,
        contextNotes: contextNotes,
      );
    }
    return map;
  }

  List<AiCostItem> _fallbackCostItemsForSolution(
    AiSolutionItem solution, {
    required int index,
    String contextNotes = '',
  }) {
    final type = _detectProjectTypeForSolution(solution, contextNotes);
    final combinedContext = '${solution.title} ${solution.description} $contextNotes';
    final projectScale = _detectProjectScale(combinedContext);
    final templates = _fallbackCostTemplatesForType(type);
    final seed =
        _stableHash('${solution.title}|${solution.description}|$contextNotes');
    final titleScale = 0.88 + ((seed % 35) / 100);
    final indexScale = 1 + (index * 0.08);

    // Scale cost items proportionally to project scale.
    // Small projects should have much lower costs than the template defaults.
    final scaleCostFactor = switch (projectScale) {
      _AiProjectScale.small => 0.08,  // ~8% of template cost for small projects
      _AiProjectScale.medium => 1.0,  // full template cost for medium projects
      _AiProjectScale.large => 1.5,   // 1.5x template cost for large projects
    };

    final items = <AiCostItem>[];

    for (int i = 0; i < templates.length; i++) {
      final template = templates[i];
      final baseCost = (template['cost'] as num).toDouble();
      final baseRoi = (template['roi'] as num).toDouble();
      final variation = 0.94 + (((seed + (i * 17)) % 13) / 100);
      final estimate = _normalizeEstimatedCost(
          baseCost * titleScale * indexScale * variation * scaleCostFactor);
      final roi = _clampDouble(
        baseRoi + ((((seed + i) % 7) - 3) * 0.6),
        6,
        35,
      );

      items.add(AiCostItem(
        item: (template['item'] ?? '').toString(),
        description: (template['description'] ?? '').toString(),
        estimatedCost: estimate,
        roiPercent: roi,
        npvByYear: _deriveFallbackNpv(estimate, roi),
      ));
    }

    return items;
  }

  List<Map<String, Object>> _fallbackCostTemplatesForType(_AiProjectType type) {
    switch (type) {
      case _AiProjectType.physical:
        return const [
          {
            'item': 'Site survey and feasibility studies',
            'description':
                'Topographic surveys, engineering feasibility, and early design validation.',
            'cost': 48200,
            'roi': 10.5
          },
          {
            'item': 'Permitting and regulatory approvals',
            'description':
                'Permit submissions, inspections, and statutory compliance documentation.',
            'cost': 36500,
            'roi': 9.2
          },
          {
            'item': 'Detailed engineering and technical drawings',
            'description':
                'Final design packages, safety calculations, and construction-ready drawings.',
            'cost': 72400,
            'roi': 11.8
          },
          {
            'item': 'Materials and equipment procurement',
            'description':
                'Purchase of long-lead materials, core equipment, and logistics handling.',
            'cost': 156800,
            'roi': 14.6
          },
          {
            'item': 'Civil works and installation',
            'description':
                'Ground works, structural installation, electrical/mechanical fit-out, and supervision.',
            'cost': 218500,
            'roi': 16.3
          },
          {
            'item': 'Commissioning, testing, and handover',
            'description':
                'Site acceptance tests, certification, and transition to operations.',
            'cost': 54800,
            'roi': 13.4
          },
        ];
      case _AiProjectType.digital:
        return const [
          {
            'item': 'Requirements and solution architecture',
            'description':
                'Domain analysis, architecture design, and delivery planning.',
            'cost': 42800,
            'roi': 15.0
          },
          {
            'item': 'Core platform and feature development',
            'description':
                'Implementation of core modules, workflows, and service components.',
            'cost': 138600,
            'roi': 20.4
          },
          {
            'item': 'Integration and data services',
            'description':
                'API orchestration, data pipelines, validation rules, and mapping.',
            'cost': 86400,
            'roi': 18.1
          },
          {
            'item': 'Security controls and compliance hardening',
            'description':
                'Identity controls, audit trail design, encryption, and compliance checks.',
            'cost': 57400,
            'roi': 16.2
          },
          {
            'item': 'Quality assurance and user acceptance testing',
            'description':
                'Automated and manual test cycles, defect remediation, and release readiness.',
            'cost': 51600,
            'roi': 14.9
          },
          {
            'item': 'Deployment, enablement, and support transition',
            'description':
                'Production rollout, user onboarding, runbook setup, and stabilization support.',
            'cost': 46300,
            'roi': 13.8
          },
        ];
      case _AiProjectType.hybrid:
        return const [
          {
            'item': 'Program mobilization and integrated planning',
            'description':
                'Joint planning across facility, operations, and digital delivery streams.',
            'cost': 59800,
            'roi': 12.7
          },
          {
            'item': 'Facility and infrastructure preparation',
            'description':
                'Physical site preparation, utilities readiness, and installation pre-work.',
            'cost': 129400,
            'roi': 15.4
          },
          {
            'item': 'Application build and configuration',
            'description':
                'Configuration of software components that support the physical rollout.',
            'cost': 102800,
            'roi': 17.3
          },
          {
            'item': 'Systems integration and data onboarding',
            'description':
                'Integration between new assets, enterprise systems, and reporting platforms.',
            'cost': 78100,
            'roi': 16.0
          },
          {
            'item': 'Operational readiness and workforce training',
            'description':
                'Process handover, SOP updates, and role-based enablement training.',
            'cost': 49400,
            'roi': 13.2
          },
          {
            'item': 'Cutover, stabilization, and optimization',
            'description':
                'Go-live support, performance tuning, and early value capture tracking.',
            'cost': 43600,
            'roi': 14.1
          },
        ];
      case _AiProjectType.service:
        return const [
          {
            'item': 'Service design and operating model definition',
            'description':
                'Service blueprinting, target operating model decisions, and launch planning.',
            'cost': 38400,
            'roi': 13.8
          },
          {
            'item': 'Regulatory, policy, and compliance setup',
            'description':
                'Policy drafting, licensing readiness, compliance controls, and approvals.',
            'cost': 29600,
            'roi': 11.7
          },
          {
            'item': 'Staffing, onboarding, and capability development',
            'description':
                'Hiring, training, role definition, and workforce readiness activities.',
            'cost': 61200,
            'roi': 15.2
          },
          {
            'item': 'Service delivery tooling and process enablement',
            'description':
                'Operational workflows, customer handling processes, and support tooling.',
            'cost': 54800,
            'roi': 14.9
          },
          {
            'item': 'Launch communications and stakeholder onboarding',
            'description':
                'Awareness campaigns, partner coordination, and end-user onboarding support.',
            'cost': 27300,
            'roi': 12.6
          },
          {
            'item': 'Performance monitoring and service stabilization',
            'description':
                'Early-stage KPI tracking, issue resolution, and process optimization after launch.',
            'cost': 24100,
            'roi': 13.5
          },
        ];
      case _AiProjectType.unknown:
        return const [
          {
            'item': 'Scope definition and delivery planning',
            'description':
                'Detailed scope baseline, scheduling, and dependency planning.',
            'cost': 45600,
            'roi': 11.5
          },
          {
            'item': 'Vendor and specialist mobilization',
            'description':
                'Procurement, vendor onboarding, and contract activation costs.',
            'cost': 68400,
            'roi': 13.1
          },
          {
            'item': 'Implementation work packages',
            'description':
                'Execution of core workstreams needed to deliver project outcomes.',
            'cost': 122900,
            'roi': 15.9
          },
          {
            'item': 'Quality assurance and compliance controls',
            'description':
                'Assurance gates, quality checks, and regulatory control activities.',
            'cost': 53700,
            'roi': 12.4
          },
          {
            'item': 'Change enablement and operational transition',
            'description':
                'Operational handoff, training, and adoption support for target users.',
            'cost': 41200,
            'roi': 10.9
          },
          {
            'item': 'Post-go-live performance optimization',
            'description':
                'Performance tuning, issue reduction, and early-stage enhancement work.',
            'cost': 38900,
            'roi': 12.0
          },
        ];
    }
  }

  String _costBreakdownPrompt(
    List<AiSolutionItem> solutions,
    String notes,
    String currency, {
    required String domainHints,
  }) {
    final safeNotes = notes.trim().isEmpty ? 'None' : _escape(notes.trim());
    final list = solutions.map((s) {
      final typeHint = _projectTypeLabel(
        _detectProjectTypeForSolution(s, notes),
      );
      return '{"title": "${_escape(s.title)}", "description": "${_escape(s.description)}", "project_type_hint": "$typeHint"}';
    }).join(',');
    final currencyInstruction = _currencyConversionInstruction(currency);
    return '''
For each solution below, provide a cost breakdown with up to 20 items (aim for 8-20 when possible).
Each item must include: item, description, estimated_cost (number in $currency), roi_percent (number), and npv_by_years (keys "3_years", "5_years", "10_years" with numeric values in $currency).

CRITICAL — Realistic Financial Guidelines:
- Every estimated_cost MUST be a realistic, non-zero value based on real-world market rates.
- NEVER return estimated_cost as 0 or null. Minimum is \$5,000.
- Research-based cost ranges (USD) by project type:
  • Healthcare/Software platform: \$50,000–\$2,000,000+
  • Physical pharmacy/construction: \$100,000–\$5,000,000+
  • Digital transformation: \$75,000–\$1,500,000
  • Staffing/Training: \$20,000–\$500,000
  • Regulatory/Compliance: \$10,000–\$200,000
  • Monitoring/Ongoing: \$15,000–\$300,000/year (NEVER \$0)

CRITICAL — ROI and NPV Consistency Rules:
- roi_percent is the RETURN ON INVESTMENT percentage for that line item.
  Realistic ranges: 5%–45% for most projects. NEVER exceed 100% per item.
  Higher-risk digital projects may go up to 60%. Physical projects typically 10%–25%.
- npv_by_years MUST be the NET PRESENT VALUE of future cash flows from that item.
  NPV MUST be positive if ROI is positive.
  NPV MUST increase with time horizon: 10_years > 5_years > 3_years.
  NPV at 5_years should typically be 1.2x–3x the estimated_cost for profitable items.
  Example: if estimated_cost is \$50,000 and roi_percent is 20%, then:
    npv_3_years ≈ \$15,000–\$25,000
    npv_5_years ≈ \$30,000–\$50,000
    npv_10_years ≈ \$60,000–\$100,000
- For physical/infrastructure projects, ROI should be lower (10%–25%) with
  proportionally lower NPV values.
- For digital/software projects, ROI can be higher (20%–60%) with
  proportionally higher NPV values.
- Total project ROI should be a weighted average of item ROIs, NOT a sum.
- Vary costs, ROIs, and NPVs across items — do not use identical values.

Rules:
- Detect the project type per solution (physical construction/infrastructure, digital/software, or hybrid) and use domain-appropriate line items.
- Physical solutions must not use software lifecycle placeholders such as Discovery and Planning, MVP Build, Integration, or Data.
- Do not return repetitive placeholder amounts (100000, 250000, 500000) unless explicitly justified from context quantities.
- Ensure solutions are distinct: avoid identical item lists and identical costs across different solutions.
- If confidence is low for a specific line item, omit it instead of inventing a generic entry.
- Be detailed and specific: do not use "etc.", "and similar", or vague groupings.
- All monetary values (estimated_cost, npv_by_years) must be in $currency.$currencyInstruction

Return ONLY valid JSON with this exact structure:
{
  "cost_breakdown": [
    {"solution": "Solution Name", "items": [
      {"item": "Project Item", "description": "...", "estimated_cost": 12345, "roi_percent": 18.5, "npv_by_years": {"3_years": 5600, "5_years": 7800, "10_years": 12800}}
    ]}
  ]
}

Solutions: [$list]

Context notes (optional): $safeNotes

Domain guardrails:
$domainHints
''';
  }

  String _projectTypeLabel(_AiProjectType type) {
    switch (type) {
      case _AiProjectType.physical:
        return 'physical';
      case _AiProjectType.digital:
        return 'digital';
      case _AiProjectType.hybrid:
        return 'hybrid';
      case _AiProjectType.service:
        return 'service';
      case _AiProjectType.unknown:
        return 'unknown';
    }
  }

  String _detectDeliveryStartingPoint(String text, _AiProjectType projectType) {
    final normalized = text.toLowerCase();
    if (normalized.trim().isEmpty) return 'greenfield (from scratch)';

    final existingOperation = _containsAnyKeywords(normalized, [
      'existing',
      'already operating',
      'current operation',
      'current facility',
      'legacy',
      'brownfield',
      'retrofit',
      'renovation',
      'upgrade',
      'expansion',
      'live environment',
      'in production',
    ]);

    final digitalUpgradeCue = _containsAnyKeywords(normalized, [
      'digital enhancement',
      'digitisation',
      'digitization',
      'system upgrade',
      'software upgrade',
      'automation only',
      'without construction',
      'existing site only needs digital',
      'existing facility needs software',
    ]);

    final constructionCue = _containsAnyKeywords(normalized, [
      'construction',
      'new build',
      'greenfield',
      'site development',
      'civil works',
      'ground-up',
      'new facility',
    ]);

    if ((digitalUpgradeCue || projectType == _AiProjectType.digital) &&
        existingOperation &&
        !constructionCue) {
      return 'digital enhancement only';
    }
    if (existingOperation && !constructionCue) {
      return 'brownfield (existing operation/facility)';
    }
    return 'greenfield (from scratch)';
  }

  String _financialMetricFocusForType(_AiProjectType type) {
    switch (type) {
      case _AiProjectType.physical:
        return 'Focus on demand volume, customer traffic, throughput, material/equipment utilization, labour productivity, waste reduction, and compliance-cost impact.';
      case _AiProjectType.digital:
        return 'Focus on acquisition/conversion, active usage, retention/churn where applicable, cloud/platform operating cost, security risk cost, and deployment velocity.';
      case _AiProjectType.hybrid:
        return 'Balance physical readiness costs (site, permits, equipment, staffing) with digital enablement costs (systems, integrations, data, security, support).';
      case _AiProjectType.service:
        return 'Focus on service capacity, response time, quality outcomes, utilisation, staffing efficiency, and recurring operating margins.';
      case _AiProjectType.unknown:
        return 'Use conservative assumptions, make explicit assumptions, and avoid domain-specific claims that are not supported by context.';
    }
  }

  String _financialDomainHints({
    required String context,
    List<AiSolutionItem> solutions = const [],
  }) {
    final solutionContext = solutions
        .map((s) => '${s.title} ${s.description}')
        .where((e) => e.trim().isNotEmpty)
        .join('\n');
    final combined = '$context\n$solutionContext'.trim();
    final detectedType = _detectProjectType(combined);
    final typeLabel = _projectTypeLabel(detectedType);
    final detectedScale = _detectProjectScale(combined);
    final scaleLabel = _projectScaleLabel(detectedScale);
    final startingPoint = _detectDeliveryStartingPoint(combined, detectedType);
    final focus = _financialMetricFocusForType(detectedType);

    final scaleGuidance = switch (detectedScale) {
      _AiProjectScale.small =>
        'Project scale is SMALL (local business, small team). All financial estimates must be proportionally small — e.g., barbershop/salon monthly benefits in the hundreds, not thousands.',
      _AiProjectScale.medium =>
        'Project scale is MEDIUM (department/mid-size business). Financial estimates should reflect mid-range values.',
      _AiProjectScale.large =>
        'Project scale is LARGE (enterprise/infrastructure). Financial estimates can reflect larger values consistent with enterprise scope.',
    };

    final guardrails = switch (detectedType) {
      _AiProjectType.physical =>
        'Avoid SaaS-only metrics like CAC, LTV, MRR, ARR, churn, and trial-to-paid unless context explicitly requests a digital business model.',
      _AiProjectType.digital =>
        'Avoid physical construction assumptions such as excavation, concrete, rebar, site permits, and civil works unless context explicitly requires physical setup.',
      _AiProjectType.service =>
        'Avoid construction-heavy assumptions and avoid SaaS-only revenue metrics unless the context explicitly indicates those models.',
      _AiProjectType.hybrid =>
        'Cover both physical and digital dimensions in proportion to stated scope; do not over-index on one side without evidence.',
      _AiProjectType.unknown =>
        'Default to greenfield assumptions and mark assumptions explicitly instead of inventing unsupported domain specifics.',
    };

    return '''
Detected project type: $typeLabel
Detected project scale: $scaleLabel
Scale guidance: $scaleGuidance
Detected starting point: $startingPoint
Domain metric focus: $focus
Domain guardrail: $guardrails
''';
  }

  bool _isDomainMismatchForProjectType(String text, _AiProjectType type) {
    final normalized = text.toLowerCase();
    if (normalized.trim().isEmpty) return false;

    const saasTerms = <String>[
      'churn',
      'cac',
      'ltv',
      'mrr',
      'arr',
      'trial-to-paid',
      'trial conversion',
      'monthly active users',
      'daily active users',
      'onboarding funnel',
      'freemium',
      'subscription tier',
    ];
    const physicalTerms = <String>[
      'excavation',
      'earthworks',
      'foundation',
      'concrete',
      'rebar',
      'civil works',
      'site clearing',
      'asphalt',
      'structural steel',
      'permit inspections',
    ];

    switch (type) {
      case _AiProjectType.physical:
        return _containsAnyKeywords(normalized, saasTerms);
      case _AiProjectType.digital:
        return _containsAnyKeywords(normalized, physicalTerms);
      case _AiProjectType.service:
        return _containsAnyKeywords(
            normalized, [...saasTerms, ...physicalTerms]);
      case _AiProjectType.hybrid:
      case _AiProjectType.unknown:
        return false;
    }
  }

  bool _looksTooGenericFinancialText(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    if (normalized == 'reduce churn via onboarding improvements') return true;

    if (RegExp(
      r'^(revenue|cost saving|operational efficiency|productivity|regulatory(?:\s*&\s*|\s+and\s+)?compliance|process improvement|brand image|stakeholder commitment|other)\s+impact$',
    ).hasMatch(normalized)) {
      return true;
    }

    const weakPhrases = <String>[
      'improve efficiency',
      'increase revenue',
      'reduce costs',
      'enhance productivity',
      'optimize operations',
      'streamline processes',
      'business growth',
      'improve outcomes',
    ];
    return weakPhrases.any(
      (phrase) => normalized == phrase || normalized == '$phrase.',
    );
  }

  _AiProjectType _detectProjectType(String text) {
    final normalized = text.toLowerCase();
    if (normalized.trim().isEmpty) return _AiProjectType.unknown;

    int physicalScore = 0;
    int digitalScore = 0;
    int serviceScore = 0;

    bool hasAny(List<String> terms) =>
        terms.any((term) => _containsKeyword(normalized, term));

    if (hasAny([
      'construction',
      'building',
      'facility',
      'fire station',
      'civil works',
      'infrastructure',
      'site',
      'foundation',
      'equipment installation',
      'procurement',
      'plant',
      'warehouse',
      'road',
      'bridge',
      'hospital wing',
      'physical',
      'utilities',
      'commissioning',
      'contractor',
    ])) {
      physicalScore += 4;
    }

    if (hasAny([
      'software',
      'application',
      'platform',
      'api',
      'integration service',
      'cloud',
      'data pipeline',
      'mobile',
      'web portal',
      'erp',
      'crm',
      'sprint',
      'release',
      'devops',
      'database',
      'automation script',
    ])) {
      digitalScore += 4;
    }

    if (hasAny(
        ['sensor', 'iot', 'smart facility', 'scada', 'control system'])) {
      physicalScore += 2;
      digitalScore += 2;
    }

    if (hasAny([
      'service',
      'operations',
      'operational',
      'training programme',
      'training program',
      'consulting',
      'non-profit',
      'nonprofit',
      'customer support',
      'call center',
      'help desk',
      'programme',
      'program',
      'process improvement',
      'service delivery',
      'service launch',
      'coaching',
      'advisory',
    ])) {
      serviceScore += 4;
    }

    if (physicalScore >= 4 && digitalScore >= 4) {
      return _AiProjectType.hybrid;
    }
    if (serviceScore >= 4 && physicalScore == 0 && digitalScore == 0) {
      return _AiProjectType.service;
    }
    if (serviceScore >= 4 &&
        ((physicalScore > 0 && digitalScore == 0) ||
            (digitalScore > 0 && physicalScore == 0))) {
      return _AiProjectType.service;
    }
    if (physicalScore >= digitalScore + 2 && physicalScore >= 3) {
      return _AiProjectType.physical;
    }
    if (digitalScore >= physicalScore + 2 && digitalScore >= 3) {
      return _AiProjectType.digital;
    }
    if (serviceScore > 0 && physicalScore == 0 && digitalScore == 0) {
      return _AiProjectType.service;
    }
    if (physicalScore > 0 && digitalScore == 0) return _AiProjectType.physical;
    if (digitalScore > 0 && physicalScore == 0) return _AiProjectType.digital;
    return _AiProjectType.unknown;
  }

  bool _containsKeyword(String normalizedText, String term) {
    final trimmed = term.trim().toLowerCase();
    if (trimmed.isEmpty) return false;
    if (trimmed.contains(' ')) {
      return normalizedText.contains(trimmed);
    }
    final pattern = RegExp('\\b${RegExp.escape(trimmed)}\\b');
    return pattern.hasMatch(normalizedText);
  }

  bool _containsAnyKeywords(String normalizedText, List<String> terms) {
    for (final term in terms) {
      if (_containsKeyword(normalizedText, term)) {
        return true;
      }
    }
    return false;
  }

  /// Detects the scale of a project based on contextual clues such as
  /// business type, budget indicators, team size hints, and scope keywords.
  /// Small = barbershop, salon, small retail, sole proprietor (budget < $50K)
  /// Medium = department-level, mid-size business (budget $50K–$200K)
  /// Large = enterprise, infrastructure, multi-site (budget $200K+)
  _AiProjectScale _detectProjectScale(String text) {
    final normalized = text.toLowerCase();
    if (normalized.trim().isEmpty) return _AiProjectScale.medium;

    // --- Small-scale indicators ---
    final smallIndicators = <String>[
      'barbershop', 'barber shop', 'salon', 'hair salon', 'nail salon',
      'small business', 'small retail', 'sole proprietor', 'mom and pop',
      'local shop', 'local store', 'boutique', 'freelance', 'solo',
      'micro business', 'home-based', 'pop-up', 'food truck', 'food cart',
      'corner store', 'kiosk', 'stall', 'personal brand',
      'pet grooming', 'dog walking', 'tutoring', 'cleaning service',
      'lawn care', 'small clinic', 'dental practice', 'yoga studio',
      'gym studio', 'personal training', 'craft', 'artisan',
      'personal app', 'portfolio app', 'booking app', 'appointment app',
    ];
    int smallScore = 0;
    for (final term in smallIndicators) {
      if (normalized.contains(term)) smallScore += 3;
    }
    // Budget hints for small scale
    if (_containsAnyKeywords(normalized, [
      'under 50k', '<50k', '< 50,000', 'under \$50', 'budget of \$10',
      'budget of \$15', 'budget of \$20', 'budget of \$25', 'budget of \$30',
      'budget of \$35', 'budget of \$40', 'budget of \$45',
    ])) {
      smallScore += 4;
    }
    // Team size hints for small scale
    if (_containsAnyKeywords(normalized, [
      '1-3 people', '1-3 team', '2-5 team', 'solo developer',
      'small team', 'tiny team',
    ])) {
      smallScore += 3;
    }

    // --- Large-scale indicators ---
    final largeIndicators = <String>[
      'enterprise', 'corporation', 'multi-site', 'multi-site',
      'infrastructure', 'government', 'municipal', 'federal',
      'hospital', 'university', 'campus', 'city-wide', 'nationwide',
      'global', 'regional', 'district', 'province', 'state-wide',
      'construction project', 'civil works', 'industrial',
      'manufacturing plant', 'power plant', 'data center', 'data centre',
      'oil and gas', 'mining', 'pipeline', 'railway', 'airport',
      'large-scale', 'large scale', 'multi-phase', 'multi-year',
      'multi-million', 'enterprise resource planning', 'erp implementation',
      'digital transformation',
    ];
    int largeScore = 0;
    for (final term in largeIndicators) {
      if (normalized.contains(term)) largeScore += 3;
    }
    // Budget hints for large scale
    if (_containsAnyKeywords(normalized, [
      'over 200k', '>200k', '> 200,000', 'over \$200', 'budget of \$500',
      'budget of \$1m', 'budget of \$2m', 'million', 'multi-million',
    ])) {
      largeScore += 4;
    }
    // Team size hints for large scale
    if (_containsAnyKeywords(normalized, [
      '50+ people', '100+ team', 'large team', 'enterprise team',
      'cross-functional team', 'multiple teams',
    ])) {
      largeScore += 3;
    }

    // --- Decision logic ---
    if (smallScore >= 3 && largeScore < 3) return _AiProjectScale.small;
    if (largeScore >= 3 && smallScore < 3) return _AiProjectScale.large;
    if (smallScore >= 3 && smallScore > largeScore) return _AiProjectScale.small;
    if (largeScore >= 3 && largeScore > smallScore) return _AiProjectScale.large;
    // Default to medium when no strong signal
    return _AiProjectScale.medium;
  }

  String _projectScaleLabel(_AiProjectScale scale) {
    switch (scale) {
      case _AiProjectScale.small:
        return 'small';
      case _AiProjectScale.medium:
        return 'medium';
      case _AiProjectScale.large:
        return 'large';
    }
  }

  // ── Financial value clamping ──────────────────────────────────────────
  // Post-processing guardrails that clamp AI-generated values to
  // scale-appropriate ranges.  These run AFTER the model response is
  // parsed so that even if the model ignores prompt instructions the
  // values presented to users remain realistic.

  /// Maximum realistic monthly benefit unit value for the given project scale.
  double _maxMonthlyBenefitUnitValue(_AiProjectScale scale) => switch (scale) {
        _AiProjectScale.small => 1500,
        _AiProjectScale.medium => 8000,
        _AiProjectScale.large => 40000,
      };

  /// Maximum realistic one-off cost for a single line item at the given scale.
  double _maxSingleItemCost(_AiProjectScale scale) => switch (scale) {
        _AiProjectScale.small => 25000,
        _AiProjectScale.medium => 150000,
        _AiProjectScale.large => 1000000,
      };

  /// Maximum realistic monthly staffing cost per role at the given scale.
  double _maxMonthlyStaffCost(_AiProjectScale scale) => switch (scale) {
        _AiProjectScale.small => 3000,
        _AiProjectScale.medium => 8000,
        _AiProjectScale.large => 15000,
      };

  /// Minimum realistic monthly staffing cost per role at the given scale.
  double _minMonthlyStaffCost(_AiProjectScale scale) => switch (scale) {
        _AiProjectScale.small => 500,
        _AiProjectScale.medium => 1500,
        _AiProjectScale.large => 3000,
      };

  /// Clamp a benefit unit value to the scale-appropriate maximum.
  double _clampBenefitValue(double value, _AiProjectScale scale) {
    final maxVal = _maxMonthlyBenefitUnitValue(scale);
    if (value > maxVal) return maxVal;
    if (value <= 0) return 0;
    return value;
  }

  /// Clamp a single cost estimate to the scale-appropriate range.
  double _clampCostValue(double value, _AiProjectScale scale) {
    final maxVal = _maxSingleItemCost(scale);
    if (value > maxVal) return maxVal;
    if (value <= 0) return 5000;
    return _normalizeEstimatedCost(value);
  }

  /// Clamp ROI to realistic ranges based on project type.
  double _clampRoi(double roi, _AiProjectType projectType) {
    if (roi.isNaN || roi < 0) return 10.0;
    double maxRoi;
    switch (projectType) {
      case _AiProjectType.digital:
        maxRoi = 60.0;
        break;
      case _AiProjectType.physical:
        maxRoi = 30.0;
        break;
      case _AiProjectType.hybrid:
        maxRoi = 45.0;
        break;
      default:
        maxRoi = 45.0;
    }
    if (roi < 5.0) return 5.0;
    if (roi > maxRoi) return maxRoi;
    return roi;
  }

  /// Sanitize NPV values to ensure mathematical consistency.
  Map<int, double> _sanitizeNpv(
      Map<int, double> npvByYear, double estimatedCost, double roi) {
    if (npvByYear.isEmpty || estimatedCost <= 0) {
      final roiDecimal = (roi.isNaN || roi <= 0) ? 0.15 : roi / 100.0;
      return {
        3: estimatedCost * roiDecimal * 1.5,
        5: estimatedCost * roiDecimal * 2.5,
        10: estimatedCost * roiDecimal * 4.0,
      };
    }

    final sanitized = <int, double>{};
    final sortedYears = npvByYear.keys.toList()..sort();

    double prevNpv = 0;
    for (final year in sortedYears) {
      var npv = npvByYear[year]!;
      if (npv.isNaN || npv < 0) {
        npv = estimatedCost * 0.3 * (year / 5.0);
      }
      if (npv < prevNpv) {
        npv = prevNpv * 1.15;
      }
      if (year == 5) {
        final roiDecimal = (roi.isNaN || roi <= 0) ? 0.15 : roi / 100.0;
        final minNpv = estimatedCost * roiDecimal * 1.5;
        final maxNpv = estimatedCost * roiDecimal * 4.0;
        if (npv < minNpv) npv = minNpv;
        if (npv > maxNpv) npv = maxNpv;
      }
      sanitized[year] = npv;
      prevNpv = npv;
    }

    return sanitized;
  }

  /// Clamp a monthly staffing cost to the scale-appropriate range.
  double _clampStaffCost(double value, _AiProjectScale scale) {
    final minVal = _minMonthlyStaffCost(scale);
    final maxVal = _maxMonthlyStaffCost(scale);
    if (value < minVal) return minVal;
    if (value > maxVal) return maxVal;
    return value;
  }

  /// Clamp a projected savings value relative to the total benefit value.
  double _clampSavingsValue(double value, double totalBenefit) {
    if (value <= 0) return 0;
    // Savings cannot exceed 30% of total benefit (optimistic upper bound)
    final maxSavings = totalBenefit * 0.30;
    if (value > maxSavings) return maxSavings;
    return value;
  }

  /// Returns a scale-specific prompt fragment for financial realism.
  String _scaleFinancialConstraints(_AiProjectScale scale) {
    return switch (scale) {
      _AiProjectScale.small =>
        'CRITICAL SCALE CONSTRAINT: This is a SMALL-SCALE project (local business, small team). '
        'Monthly benefit unit values MUST NOT exceed \$1,500. '
        'Monthly staffing costs MUST be \$500-\$3,000 per role. '
        'Total project budget is likely under \$50K. '
        'Any value suggesting \$5,000+/mo benefit for a single category is UNREALISTIC and will be rejected. '
        'A barbershop making \$8K/mo cannot realize \$3K/mo in new revenue from one app feature.',
      _AiProjectScale.medium =>
        'SCALE CONSTRAINT: This is a MEDIUM-SCALE project (department/mid-size business). '
        'Monthly benefit unit values should range \$1,000-\$8,000. '
        'Monthly staffing costs should be \$1,500-\$8,000 per role. '
        'Total project budget is likely \$50K-\$200K.',
      _AiProjectScale.large =>
        'SCALE CONSTRAINT: This is a LARGE-SCALE project (enterprise/infrastructure). '
        'Monthly benefit unit values can range \$5,000-\$40,000. '
        'Monthly staffing costs can be \$3,000-\$15,000 per role for senior positions. '
        'Total project budget is likely \$200K+.',
    };
  }

  /// Returns scale-specific duration guidance for schedule activities.
  String _scaleDurationGuidance(_AiProjectScale scale) {
    return switch (scale) {
      _AiProjectScale.small =>
        'TIMELINE CONSTRAINT: This is a SMALL project. Total project duration should be 1-12 weeks. '
        'Individual activities should be 1-10 working days. Do NOT suggest multi-month phases. '
        'A simple booking app does not need 6 months of development.',
      _AiProjectScale.medium =>
        'TIMELINE CONSTRAINT: This is a MEDIUM project. Total duration should be 3-9 months. '
        'Individual activities should be 3-30 working days. Phases can span 1-3 months.',
      _AiProjectScale.large =>
        'TIMELINE CONSTRAINT: This is a LARGE project. Total duration can be 9-24+ months. '
        'Individual activities should be 5-60 working days. Phases can span 2-6 months.',
    };
  }

  /// Returns scale-specific staffing cost guidance.
  String _scaleStaffingCostGuidance(_AiProjectScale scale) {
    return switch (scale) {
      _AiProjectScale.small =>
        'STAFFING COST CONSTRAINT: Small/local business in Africa — monthly cost per role MUST be \$500-\$3,000. '
        'A barbershop manager earns ~\$800-\$2,000/mo, a part-time developer ~\$1,000-\$2,500/mo. '
        'Do NOT suggest \$8,000/mo for any single role in a small business context.',
      _AiProjectScale.medium =>
        'STAFFING COST GUIDANCE: Mid-size enterprise — monthly cost per role typically \$1,500-\$8,000. '
        'Project managers: \$3,000-\$6,000/mo. Senior developers: \$4,000-\$8,000/mo. '
        'Business analysts: \$2,000-\$5,000/mo.',
      _AiProjectScale.large =>
        'STAFFING COST GUIDANCE: Large enterprise — monthly cost per role typically \$3,000-\$15,000. '
        'Program managers: \$6,000-\$12,000/mo. Solution architects: \$8,000-\$15,000/mo. '
        'Senior engineers: \$5,000-\$10,000/mo.',
    };
  }

  _AiProjectType _detectProjectTypeForSolution(
    AiSolutionItem solution,
    String contextNotes,
  ) {
    final solutionOnly =
        '${solution.title} ${solution.description}'.toLowerCase();

    final hasStrongPhysicalCue = _containsAnyKeywords(solutionOnly, [
      'construction',
      'building',
      'facility',
      'fire station',
      'civil works',
      'infrastructure',
      'site',
      'foundation',
      'commissioning',
      'contractor',
      'procurement',
    ]);

    final hasStrongDigitalCue = _containsAnyKeywords(solutionOnly, [
      'software',
      'application',
      'platform',
      'api',
      'mobile',
      'web portal',
      'cloud',
      'devops',
      'database',
      'data pipeline',
      'automation script',
    ]);

    if (hasStrongPhysicalCue && !hasStrongDigitalCue) {
      return _AiProjectType.physical;
    }

    final directType = _detectProjectType(solutionOnly);
    if (directType != _AiProjectType.unknown) {
      return directType;
    }

    return _detectProjectType(
      '$solutionOnly $contextNotes',
    );
  }

  double _extractLargestCurrencyAnchor(String text) {
    if (text.trim().isEmpty) return 0;
    final matches = RegExp(
      r'(?:(?:usd|eur|gbp|zmw|\$)\s*)?([0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]+)?|[0-9]+(?:\.[0-9]+)?)',
      caseSensitive: false,
    ).allMatches(text);

    double largest = 0;
    for (final match in matches) {
      final raw = match.group(1);
      if (raw == null || raw.isEmpty) continue;
      final parsed = double.tryParse(raw.replaceAll(',', ''));
      if (parsed == null || parsed < 1000) continue;
      if (parsed > largest) largest = parsed;
    }
    return largest;
  }

  bool _looksGenericRoundNumber(double value) {
    if (!value.isFinite || value <= 0) return false;
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() > 0.01) return false;
    final intValue = rounded.toInt().abs();
    if (intValue < 50000) return false;

    return intValue % 50000 == 0 ||
        intValue == 250000 ||
        intValue == 500000 ||
        intValue == 1000000;
  }

  bool _isSoftwarePhaseLabel(String text) {
    final normalized = text.toLowerCase();
    const softwarePatterns = [
      'discovery and planning',
      'discovery & planning',
      'mvp build',
      'integration & data',
      'integration and data',
      'sprint',
      'backlog',
      'user story',
      'api integration',
      'data migration',
      'release pipeline',
      'devops',
      'qa automation',
    ];
    return softwarePatterns.any((pattern) => normalized.contains(pattern));
  }

  double _normalizeEstimatedCost(double value) {
    if (!value.isFinite || value <= 0) return 0;
    final normalized = (value / 50).round() * 50.0;
    return normalized > 0 ? normalized : 0;
  }

  double _nudgeDuplicateCost(
    double baseCost, {
    required int solutionIndex,
    required int itemIndex,
  }) {
    final multiplier =
        1 + ((solutionIndex + 1) * 0.03) + ((itemIndex % 4) * 0.01);
    final scaled = _normalizeEstimatedCost(baseCost * multiplier);
    final offset = ((solutionIndex + 1) * 35) + ((itemIndex + 1) * 10);
    return _normalizeEstimatedCost(scaled + offset);
  }

  Map<int, double> _scaleNpvByCost(
    Map<int, double> current,
    double oldCost,
    double newCost,
  ) {
    if (current.isEmpty || !oldCost.isFinite || oldCost <= 0) {
      return _deriveFallbackNpv(newCost, 12);
    }
    final factor = newCost / oldCost;
    final scaled = <int, double>{};
    for (final entry in current.entries) {
      scaled[entry.key] = _normalizeEstimatedCost(entry.value * factor);
    }
    return scaled;
  }

  Map<int, double> _deriveFallbackNpv(double estimatedCost, double roiPercent) {
    final annualReturn = estimatedCost * (roiPercent / 100);
    double positive(double value) {
      if (!value.isFinite || value <= 0) return 0;
      return _normalizeEstimatedCost(value);
    }

    return {
      3: positive((annualReturn * 1.9) - (estimatedCost * 0.12)),
      5: positive((annualReturn * 3.1) - (estimatedCost * 0.18)),
      10: positive((annualReturn * 5.8) - (estimatedCost * 0.25)),
    };
  }

  double _clampDouble(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// Clamps an AI-returned estimated project value to a realistic maximum
  /// based on the detected project scale. Only caps from above — never
  /// inflates a value that the AI intentionally set lower.
  double _clampToProjectScale(double value, _AiProjectScale scale) {
    if (!value.isFinite || value <= 0) return value;
    final maxAllowed = switch (scale) {
      _AiProjectScale.small => 30000.0,
      _AiProjectScale.medium => 150000.0,
      _AiProjectScale.large => 500000.0,
    };
    return value > maxAllowed ? _normalizeEstimatedCost(maxAllowed) : value;
  }

  int _stableHash(String input) {
    var hash = 0;
    for (final codeUnit in input.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    return hash;
  }

  Future<AiProjectValueInsights> generateProjectValueInsights(
    List<AiSolutionItem> solutions, {
    String contextNotes = '',
  }) async {
    final combinedText =
        '$contextNotes ${solutions.map((s) => '${s.title} ${s.description}').join(' ')}';
    final detectedType = _detectProjectType(combinedText);
    final detectedScale = _detectProjectScale(combinedText);
    final domainHints =
        _financialDomainHints(context: contextNotes, solutions: solutions);
    if (!OpenAiConfig.isConfigured) {
      return _fallbackProjectValueInsights(
        solutions,
        contextNotes: contextNotes,
      );
    }

    final scaleHint = _projectScaleLabel(detectedScale);
    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();
    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': 0.4,
      'max_completion_tokens': 900,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'financial analyst preparing a solution-specific cost-benefit analysis',
            strictJson: true,
            extraRules:
                'Focus on the exact solution context provided in the request and estimate direct financial value, ROI, cost savings, revenue potential, and quantifiable benefits for that solution only. Do not output SaaS metrics for non-digital projects, and do not output construction assumptions for purely digital projects. The detected project scale is $scaleHint — you MUST scale all financial estimates to match this scale. Small projects should have small benefit numbers, NOT enterprise-level figures. Follow these domain guardrails:\n$domainHints',
          )
        },
        {
          'role': 'user',
          'content': _projectValuePrompt(
            solutions,
            contextNotes,
            domainHints: domainHints,
            projectScale: detectedScale,
          )
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;
      final valueMap =
          (parsed['project_value'] ?? parsed) as Map<String, dynamic>;
      final insights = AiProjectValueInsights.fromMap(valueMap);
      final mergedNarratives = [
        insights.benefits['revenue'] ?? '',
        insights.benefits['cost_saving'] ?? '',
        insights.benefits['ops_efficiency'] ?? '',
        insights.benefits['productivity'] ?? '',
        insights.benefits['regulatory_compliance'] ?? '',
        insights.benefits['process_improvement'] ?? '',
        insights.benefits['brand_image'] ?? '',
        insights.benefits['stakeholder_commitment'] ?? '',
        insights.benefits['other'] ?? '',
      ].join(' ');

      if (insights.estimatedProjectValue <= 0 ||
          _looksTooGenericFinancialText(mergedNarratives) ||
          _isDomainMismatchForProjectType(mergedNarratives, detectedType)) {
        return _fallbackProjectValueInsights(
          solutions,
          contextNotes: contextNotes,
        );
      }

      // Clamp AI-returned estimated value to realistic range for the detected scale
      final clampedValue = _clampToProjectScale(
        insights.estimatedProjectValue,
        detectedScale,
      );
      if (clampedValue < insights.estimatedProjectValue) {
        return AiProjectValueInsights(
          estimatedProjectValue: clampedValue,
          benefits: insights.benefits,
        );
      }

      return insights;
    } catch (e) {
      if (kDebugMode) debugPrint('generateProjectValueInsights failed: $e');
      return _fallbackProjectValueInsights(
        solutions,
        contextNotes: contextNotes,
      );
    }
  }

  AiProjectValueInsights _fallbackProjectValueInsights(
    List<AiSolutionItem> solutions, {
    String contextNotes = '',
  }) {
    final firstSolution = solutions.isNotEmpty
        ? solutions.first.title.trim()
        : 'proposed initiative';
    final combinedContext =
        '$contextNotes ${solutions.map((s) => '${s.title} ${s.description}').join(' ')}';
    final type = _detectProjectType(combinedContext);
    final projectScale = _detectProjectScale(combinedContext);
    final seed = _stableHash(combinedContext);

    // Scale-aware baseline values: small projects ($5K–$30K), medium ($30K–$150K), large ($150K–$500K)
    final baseline = switch (projectScale) {
      _AiProjectScale.small => switch (type) {
          _AiProjectType.physical => 22000.0,
          _AiProjectType.digital => 15000.0,
          _AiProjectType.hybrid => 25000.0,
          _AiProjectType.service => 12000.0,
          _AiProjectType.unknown => 18000.0,
        },
      _AiProjectScale.medium => switch (type) {
          _AiProjectType.physical => 85000.0,
          _AiProjectType.digital => 55000.0,
          _AiProjectType.hybrid => 95000.0,
          _AiProjectType.service => 45000.0,
          _AiProjectType.unknown => 60000.0,
        },
      _AiProjectScale.large => switch (type) {
          _AiProjectType.physical => 350000.0,
          _AiProjectType.digital => 250000.0,
          _AiProjectType.hybrid => 400000.0,
          _AiProjectType.service => 200000.0,
          _AiProjectType.unknown => 300000.0,
        },
    };
    final variation = 0.9 + ((seed % 26) / 100);
    final scaleMultiplier =
        1 + ((solutions.length > 1 ? solutions.length - 1 : 0) * 0.07);
    final estimated = _normalizeEstimatedCost(baseline * variation * scaleMultiplier);

    // Scale-aware floor: prevent small projects from getting inflated fallbacks
    final floor = switch (projectScale) {
      _AiProjectScale.small => 5000.0,
      _AiProjectScale.medium => 30000.0,
      _AiProjectScale.large => 150000.0,
    };

    Map<String, String> benefitNarrativesForType() {
      switch (type) {
        case _AiProjectType.physical:
          return {
            'revenue':
                'Revenue uplift tied to improved customer throughput and capacity utilisation from $firstSolution.',
            'cost_saving':
                'Reduced material wastage, rework, and procurement leakage through tighter execution controls.',
            'ops_efficiency':
                'Faster operating cycles by improving handoffs between site, procurement, and operations teams.',
            'productivity':
                'Higher output per shift through clearer role planning, scheduling, and on-site coordination.',
            'regulatory_compliance':
                'Lower probability of permit, health, or safety penalties through proactive compliance planning.',
            'process_improvement':
                'Standardised SOPs and checklists reduce variation and improve repeatability across teams.',
            'brand_image':
                'Improved market trust from reliable delivery and visible quality standards.',
            'stakeholder_commitment':
                'Stronger sponsor confidence due to clearer milestones and measurable value capture.',
            'other':
                'Additional upside from local demand alignment and improved supplier performance.',
          };
        case _AiProjectType.digital:
          return {
            'revenue':
                'Revenue upside from improved conversion, retention, and monetisation of digital channels.',
            'cost_saving':
                'Cost avoidance from automation of manual tasks and lower defect remediation overhead.',
            'ops_efficiency':
                'Shorter cycle times through streamlined workflows, integrations, and release execution.',
            'productivity':
                'Higher team throughput through reusable components and reduced context-switching.',
            'regulatory_compliance':
                'Lower security and compliance risk-cost exposure through built-in controls and auditability.',
            'process_improvement':
                'More predictable delivery through standardised engineering and change-management practices.',
            'brand_image':
                'Improved customer confidence through stable digital experiences and faster issue resolution.',
            'stakeholder_commitment':
                'Better executive confidence from traceable KPIs and transparent value realisation.',
            'other':
                'Additional value from data-driven decision support and operational visibility.',
          };
        case _AiProjectType.hybrid:
          return {
            'revenue':
                'Revenue growth from combining improved physical capacity with digitally enabled service reach.',
            'cost_saving':
                'Savings from coordinated procurement, reduced rework, and integrated planning across streams.',
            'ops_efficiency':
                'Improved end-to-end flow by synchronising site readiness with system enablement milestones.',
            'productivity':
                'Higher productivity through aligned teams, tools, and operational handoff routines.',
            'regulatory_compliance':
                'Reduced compliance delays across both physical operations and digital controls.',
            'process_improvement':
                'Cross-functional SOP alignment reduces bottlenecks and improves delivery predictability.',
            'brand_image':
                'Stronger market positioning through reliable omni-channel execution quality.',
            'stakeholder_commitment':
                'Greater stakeholder alignment driven by clear, balanced physical and digital milestones.',
            'other':
                'Additional value from integrated data and operational insights across the full ecosystem.',
          };
        case _AiProjectType.service:
          return {
            'revenue':
                'Revenue growth from increased service utilisation and improved repeat engagement.',
            'cost_saving':
                'Lower operating cost per service unit through standardised workflows and reduced rework.',
            'ops_efficiency':
                'Faster service delivery cycles through clearer intake, routing, and execution controls.',
            'productivity':
                'Higher staff productivity from better role clarity, training, and queue management.',
            'regulatory_compliance':
                'Reduced risk-cost through stronger policy adherence and auditable service records.',
            'process_improvement':
                'Consistent operating playbooks improve quality and reduce variation in outcomes.',
            'brand_image':
                'Improved client trust through dependable response times and service quality.',
            'stakeholder_commitment':
                'Higher stakeholder confidence supported by measurable service performance indicators.',
            'other':
                'Additional value from better partner coordination and continuous service optimization.',
          };
        case _AiProjectType.unknown:
          return {
            'revenue':
                'Revenue uplift expected from stronger delivery quality and better market responsiveness.',
            'cost_saving':
                'Cost reduction through improved planning discipline and reduced avoidable rework.',
            'ops_efficiency':
                'Operational improvement from streamlined execution and clearer accountability.',
            'productivity':
                'Productivity gains from better workload planning and fewer blocked tasks.',
            'regulatory_compliance':
                'Lower compliance risk-cost through more structured controls and documentation.',
            'process_improvement':
                'Process stability gains through standardised workflows and quality checks.',
            'brand_image':
                'Improved stakeholder perception through consistent delivery outcomes.',
            'stakeholder_commitment':
                'Stronger support from decision-makers due to improved transparency and tracking.',
            'other':
                'Additional value opportunities can be captured as scope assumptions are refined.',
          };
      }
    }

    return AiProjectValueInsights(
      estimatedProjectValue: estimated > 0 ? estimated : floor,
      benefits: benefitNarrativesForType(),
    );
  }

  String _projectValuePrompt(
    List<AiSolutionItem> solutions,
    String notes, {
    required String domainHints,
    _AiProjectScale projectScale = _AiProjectScale.medium,
  }) {
    final list = solutions
        .map((s) =>
            '{"title": "${_escape(s.title)}", "description": "${_escape(s.description)}"}')
        .join(',');
    final scaleLabel = _projectScaleLabel(projectScale);
    final scaleGuidance = switch (projectScale) {
      _AiProjectScale.small =>
        'This is a SMALL-SCALE project (e.g., barbershop, salon, local shop, small business tool). '
        'Estimated annual benefit should be \$5,000–\$30,000. '
        'A single-location small business cannot generate \$100K+ in annual benefit from one app or tool. '
        'Be realistic: a barbershop making \$150K/year in revenue cannot realize \$283K in project benefit.',
      _AiProjectScale.medium =>
        'This is a MEDIUM-SCALE project (department-level, mid-size business). '
        'Estimated annual benefit should be \$30,000–\$150,000. '
        'Scale proportionally to the organisation size and budget.',
      _AiProjectScale.large =>
        'This is a LARGE-SCALE project (enterprise, infrastructure, multi-site). '
        'Estimated annual benefit should be \$150,000–\$500,000. '
        'Scale proportionally to the organisation size and budget.',
    };
    return '''
Based on the following project cost-benefit analysis data, estimate direct financial value and provide category-specific benefit narratives.

Detected project scale: $scaleLabel

Primary focus:
1. Direct revenue impact
2. Cost reduction/avoidance
3. Operational efficiency and productivity effects
4. Compliance/risk-cost implications
5. Stakeholder/business reputation impact where financially relevant

Rules:
- Ground outputs in provided context and scope. Avoid generic statements.
- Keep each benefit text concise (1-2 sentences) but specific.
- Include quantifiable language when possible.
- Do NOT use SaaS-only language (CAC/LTV/churn/MRR) unless context explicitly indicates a digital subscription model.
- For physical projects, prefer metrics like customer traffic, throughput, utilisation, permits/compliance, material waste, and staffing productivity.
- For service projects, prefer service capacity, response time, quality consistency, utilisation, and staffing efficiency metrics.
- Return ONLY valid JSON with the exact key schema below.

CRITICAL REALISM RULES FOR estimated_value:
- The estimated_value represents the ANNUAL projected benefit in the given currency.
- $scaleGuidance
- For a small/local business project (e.g., barbershop, salon, small retail): estimated_value should be \$5,000-\$30,000.
- For a mid-size enterprise project: estimated_value should be \$30,000-\$150,000.
- For a large infrastructure project: estimated_value should be \$150,000-\$500,000.
- For a small digital/app project for a local business: estimated_value should be \$5,000-\$25,000.
- Do NOT suggest \$50,000+ for a small business app — that is unrealistic and unhelpful.
- Consider the actual revenue potential of the business type when estimating.
- A project's benefit should NEVER exceed 2-3x the business's annual revenue.
- Scale benefit values proportionally to the project's budget and scope.

Return ONLY valid JSON with this exact structure:
{
  "project_value": {
    "estimated_value": 45000,
    "benefits": {
      "revenue": "...",
      "cost_saving": "...",
      "ops_efficiency": "...",
      "productivity": "...",
      "regulatory_compliance": "...",
      "process_improvement": "...",
      "brand_image": "...",
      "stakeholder_commitment": "...",
      "other": "..."
    }
  }
}

Solutions: [$list]

Context notes (optional): $notes

Domain guardrails:
$domainHints
''';
  }

  Future<String> generateBusinessCase({
    required String projectName,
    required String solutionTitle,
    required String solutionDescription,
    String notes = '',
  }) async {
    if (!OpenAiConfig.isConfigured) throw const OpenAiNotConfiguredException();
    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();
    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': 0.6,
      'max_completion_tokens': 1200,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a project strategist. Write a concise, executive-ready business case. Use short paragraphs or bullets. No markdown headings.'
        },
        {
          'role': 'user',
          'content': '''
Project: ${_escape(projectName)}
Solution title: ${_escape(solutionTitle)}
Solution description: ${_escape(solutionDescription)}
Notes: ${notes.trim().isEmpty ? 'None' : _escape(notes)}

Include: problem statement, proposed solution, benefits, risks, success metrics, and a brief recommendation.
Return plain text only.'''
        }
      ],
    }));

    final response = await _client
        .post(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 18));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('OpenAI error ${response.statusCode}: ${response.body}');
    }
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final content =
        OpenAiConfig.extractContent(data);
    return _stripAsterisks(content).trim();
  }

  Future<List<BenefitLineItemInput>> generateBenefitLineItems({
    required List<AiSolutionItem> solutions,
    required double estimatedProjectValue,
    String contextNotes = '',
    String currency = 'USD',
    int count = 6,
  }) async {
    final combinedText =
        '$contextNotes ${solutions.map((s) => '${s.title} ${s.description}').join(' ')}';
    final detectedType = _detectProjectType(combinedText);
    final detectedScale = _detectProjectScale(combinedText);
    final domainHints =
        _financialDomainHints(context: contextNotes, solutions: solutions);
    if (solutions.isEmpty || estimatedProjectValue <= 0) return [];
    if (!OpenAiConfig.isConfigured) {
      return _fallbackBenefitLineItems(
        estimatedProjectValue,
        currency,
        solutions: solutions,
        contextNotes: contextNotes,
        count: count,
      );
    }

    final scaleHint = _projectScaleLabel(detectedScale);
    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();
    final list = solutions
        .map((s) =>
            '{"title":"${_escape(s.title)}","description":"${_escape(s.description)}"}')
        .join(',');
    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': 0.5,
      'max_completion_tokens': 1200,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'financial analyst generating monetised benefit line items for project value modelling',
            strictJson: true,
            extraRules:
                'Return strict JSON for benefit line items. Use only these category keys: revenue, cost_saving, ops_efficiency, productivity, regulatory_compliance, process_improvement, brand_image, stakeholder_commitment, other. Do not use SaaS-only terms for non-digital projects. Do not use construction-only assumptions for purely digital projects. The detected project scale is $scaleHint — you MUST scale all financial values to match this scale. Small projects get small numbers. Follow these domain guardrails:\n$domainHints',
          )
        },
        {
          'role': 'user',
          'content': _benefitLineItemsPrompt(
            list,
            estimatedProjectValue,
            currency,
            contextNotes,
            count,
            domainHints: domainHints,
            projectScale: detectedScale,
          ),
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _fallbackBenefitLineItems(
          estimatedProjectValue,
          currency,
          solutions: solutions,
          contextNotes: contextNotes,
          count: count,
        );
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;
      final seen = <String>{};
      final items = (parsed['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map((item) {
            final rawCategory =
                (item['category_key'] ?? item['category'] ?? '').toString();
            final category = _normalizeBenefitCategoryKey(rawCategory);
            var title = (item['title'] ?? '').toString().trim();
            if (title.isEmpty ||
                _looksTooGenericFinancialText(title) ||
                _isDomainMismatchForProjectType(title, detectedType)) {
              title = _fallbackBenefitTitleForCategory(
                category,
                detectedType,
                solutions,
              );
            }
            var notes = (item['notes'] ?? '').toString().trim();
            if (_isDomainMismatchForProjectType(notes, detectedType) ||
                _looksTooGenericFinancialText(notes)) {
              notes = _fallbackBenefitNotesForCategory(category, detectedType);
            }
            final unitValueRaw =
                _toDouble(item['unit_value'] ?? item['unitValue']);
            // Post-processing: clamp unit value to scale-appropriate maximum
            final unitValue = _clampBenefitValue(unitValueRaw, detectedScale);
            final unitsRaw = _toDouble(item['units'] ?? 1);
            final units = unitsRaw > 0 ? unitsRaw : 1.0;
            final key =
                '${category.toLowerCase()}|${title.toLowerCase()}|${unitValue.toStringAsFixed(2)}';
            if (seen.contains(key) || unitValue <= 0 || title.isEmpty) {
              return null;
            }
            seen.add(key);
            return BenefitLineItemInput(
              category: category,
              title: title,
              unitValue: unitValue,
              units: units,
              notes: notes,
            );
          })
          .whereType<BenefitLineItemInput>()
          .toList();
      return items.isEmpty
          ? _fallbackBenefitLineItems(
              estimatedProjectValue,
              currency,
              solutions: solutions,
              contextNotes: contextNotes,
              count: count,
            )
          : items;
    } catch (e) {
      debugPrint('generateBenefitLineItems failed: $e');
      return _fallbackBenefitLineItems(
        estimatedProjectValue,
        currency,
        solutions: solutions,
        contextNotes: contextNotes,
        count: count,
      );
    }
  }

  String _benefitLineItemsPrompt(
      String solutionsJson,
      double estimatedProjectValue,
      String currency,
      String contextNotes,
      int count,
      {required String domainHints,
      _AiProjectScale projectScale = _AiProjectScale.medium}) {
    final notes = contextNotes.trim().isEmpty
        ? 'No additional context supplied.'
        : contextNotes.trim();
    final scaleLabel = _projectScaleLabel(projectScale);
    final scaleUnitRange = switch (projectScale) {
      _AiProjectScale.small =>
        '\$100-\$1,500/mo for small local businesses (e.g., barbershop, salon). '
        'A barbershop generating \$10K/mo in revenue cannot realize \$5K/mo in benefit from a single app.',
      _AiProjectScale.medium =>
        '\$1,000-\$8,000/mo for mid-size enterprises or department-level projects.',
      _AiProjectScale.large =>
        '\$5,000-\$40,000/mo for large enterprises, infrastructure, or multi-site deployments.',
    };
    final currencyInstruction = _currencyConversionInstruction(currency);
    return '''
We are preparing benefit line items for a project portfolio.
Detected project scale: $scaleLabel
Target total value: $currency ${estimatedProjectValue.toStringAsFixed(0)}.
Provide $count items across these exact category keys:
["revenue","cost_saving","ops_efficiency","productivity","regulatory_compliance","process_improvement","brand_image","stakeholder_commitment","other"].
Each line item must be domain-specific to the project context and must include a practical, non-generic title.

IMPORTANT REALISM RULES:
- Unit values must be realistic per-month amounts, NOT lump-sum annual totals.
- For this $scaleLabel-scale project, monthly unit values should typically range: $scaleUnitRange
- Units should typically be 12 (months) for recurring benefits, or 1 for one-time benefits.
- Total value per item (unit_value * units) should sum to approximately the target total value.
- For a small/local business project (barbershop, salon, etc.): monthly unit values typically range \$100-\$1,500.
- For a mid-size enterprise project: monthly unit values typically range \$1,000-\$8,000.
- For a large infrastructure project: monthly unit values typically range \$5,000-\$40,000.
- Do NOT suggest \$3,000+ per month for a small business app like a barbershop; that is unrealistic.
- Revenue benefits should be the largest; stakeholder_commitment and other should be smallest.
- Scale ALL values proportionally to the project's budget and business size.
- All monetary values (unit_value, target total) must be in $currency.$currencyInstruction

Return strict JSON:
{
  "items": [
    {
      "category_key": "revenue",
      "title": "Domain-specific monetised benefit title",
      "unit_value": 1500,
      "units": 12,
      "notes": "Monthly impact"
    }
  ]
}

Solutions: [$solutionsJson]
Context notes: $notes
${_scaleFinancialConstraints(projectScale)}
Domain guardrails:
$domainHints
Return ONLY JSON.
''';
  }

  List<BenefitLineItemInput> _fallbackBenefitLineItems(
    double estimatedProjectValue,
    String currency, {
    required List<AiSolutionItem> solutions,
    String contextNotes = '',
    int count = 6,
  }) {
    final combinedContext =
        '$contextNotes ${solutions.map((s) => '${s.title} ${s.description}').join(' ')}';
    final scale = _detectProjectScale(combinedContext);
    // Use a realistic annual total scaled to project size; avoid inflated defaults
    final scaleDefault = switch (scale) {
      _AiProjectScale.small => 15000.0,
      _AiProjectScale.medium => 45000.0,
      _AiProjectScale.large => 250000.0,
    };
    final total = estimatedProjectValue > 0 ? estimatedProjectValue : scaleDefault;
    final type = _detectProjectType(combinedContext);
    final allocations = <MapEntry<String, double>>[
      const MapEntry('revenue', 0.24),
      const MapEntry('cost_saving', 0.20),
      const MapEntry('ops_efficiency', 0.14),
      const MapEntry('productivity', 0.12),
      const MapEntry('regulatory_compliance', 0.10),
      const MapEntry('process_improvement', 0.08),
      const MapEntry('brand_image', 0.06),
      const MapEntry('stakeholder_commitment', 0.04),
      const MapEntry('other', 0.02),
    ];
    final cappedCount = count < 1
        ? 1
        : (count > allocations.length ? allocations.length : count);
    return allocations.take(cappedCount).map((entry) {
      // Distribute annual total across 12 months for realistic per-month unit values
      final annualValue = total * entry.value;
      final monthlyUnitValue = annualValue / 12;
      final title =
          _fallbackBenefitTitleForCategory(entry.key, type, solutions);
      return BenefitLineItemInput(
        category: entry.key,
        title: title,
        unitValue: monthlyUnitValue,
        units: 12,
        notes: _fallbackBenefitNotesForCategory(entry.key, type),
      );
    }).toList();
  }

  String _fallbackBenefitTitleForCategory(
    String category,
    _AiProjectType type,
    List<AiSolutionItem> solutions,
  ) {
    final solutionRef = solutions.isNotEmpty
        ? solutions.first.title.trim()
        : 'the selected solution';
    switch (type) {
      case _AiProjectType.physical:
        switch (category) {
          case 'revenue':
            return 'Increase customer traffic and average ticket for $solutionRef';
          case 'cost_saving':
            return 'Reduce material waste and procurement leakage in $solutionRef';
          case 'ops_efficiency':
            return 'Reduce service and handoff cycle time for $solutionRef';
          case 'productivity':
            return 'Improve workforce output per shift in $solutionRef';
          case 'regulatory_compliance':
            return 'Avoid permit and compliance penalty costs for $solutionRef';
          case 'process_improvement':
            return 'Standardize operating procedures for $solutionRef';
          case 'brand_image':
            return 'Improve local market confidence in $solutionRef';
          case 'stakeholder_commitment':
            return 'Increase sponsor confidence through milestone visibility';
          default:
            return 'Capture site-specific value opportunities from $solutionRef';
        }
      case _AiProjectType.digital:
        switch (category) {
          case 'revenue':
            return 'Increase conversion and monetised usage for $solutionRef';
          case 'cost_saving':
            return 'Reduce manual processing and support overhead in $solutionRef';
          case 'ops_efficiency':
            return 'Shorten release and issue-resolution cycle time';
          case 'productivity':
            return 'Increase delivery throughput via automation and reuse';
          case 'regulatory_compliance':
            return 'Reduce security and compliance risk-cost exposure';
          case 'process_improvement':
            return 'Improve workflow reliability and handoff quality';
          case 'brand_image':
            return 'Improve trust through stable digital service quality';
          case 'stakeholder_commitment':
            return 'Increase executive confidence with KPI visibility';
          default:
            return 'Unlock additional value from data-driven optimization';
        }
      case _AiProjectType.hybrid:
        switch (category) {
          case 'revenue':
            return 'Increase revenue via integrated physical and digital channels';
          case 'cost_saving':
            return 'Reduce cross-stream waste across facility and system delivery';
          case 'ops_efficiency':
            return 'Synchronize physical readiness with digital go-live';
          case 'productivity':
            return 'Improve cross-functional team output and coordination';
          case 'regulatory_compliance':
            return 'Reduce compliance delays across site and systems';
          case 'process_improvement':
            return 'Standardize integrated workflows across delivery streams';
          case 'brand_image':
            return 'Strengthen brand confidence through consistent experience';
          case 'stakeholder_commitment':
            return 'Improve stakeholder alignment on integrated milestones';
          default:
            return 'Capture blended value from physical-digital optimization';
        }
      case _AiProjectType.service:
        switch (category) {
          case 'revenue':
            return 'Increase service uptake and repeat engagement';
          case 'cost_saving':
            return 'Reduce cost per service case through workflow controls';
          case 'ops_efficiency':
            return 'Improve response times and service throughput';
          case 'productivity':
            return 'Increase staff utilization and task completion rates';
          case 'regulatory_compliance':
            return 'Reduce policy and compliance breach exposure';
          case 'process_improvement':
            return 'Standardize service SOPs for predictable delivery';
          case 'brand_image':
            return 'Improve client trust via consistent service quality';
          case 'stakeholder_commitment':
            return 'Increase sponsor confidence through service KPIs';
          default:
            return 'Capture value through continuous service optimization';
        }
      case _AiProjectType.unknown:
        final categoryLabel = _benefitCategoryDisplayLabel(category);
        return '$categoryLabel value realisation for $solutionRef';
    }
  }

  String _fallbackBenefitNotesForCategory(
    String category,
    _AiProjectType type,
  ) {
    switch (type) {
      case _AiProjectType.physical:
        return 'Annualized estimate based on operational throughput and cost controls.';
      case _AiProjectType.digital:
        return 'Annualized estimate based on usage, automation, and platform efficiency.';
      case _AiProjectType.hybrid:
        return 'Annualized estimate blending physical and digital delivery impacts.';
      case _AiProjectType.service:
        return 'Annualized estimate based on service volume, quality, and staffing efficiency.';
      case _AiProjectType.unknown:
        final categoryLabel = _benefitCategoryDisplayLabel(category);
        return '$categoryLabel estimate annualized in conservative terms.';
    }
  }

  Future<List<AiBenefitSavingsSuggestion>> generateBenefitSavingsSuggestions(
    List<BenefitLineItemInput> items, {
    String currency = 'USD',
    double? savingsTargetPercent,
    String contextNotes = '',
  }) async {
    final contextFromItems =
        items.map((e) => '${e.category} ${e.title} ${e.notes}').join(' ');
    final combinedContext = '$contextNotes $contextFromItems';
    final detectedType = _detectProjectType(combinedContext);
    final detectedScale = _detectProjectScale(combinedContext);
    final domainHints = _financialDomainHints(
      context: combinedContext,
    );
    final scaleConstraints = _scaleFinancialConstraints(detectedScale);
    final totalBenefit = items.fold<double>(0, (sum, item) => sum + item.total);
    if (items.isEmpty) return [];
    if (!OpenAiConfig.isConfigured) {
      return _fallbackSavingsSuggestions(
        items,
        currency: currency,
        contextNotes: contextNotes,
      );
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();
    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': 0.4,
      'max_completion_tokens': 1200,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'financial optimization analyst identifying savings scenarios from benefit line items',
            strictJson: true,
            extraRules:
                'Always output a JSON object with a "savings_scenarios" array. Each scenario requires: lever, recommendation, projected_savings (number), timeframe, confidence, rationale. Keep levers relevant to the detected domain and avoid generic advice. Follow these domain guardrails:\n$domainHints',
          )
        },
        {
          'role': 'user',
          'content': _benefitSavingsPrompt(
            items,
            currency,
            savingsTargetPercent,
            contextNotes,
            domainHints: domainHints,
            scaleConstraints: scaleConstraints,
          ),
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 14));
      if (response.statusCode == 401) {
        throw Exception('Invalid API key. Please check your OpenAI API key.');
      }
      if (response.statusCode == 429) {
        throw Exception(
            'API quota exceeded. Please check your OpenAI billing.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;
      final scenarios = (parsed['savings_scenarios'] as List? ?? [])
          .map((e) {
            final raw = AiBenefitSavingsSuggestion.fromMap(
                (e ?? {}) as Map<String, dynamic>);
            // Post-processing: clamp projected savings to realistic range
            final clampedSavings = _clampSavingsValue(raw.projectedSavings, totalBenefit);
            return AiBenefitSavingsSuggestion(
              lever: raw.lever,
              recommendation: raw.recommendation,
              projectedSavings: clampedSavings,
              timeframe: raw.timeframe,
              confidence: raw.confidence,
              rationale: raw.rationale,
            );
          })
          .where((e) {
        if (e.lever.isEmpty) return false;
        if (e.projectedSavings <= 0) return false;
        final mergedText = '${e.lever} ${e.recommendation} ${e.rationale}';
        if (_isDomainMismatchForProjectType(mergedText, detectedType)) {
          return false;
        }
        if (_looksTooGenericFinancialText(mergedText)) {
          return false;
        }
        return true;
      }).toList();
      if (scenarios.isEmpty) {
        return _fallbackSavingsSuggestions(
          items,
          currency: currency,
          contextNotes: contextNotes,
        );
      }
      return scenarios;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('generateBenefitSavingsSuggestions failed: $e');
      }
      return _fallbackSavingsSuggestions(
        items,
        currency: currency,
        contextNotes: contextNotes,
      );
    }
  }

  String _benefitSavingsPrompt(List<BenefitLineItemInput> items,
      String currency, double? savingsTargetPercent, String contextNotes,
      {required String domainHints, String scaleConstraints = ''}) {
    final target = savingsTargetPercent != null && savingsTargetPercent > 0
        ? 'Aim for at least ${savingsTargetPercent.toStringAsFixed(1)}% savings against total monetised benefits.'
        : 'If no explicit savings target is provided, surface high-impact opportunities.';
    final payload = jsonEncode(items.map((e) => e.toJson()).toList());
    final notes = contextNotes.trim().isEmpty
        ? 'No additional context supplied.'
        : contextNotes.trim();
    final currencyInstruction = _currencyConversionInstruction(currency);
    return '''
These are the financial benefit line items currently modelled (currency: $currency):
$payload

$target
Respond with 2-4 concise savings scenarios that resemble spreadsheet-style levers (unit cost, volume, timing). Use numeric projected_savings values in $currency.
Extra notes for context: $notes
Do not suggest SaaS-only levers (CAC/LTV/churn/MRR) unless the project context clearly indicates SaaS/digital subscription.
Do not suggest construction-only levers for purely digital projects.
Projected savings for each scenario MUST NOT exceed 30% of the total benefit value across all items.
- All monetary values (projected_savings) must be in $currency.$currencyInstruction
$scaleConstraints
Domain guardrails:
$domainHints

Remember: Return ONLY a JSON object with key "savings_scenarios".
''';
  }

  List<AiBenefitSavingsSuggestion> _fallbackSavingsSuggestions(
    List<BenefitLineItemInput> items, {
    required String currency,
    String contextNotes = '',
  }) {
    if (items.isEmpty) return [];
    final sorted = List<BenefitLineItemInput>.from(items)
      ..sort((a, b) => b.total.compareTo(a.total));
    final total = sorted.fold<double>(0, (sum, item) => sum + item.total);
    final type = _detectProjectType(
      '$contextNotes ${items.map((e) => '${e.category} ${e.title} ${e.notes}').join(' ')}',
    );

    double cappedSavings(double value) => value.isFinite ? value : 0;

    final suggestions = <AiBenefitSavingsSuggestion>[];
    final top = sorted.first;
    final topCategoryLabel = _benefitCategoryDisplayLabel(top.category);

    String topRecommendation() {
      switch (type) {
        case _AiProjectType.physical:
          return 'Target a 6-10% savings through supplier renegotiation, batch purchasing, and waste controls for this benefit driver.';
        case _AiProjectType.digital:
          return 'Target a 6-10% savings through licensing optimization, workload right-sizing, and automation of repeat tasks.';
        case _AiProjectType.hybrid:
          return 'Target a 6-10% savings through coordinated supplier, operations, and platform optimization across both physical and digital workstreams.';
        case _AiProjectType.service:
          return 'Target a 5-9% savings through service process standardization, scheduling discipline, and role optimization.';
        case _AiProjectType.unknown:
          return 'Target a conservative 5-8% savings by tightening assumptions, supplier rates, and execution controls.';
      }
    }

    suggestions.add(AiBenefitSavingsSuggestion(
      lever: 'Optimize $topCategoryLabel driver: ${top.title}',
      recommendation: topRecommendation(),
      projectedSavings: cappedSavings(top.total * 0.08),
      timeframe: 'Next quarter',
      confidence: 'Medium',
      rationale:
          'Largest monetised benefit category is $topCategoryLabel; a focused improvement here can protect value quickly.',
    ));

    if (sorted.length > 1) {
      final runnerUp = sorted[1];
      final runnerUpLabel = _benefitCategoryDisplayLabel(runnerUp.category);
      suggestions.add(AiBenefitSavingsSuggestion(
        lever: 'Volume and utilisation discipline for ${runnerUp.title}',
        recommendation:
            'Reduce avoidable volume by ~5% through tighter controls, scheduling, and performance tracking.',
        projectedSavings: cappedSavings(runnerUp.total * 0.05),
        timeframe: '6 months',
        confidence: 'Medium',
        rationale:
            'Second-largest monetised benefit ($runnerUpLabel) where volume adjustments improve realised savings.',
      ));
    }

    suggestions.add(AiBenefitSavingsSuggestion(
      lever: 'Benefit realisation governance',
      recommendation:
          'Embed monthly finance checkpoints and owner-level review to prevent benefit leakage across categories.',
      projectedSavings: cappedSavings(total * 0.05),
      timeframe: '12 months',
      confidence: 'Medium',
      rationale:
          'Routine oversight across the full benefit base (~$currency ${total.toStringAsFixed(0)}) typically safeguards at least 5% of value.',
    ));

    return suggestions;
  }

  // Removed fallback technology suggestions; API must provide technologies or return an error.

  // INFRASTRUCTURE
  Future<Map<String, List<String>>> generateInfrastructureForSolutions(
      List<AiSolutionItem> solutions,
      {String contextNotes = ''}) async {
    if (solutions.isEmpty) return {};
    if (!OpenAiConfig.isConfigured) return _fallbackInfrastructure(solutions);

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();
    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': 0.5,
      'max_completion_tokens': 1200,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'cloud and infrastructure architect identifying the infrastructure considerations each solution genuinely needs',
            strictJson: true,
            extraRules:
                'For each solution, list the environments, facilities, utilities, networking, hosting, resiliency, observability, security, or operational infrastructure that solution specifically requires. If a solution has little or no infrastructure footprint in one dimension, do not fill it with generic placeholders.',
          )
        },
        {
          'role': 'user',
          'content': _infrastructurePrompt(solutions, contextNotes)
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;

      final List list = (parsed['infrastructure'] as List? ?? []);
      final Map<String, List<String>> result = {};
      for (var idx = 0; idx < list.length; idx++) {
        final item = list[idx];
        final map = item as Map<String, dynamic>;
        final title = (map['solution'] ?? '').toString();
        final items = (map['items'] as List? ?? [])
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .take(8)
            .toList();
        if (title.isNotEmpty && items.isNotEmpty) result[title] = items;
      }
      return _mergeWithFallbackInfra(solutions, result);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('generateInfrastructureForSolutions failed: $e');
      }
      return _fallbackInfrastructure(solutions);
    }
  }

  Map<String, List<String>> _mergeWithFallbackInfra(
      List<AiSolutionItem> solutions, Map<String, List<String>> generated) {
    final fallback = _fallbackInfrastructure(solutions);
    final merged = <String, List<String>>{};
    for (final s in solutions) {
      final g = generated[s.title];
      merged[s.title] = (g != null && g.isNotEmpty)
          ? g.take(8).toList()
          : (fallback[s.title] ?? []);
    }
    return merged;
  }

  Map<String, List<String>> _fallbackInfrastructure(
      List<AiSolutionItem> solutions) {
    final map = <String, List<String>>{};
    // Provide distinct-but-reasonable infrastructure lists per solution (avoid identical outputs).
    const pools = <List<String>>[
      [
        'Production environments (dev/test/stage/prod) with CI/CD promotion',
        'Networking: segmented subnets, ingress/egress controls, load balancing',
        'Identity & access: SSO + RBAC with least privilege reviews',
        'Secrets management with rotation and audit trails',
        'Encrypted data storage with backup policy (RPO/RTO defined)',
        'Observability: logs, metrics, traces, alerting and dashboards',
        'Scalability: autoscaling rules and capacity planning baselines',
        'Resilience: multi-zone deployment and documented failover runbooks',
      ],
      [
        'Dedicated environments with automated deployments and rollback strategy',
        'API gateway / reverse proxy with WAF and rate limiting',
        'Private networking with secure connectivity to on-prem / partners',
        'Centralized identity provider and privileged access workflows',
        'Data integration layer with secure queues/topics and retry policies',
        'Monitoring for SLOs: uptime, latency, error budgets, alert routing',
        'Performance testing infrastructure and caching strategy',
        'Disaster recovery plan with periodic restore testing',
      ],
      [
        'Hardened baseline images and configuration management standards',
        'Network segmentation for sensitive components and data flows',
        'Endpoint and service-to-service encryption (mTLS where needed)',
        'Key management (KMS/KeyVault) and certificate lifecycle process',
        'Audit logging and retention aligned to compliance requirements',
        'Data lifecycle controls: retention, archival, deletion workflows',
        'High availability with redundancy for critical services',
        'Operational runbooks and incident response escalation paths',
      ],
      [
        'Compute sizing for expected throughput and peak load scenarios',
        'Storage performance tiering (IOPS/latency) for core datasets',
        'Batch/ETL scheduling infrastructure (jobs, orchestration, retries)',
        'Role-based access boundaries and admin separation of duties',
        'Secure remote access for operations with session recording',
        'Cost governance: tagging, budgets, alerts, and usage reporting',
        'Service health dashboards and automated anomaly detection',
        'Resilience testing cadence (chaos / failover exercises)',
      ],
      [
        'Edge delivery where needed (CDN) and static asset optimization',
        'DNS strategy and TLS termination with certificate automation',
        'Load testing harness and production-like staging environment',
        'Data replication strategy for geo / multi-site requirements',
        'Backup encryption, immutable backups, and restore SLAs',
        'Centralized logging with searchable retention policies',
        'Security scanning pipeline (SAST/DAST/dependency) integrated into CI',
        'Governance: change control approvals and deployment audit trail',
      ],
    ];

    for (int i = 0; i < solutions.length; i++) {
      final s = solutions[i];
      map[s.title] = pools[i % pools.length];
    }
    return map;
  }

  String _infrastructurePrompt(List<AiSolutionItem> solutions, String notes) {
    // Handle empty solutions by using project context from notes
    String list = '';
    if (solutions.isNotEmpty) {
      list = solutions
          .map((s) =>
              '{"title": "${_escape(s.title)}", "description": "${_escape(s.description)}"}')
          .join(',');
    } else if (notes.isNotEmpty) {
      // If no solutions but we have project context, create a placeholder
      list = '{"title": "Project", "description": "${_escape(notes)}"}';
    }

    return '''
For each solution below, list ONLY physical infrastructure considerations required to support it - things that can be physically touched or installed.

CRITICAL REQUIREMENTS:
- ONLY include physical infrastructure: servers, cabling, hardware, routers, switches, physical storage devices, network equipment, data center components, cooling systems, power units, UPS systems, physical racks
- EXCLUDE: cloud services (AWS, Azure, GCP), software frameworks, virtual-only solutions, SaaS platforms, APIs, databases (unless referring to physical database servers), containers, or any intangible components
- Focus exclusively on tangible hardware and physical infrastructure components that can be physically installed
- Each solution must have DIFFERENT and UNIQUE physical infrastructure recommendations tailored to its specific requirements

IMPORTANT: Write clear, complete sentences. Each item should be a full, understandable statement (e.g., "Physical rack-mounted servers with redundant power supplies" not just "Servers"). Keep each item between 8-20 words and make it actionable and specific.
IMPORTANT: Tailor items to EACH solution's title/description. Do NOT reuse the exact same list across different solutions.
IMPORTANT: Be detailed and specific. Do not use "etc.", "and similar", or vague groupings. State each item explicitly.

Return ONLY valid JSON with this exact structure:
{
  "infrastructure": [
    {"solution": "Solution Name", "items": ["Complete infrastructure consideration 1", "Complete infrastructure consideration 2", "Complete infrastructure consideration 3"]}
  ]
}

${list.isNotEmpty ? 'Solutions: [$list]' : 'Project Context: $notes'}

Context notes (optional): $notes
''';
  }

  // STAKEHOLDERS
  // Returns a map with 'internal' and 'external' keys, each containing Map<String, List<String>>
  Future<Map<String, Map<String, List<String>>>>
      generateStakeholdersForSolutions(List<AiSolutionItem> solutions,
          {String contextNotes = ''}) async {
    if (solutions.isEmpty) return {'internal': {}, 'external': {}};
    if (!OpenAiConfig.isConfigured) return _fallbackStakeholders(solutions);

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();
    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': 0.5,
      'max_completion_tokens': 2000,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a stakeholder analyst. For each solution, separately list INTERNAL stakeholders (employees, departments, teams within the organization) and EXTERNAL stakeholders (regulatory bodies, vendors, government agencies, external partners). Be detailed and specific: do not use "etc.", "and similar", or vague groupings. State each stakeholder explicitly. Return strict JSON only.'
        },
        {
          'role': 'user',
          'content': _stakeholdersPrompt(solutions, contextNotes)
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;

      final Map<String, List<String>> internalResult = {};
      final Map<String, List<String>> externalResult = {};

      final List stakeholderList = (parsed['stakeholders'] as List? ?? []);
      for (final item in stakeholderList) {
        final map = item as Map<String, dynamic>;
        final title = (map['solution'] ?? '').toString();
        final internalItems = (map['internal'] as List? ?? [])
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .take(6)
            .toList();
        final externalItems = (map['external'] as List? ?? [])
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .take(6)
            .toList();
        if (title.isNotEmpty) {
          if (internalItems.isNotEmpty) internalResult[title] = internalItems;
          if (externalItems.isNotEmpty) externalResult[title] = externalItems;
        }
      }
      return _mergeWithFallbackStakeholders(
          solutions, internalResult, externalResult);
    } catch (e) {
      if (kDebugMode) debugPrint('generateStakeholdersForSolutions failed: $e');
      return _fallbackStakeholders(solutions);
    }
  }

  Map<String, Map<String, List<String>>> _mergeWithFallbackStakeholders(
      List<AiSolutionItem> solutions,
      Map<String, List<String>> generatedInternal,
      Map<String, List<String>> generatedExternal) {
    final fallback = _fallbackStakeholders(solutions);
    final mergedInternal = <String, List<String>>{};
    final mergedExternal = <String, List<String>>{};

    for (final s in solutions) {
      final gInternal = generatedInternal[s.title];
      final gExternal = generatedExternal[s.title];
      mergedInternal[s.title] = (gInternal != null && gInternal.isNotEmpty)
          ? gInternal.take(6).toList()
          : (fallback['internal']![s.title] ?? []);
      mergedExternal[s.title] = (gExternal != null && gExternal.isNotEmpty)
          ? gExternal.take(6).toList()
          : (fallback['external']![s.title] ?? []);
    }
    return {'internal': mergedInternal, 'external': mergedExternal};
  }

  Map<String, Map<String, List<String>>> _fallbackStakeholders(
      List<AiSolutionItem> solutions) {
    // Create distinct pools of stakeholders for variety
    const internalPools = <List<String>>[
      [
        'Project Manager / Program Director',
        'IT Operations Team',
        'Finance & Budget Office',
        'Legal & Compliance Department',
        'Internal Audit',
        'Business Unit Leads',
      ],
      [
        'Executive Sponsor',
        'Operations Manager',
        'Procurement Team',
        'Security & Risk Management',
        'Quality Assurance',
        'Change Management Office',
      ],
      [
        'Technology Lead',
        'Product Owner',
        'Vendor Management',
        'Data Governance Team',
        'Training & Development',
        'Stakeholder Relations',
      ],
      [
        'Chief Technology Officer',
        'Business Analysts',
        'Contract Management',
        'Information Security',
        'Testing & Validation',
        'Communications Team',
      ],
      [
        'Program Office',
        'Technical Architects',
        'Budget & Finance',
        'Legal Counsel',
        'Internal Controls',
        'User Experience Team',
      ],
    ];

    const externalPools = <List<String>>[
      [
        'Regulatory authority (industry-specific)',
        'Data protection authority / privacy office',
        'Government procurement or finance oversight',
        'External vendors / systems integrators',
        'End-user representatives / advocacy groups',
        'Industry standards organizations',
      ],
      [
        'Compliance & regulatory bodies',
        'Third-party auditors',
        'External consultants',
        'Vendor partners',
        'Community stakeholders',
        'Trade associations',
      ],
      [
        'Government agencies',
        'Regulatory compliance officers',
        'External service providers',
        'Customer advisory boards',
        'Public interest groups',
        'Industry watchdogs',
      ],
      [
        'Oversight committees',
        'External legal advisors',
        'Managed service providers',
        'User groups',
        'Environmental regulators',
        'Consumer protection agencies',
      ],
      [
        'International regulatory bodies',
        'Certification organizations',
        'Outsourced IT services',
        'Public stakeholders',
        'Media & communications',
        'Independent evaluators',
      ],
    ];

    final internalMap = <String, List<String>>{};
    final externalMap = <String, List<String>>{};

    for (int i = 0; i < solutions.length; i++) {
      final s = solutions[i];
      internalMap[s.title] = internalPools[i % internalPools.length];
      externalMap[s.title] = externalPools[i % externalPools.length];
    }

    return {'internal': internalMap, 'external': externalMap};
  }

  String _stakeholdersPrompt(List<AiSolutionItem> solutions, String notes) {
    // Handle empty solutions by using project context from notes
    String list = '';
    if (solutions.isNotEmpty) {
      list = solutions
          .map((s) =>
              '{"title": "${_escape(s.title)}", "description": "${_escape(s.description)}"}')
          .join(',');
    } else if (notes.isNotEmpty) {
      // If no solutions but we have project context, create a placeholder
      list = '{"title": "Project", "description": "${_escape(notes)}"}';
    }

    return '''
For each solution below, separately identify INTERNAL stakeholders (employees, departments, teams within your organization) and EXTERNAL stakeholders (regulatory bodies, vendors, government agencies, external partners, community groups).

IMPORTANT: Tailor stakeholders to EACH solution's specific title and description. Do NOT reuse the exact same list across different solutions. Keep each item under 12 words.
IMPORTANT: Be detailed and specific. Do not use "etc.", "and similar", or vague groupings. State each stakeholder explicitly.

Return ONLY valid JSON with this exact structure:
{
  "stakeholders": [
    {
      "solution": "Solution Name",
      "internal": ["Internal Stakeholder 1", "Internal Stakeholder 2"],
      "external": ["External Stakeholder 1", "External Stakeholder 2"]
    }
  ]
}

${list.isNotEmpty ? 'Solutions: [$list]' : 'Project Context: $notes'}

Context notes (optional): $notes
''';
  }

  // Helpers
  List<AiSolutionItem> _normalizeSolutions(List<AiSolutionItem> items) {
    final List<AiSolutionItem> normalized = [];
    // Take up to 5 items from API response
    for (var i = 0; i < items.length && normalized.length < 5; i++) {
      normalized.add(items[i]);
    }
    // Keep strong AI outputs intact; only fall back when none are usable.
    if (normalized.isNotEmpty) {
      return normalized;
    }
    while (normalized.length < 3) {
      normalized.add(AiSolutionItem(
        title: 'Solution Option ${normalized.length + 1}',
        description:
            'A comprehensive approach to address the project requirements, considering feasibility, resources, and expected outcomes.',
      ));
    }
    return normalized;
  }

  String _solutionsPrompt(
    String businessCase, {
    String contextNotes = '',
  }) =>
      '''
Generate 2-3 concrete, genuinely distinct solution options for this business case. Each solution should be practical, achievable, and directly address the project needs without being a minor variation of another option.

Return ONLY valid JSON in this exact structure:
{
  "solutions": [
    {"title": "Solution Name", "description": "Brief description of approach, benefits, and key considerations"}
  ]
}

Decision rules you MUST follow:
- Determine project type and starting point from the context.
- If context is ambiguous, assume a from-scratch (greenfield) starting point.
- If context clearly states existing operations/infrastructure and asks mainly for digital enablement, focus on digital enhancement rather than full physical setup.
- For physical or hybrid projects that are from-scratch, include foundational real-world setup logic in descriptions (site/readiness, permits/compliance, procurement/equipment, staffing/operations).
- For digital-focused enhancements on existing operations, emphasize integration, data migration, cybersecurity, rollout, and change management.
- Do not include outdated, deprecated, or irrelevant practices.
- Each option must be genuinely different in delivery strategy (not wording variants).
- In each description, explicitly indicate the assumed starting point (from-scratch vs existing operation enhancement) and first key workstreams.

Project Context:
$businessCase

Additional Cross-Page Context:
${contextNotes.trim().isEmpty ? 'None provided.' : contextNotes}
''';

  String _normalizeRequirementPhase(dynamic rawValue) {
    final raw = _stripAsterisks((rawValue ?? '').toString().trim());
    if (raw.isEmpty) return 'Planning';

    final value = raw.toLowerCase();
    if (value == 'all' || value == 'all phases' || value == 'all phase') {
      return 'ALL';
    }
    if (value.startsWith('init')) return 'Initiation';
    if (value.startsWith('plan')) return 'Planning';
    if (value.startsWith('des')) return 'Design';
    if (value.startsWith('exec') || value.contains('implement')) {
      return 'Execution';
    }
    if (value.startsWith('launch') ||
        value.contains('go live') ||
        value.contains('golive')) {
      return 'Launch';
    }
    return 'Planning';
  }

  String _requirementsPrompt(String businessCase) => '''
Based on this project context, generate 7-20 specific project requirements that must be met for the project to be considered successful.

Each requirement should be:
- Clear and specific
- Measurable or verifiable
- Properly categorized by type
- Assigned to a relevant discipline, role, and/or person
- Tagged to one implementation phase (Initiation, Planning, Design, Execution, Launch, or ALL)
- Include a short requirement source note or source link
- Avoid frivolous, duplicate, or low-value items. Keep the list scope-relevant and practical.

Discipline rules:
- Use a specific discipline value, not a placeholder.
- Prefer one of: Architecture, Civil, Electrical, Mechanical, IT, Operations, Safety, Security, Procurement, Commercial, Quality, Regulatory, Program Management, Other.
- NEVER return the literal value "Discipline".

Return ONLY valid JSON in this exact structure:
{
  "requirements": [
    {
      "requirement": "Specific requirement statement",
      "requirementType": "Technical|Regulatory|Functional|Operational|Non-Functional|Safety|Sustainability|Business|Stakeholder|Solutions|Transitional|Other",
      "discipline": "Owning discipline",
      "role": "Primary role responsible",
      "person": "Specific person (optional if role is provided)",
      "phase": "Initiation|Planning|Design|Execution|Launch|ALL",
      "requirementSource": "Source note or URL"
    }
  ]
}

Business Case:
$businessCase
''';

  String _risksPrompt(List<AiSolutionItem> solutions, String notes) {
    final list = solutions
        .map((s) =>
            '{"title": "${_escape(s.title)}", "description": "${_escape(s.description)}"}')
        .join(',');
    return '''
IMPORTANT: Generate UNIQUE and DIFFERENT risks for EACH solution. Each solution has its own specific characteristics, so the risks should be tailored to that particular solution's approach, technology, and implementation strategy.

Do NOT repeat the same generic risks across solutions. Consider:
- The specific implementation approach of each solution
- Technical challenges unique to that solution
- Resource and skill requirements specific to that approach
- Integration challenges particular to that solution's architecture
- Timeline and budget risks specific to that solution's scope

Given these potential solutions, provide three distinct, solution-specific delivery risks for each. Keep each risk under 22 words, actionable and specific to that particular solution. Be detailed and specific: do not use "etc.", "and similar", or vague groupings. State each risk explicitly.

Return ONLY valid JSON with this exact structure:
{
  "risks": [
    {"solution": "Solution Name", "items": ["Unique Risk 1 specific to this solution", "Unique Risk 2 specific to this solution", "Unique Risk 3 specific to this solution"]}
  ]
}

Solutions: [$list]

Context notes (optional): $notes
''';
  }

  /// Generate risk suggestions for a single risk field using KAZ AI
  Future<List<String>> generateSingleRiskSuggestions({
    required String solutionTitle,
    required int riskNumber,
    required List<String> existingRisks,
    required String contextNotes,
  }) async {
    if (!OpenAiConfig.isConfigured) {
      return _fallbackSingleRiskSuggestions(solutionTitle, riskNumber);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final existingRisksText = existingRisks.isEmpty
        ? 'None yet'
        : existingRisks.map((r) => '- $r').join('\n');

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': 0.7,
      'max_completion_tokens': 600,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a risk analyst helping identify project delivery risks. Generate unique, specific risks that are different from any already identified. Return strict JSON only.'
        },
        {
          'role': 'user',
          'content': '''
Generate 3 unique risk suggestions for Risk #$riskNumber of the solution: "$solutionTitle"

Already identified risks for this solution (DO NOT repeat these):
$existingRisksText

Context notes: ${contextNotes.isEmpty ? 'None provided' : contextNotes}

Return ONLY valid JSON with this exact structure:
{
  "suggestions": ["Risk suggestion 1", "Risk suggestion 2", "Risk suggestion 3"]
}

Make each suggestion:
- Specific to this solution's approach
- Different from the existing risks
- Actionable and under 25 words
- Focus on delivery, technical, resource, or timeline risks
'''
        }
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('OpenAI error ${response.statusCode}');
      }

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;

      final suggestions = (parsed['suggestions'] as List? ?? [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .take(3)
          .toList();

      return suggestions.isEmpty
          ? _fallbackSingleRiskSuggestions(solutionTitle, riskNumber)
          : suggestions;
    } catch (e) {
      if (kDebugMode) debugPrint('generateSingleRiskSuggestions failed: $e');
      return _fallbackSingleRiskSuggestions(solutionTitle, riskNumber);
    }
  }

  List<String> _fallbackSingleRiskSuggestions(
      String solutionTitle, int riskNumber) {
    final allFallbacks = [
      'Resource availability may impact timeline due to competing project priorities.',
      'Technical integration complexity could lead to unexpected delays and cost overruns.',
      'Stakeholder alignment challenges may slow decision-making and approval processes.',
      'Vendor dependency creates risk if external deliverables are delayed or below quality.',
      'Scope creep from evolving requirements could impact budget and schedule.',
      'Knowledge transfer gaps may affect team productivity during implementation.',
      'Data migration complexity could introduce quality issues and extend timelines.',
      'Change management resistance may slow user adoption and reduce expected benefits.',
      'Infrastructure scaling requirements may exceed initial capacity planning estimates.',
    ];

    // Return different fallbacks based on risk number to avoid duplicates
    final startIdx = (riskNumber - 1) * 3;
    return [
      allFallbacks[startIdx % allFallbacks.length],
      allFallbacks[(startIdx + 1) % allFallbacks.length],
      allFallbacks[(startIdx + 2) % allFallbacks.length],
    ];
  }

  String _projectFrameworkPrompt(String context) {
    final escaped = _escape(context);
    return '''
Determine the best overall project framework (Waterfall, Agile, or Hybrid) and generate three distinct project goals aligned with that framework. Each goal should include a brief description (max 40 words) and may optionally specify the preferred framework if Hybrid is chosen.

Return ONLY valid JSON in this exact structure:
{
  "framework": "Waterfall|Agile|Hybrid",
  "goals": [
    {
      "name": "Goal 1",
      "description": "Concise description",
      "framework": "Optional: Waterfall|Agile|Hybrid"
    }
  ]
}

Project Context:
"""
$escaped
"""
''';
  }

  Future<String> generateSsherPlanSummary({
    required String context,
    int maxTokens = 450,
    double temperature = 0.45,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) return '';
    if (!OpenAiConfig.isConfigured) {
      return _fallbackSsherSummary(trimmedContext);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are an SSHER strategist. Craft a concise summary (120-180 words) that highlights the safety, security, health, environment, and regulatory priorities tied to the provided context. Always return ONLY valid JSON matching the requested schema.'
        },
        {
          'role': 'user',
          'content': _ssherSummaryPrompt(trimmedContext),
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content = OpenAiConfig.extractContent(data);
      if (content.isNotEmpty) {
        final parsed = _decodeJsonSafely(content);
        final summary = parsed != null
            ? (parsed['summary'] ?? parsed['text'] ?? '').toString().trim()
            : '';
        if (summary.isNotEmpty) return summary;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('generateSsherPlanSummary failed: $e');
    }

    return _fallbackSsherSummary(trimmedContext);
  }

  Future<List<SsherEntry>> generateSsherEntries({
    required String context,
    int itemsPerCategory = 2,
    int maxTokens = 900,
    double temperature = 0.5,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) return [];
    if (!OpenAiConfig.isConfigured) {
      return _fallbackSsherEntries(trimmedContext, itemsPerCategory);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are an SSHER strategist. Generate concise, realistic table entries for safety, security, health, environment, and regulatory risks. Always return ONLY valid JSON matching the requested schema.'
        },
        {
          'role': 'user',
          'content': _ssherEntriesPrompt(trimmedContext, itemsPerCategory),
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content = OpenAiConfig.extractContent(data);
      if (content.isNotEmpty) {
        final parsed = _decodeJsonSafely(content);
        if (parsed != null) {
          final entries = _parseSsherEntries(parsed, itemsPerCategory);
          if (entries.isNotEmpty) return entries;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('generateSsherEntries failed: $e');
    }

    return _fallbackSsherEntries(trimmedContext, itemsPerCategory);
  }

  /// Generates a concise, project-specific Interface Management Plan that
  /// incorporates the user's additional-interfaces input (from the popup),
  /// the project context, and the stakeholder management plan. Summarizes how
  /// interfaces will be stewarded via the register, risk process, and meetings.
  Future<String> generateInterfaceManagementPlan({
    required String context,
    required String additionalInterfaces,
    required String stakeholderPlanSummary,
    int maxTokens = 700,
    double temperature = 0.5,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) return '';
    if (!OpenAiConfig.isConfigured) {
      return _fallbackInterfaceManagementPlan(
          trimmedContext, additionalInterfaces, stakeholderPlanSummary);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a senior project interface manager. Write a concise (180-260 words) Interface Management Plan that is SPECIFIC to the project context provided. Reference actual project names, stakeholders, vendors, and scope elements where possible. Summarize how interfaces will be stewarded using the Interface Register, the Risk Management process, coordination meetings, and governance cadence. Always return ONLY valid JSON.'
        },
        {
          'role': 'user',
          'content': _interfaceManagementPlanPrompt(
              trimmedContext, additionalInterfaces, stakeholderPlanSummary),
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content = OpenAiConfig.extractContent(data);
      if (content.isNotEmpty) {
        final parsed = _decodeJsonSafely(content);
        final plan = parsed != null
            ? (parsed['plan'] ?? parsed['summary'] ?? parsed['text'] ?? '')
                .toString()
                .trim()
            : '';
        if (plan.isNotEmpty) return plan;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('generateInterfaceManagementPlan failed: $e');
    }

    return _fallbackInterfaceManagementPlan(
        trimmedContext, additionalInterfaces, stakeholderPlanSummary);
  }

  /// Generates interface register entries by analyzing the project context,
  /// stakeholder plan, vendor/contractor data, and program/portfolio context.
  /// Returns a list of maps with keys: boundary, interfaceType, partyA,
  /// partyB, criticality, priority, status, owner, notes.
  Future<List<Map<String, dynamic>>> generateInterfaceEntries({
    required String context,
    required String additionalInterfaces,
    required String programPortfolioContext,
    int maxItems = 12,
    int maxTokens = 1400,
    double temperature = 0.45,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) return [];
    if (!OpenAiConfig.isConfigured) {
      return _fallbackInterfaceEntries(
          trimmedContext, additionalInterfaces, maxItems);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a senior interface management analyst. Identify cross-scope interfaces where project activities might cross with vendors, contractors, other companies, organizations, or businesses. Focus on REAL interfaces (data flow, physical handoff, contractual dependency, organizational coordination). Return up to $maxItems entries. Always return ONLY valid JSON.'
        },
        {
          'role': 'user',
          'content': _interfaceEntriesPrompt(
              trimmedContext, additionalInterfaces, programPortfolioContext, maxItems),
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content = OpenAiConfig.extractContent(data);
      if (content.isNotEmpty) {
        final parsed = _decodeJsonSafely(content);
        if (parsed != null) {
          final list = parsed['entries'] ?? parsed['interfaces'] ?? [];
          if (list is List) {
            return list
                .map((e) {
                  if (e is Map) {
                    return {
                      'boundary': (e['boundary'] ?? e['name'] ?? e['title'] ?? '')
                          .toString()
                          .trim(),
                      'interfaceType': (e['interfaceType'] ?? e['type'] ??
                              'Organizational')
                          .toString()
                          .trim(),
                      'partyA': (e['partyA'] ?? e['party_a'] ?? e['provider'] ??
                              'Project Team')
                          .toString()
                          .trim(),
                      'partyB': (e['partyB'] ?? e['party_b'] ??
                              e['receiver'] ?? e['counterparty'] ?? '')
                          .toString()
                          .trim(),
                      'criticality': (e['criticality'] ?? 'Major')
                          .toString()
                          .trim(),
                      'priority': (e['priority'] ?? 'Medium')
                          .toString()
                          .trim(),
                      'status': (e['status'] ?? 'Pending')
                          .toString()
                          .trim(),
                      'owner': (e['owner'] ?? e['responsible'] ?? '')
                          .toString()
                          .trim(),
                      'notes': (e['notes'] ?? e['description'] ?? '')
                          .toString()
                          .trim(),
                    };
                  }
                  return <String, dynamic>{};
                })
                .where((m) => m['boundary']!.isNotEmpty)
                .take(maxItems)
                .toList();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('generateInterfaceEntries failed: $e');
    }

    return _fallbackInterfaceEntries(
        trimmedContext, additionalInterfaces, maxItems);
  }

  /// Generates a per-category SSHER plan (Safety Plan, Security Plan, Health Plan,
  /// Environment Plan, Regulatory Plan). The plan is concise (90-150 words) and
  /// customized for the project's type, location, and rules.
  Future<String> generateSsherCategoryPlan({
    required String context,
    required String category, // 'safety' | 'security' | 'health' | 'environment' | 'regulatory'
    int maxTokens = 350,
    double temperature = 0.5,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) return '';
    if (!OpenAiConfig.isConfigured) {
      return _fallbackSsherCategoryPlan(trimmedContext, category);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are an SSHER strategist. Craft a concise $category plan (90-150 words) tailored to the project\'s type, location, and regulatory environment. Always return ONLY valid JSON matching the requested schema.'
        },
        {
          'role': 'user',
          'content': _ssherCategoryPlanPrompt(trimmedContext, category),
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content = OpenAiConfig.extractContent(data);
      if (content.isNotEmpty) {
        final parsed = _decodeJsonSafely(content);
        final plan = parsed != null
            ? (parsed['plan'] ?? parsed['summary'] ?? parsed['text'] ?? '')
                .toString()
                .trim()
            : '';
        if (plan.isNotEmpty) return plan;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('generateSsherCategoryPlan failed: $e');
    }

    return _fallbackSsherCategoryPlan(trimmedContext, category);
  }

  /// Generates a list of applicable UN Sustainable Development Goals for the
  /// project, with rationale tied to the project context.
  Future<List<Map<String, String>>> generateSdgRecommendations({
    required String context,
    int maxTokens = 600,
    double temperature = 0.4,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) return [];
    if (!OpenAiConfig.isConfigured) {
      return _fallbackSdgRecommendations(trimmedContext);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a sustainability analyst. Identify the UN Sustainable Development Goals (SDGs 1-17) most applicable to this project based on its scope, location, and impact areas. Return ONLY valid JSON.'
        },
        {
          'role': 'user',
          'content': _ssherSdgPrompt(trimmedContext),
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content = OpenAiConfig.extractContent(data);
      if (content.isNotEmpty) {
        final parsed = _decodeJsonSafely(content);
        if (parsed != null) {
          final list = parsed['sdgs'] ?? parsed['goals'] ?? [];
          if (list is List) {
            return list
                .map((e) {
                  if (e is Map) {
                    return {
                      'goal': (e['goal'] ?? e['id'] ?? e['number'] ?? '')
                          .toString(),
                      'title': (e['title'] ?? e['name'] ?? '').toString(),
                      'rationale': (e['rationale'] ?? e['reason'] ?? '').toString(),
                    };
                  }
                  return <String, String>{};
                })
                .where((m) => m['goal']!.isNotEmpty)
                .toList();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('generateSdgRecommendations failed: $e');
    }

    return _fallbackSdgRecommendations(trimmedContext);
  }

  Future<Map<String, List<Map<String, dynamic>>>> generateLaunchPhaseEntries({
    required String context,
    required Map<String, String> sections,
    int itemsPerSection = 2,
    int maxTokens = 1600,
    double temperature = 0.5,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) return {};
    if (!OpenAiConfig.isConfigured) {
      return _fallbackLaunchEntries(trimmedContext, sections, itemsPerSection);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'launch-phase analyst generating concise and realistic table entries',
            strictJson: true,
            extraRules:
                'Return only valid JSON matching the requested schema for each section key.',
          ),
        },
        {
          'role': 'user',
          'content': _launchPhaseEntriesPrompt(
              trimmedContext, sections, itemsPerSection),
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content = OpenAiConfig.extractContent(data);
      if (content.isNotEmpty) {
        final parsed = _decodeJsonSafely(content);
        if (parsed != null) {
          final entries =
              _parseLaunchPhaseEntries(parsed, sections, itemsPerSection);
          if (entries.isNotEmpty) return entries;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('generateLaunchPhaseEntries failed: $e');
    }

    return _fallbackLaunchEntries(trimmedContext, sections, itemsPerSection);
  }

  /// Generate staffing role suggestions based on PreferredSolution and project context
  /// Returns a list of role names (3-4 suggestions) that are relevant to the project
  Future<List<String>> generateStaffingRoleSuggestions({
    required String context,
    int maxSuggestions = 4,
    int maxTokens = 400,
    double temperature = 0.6,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) return _fallbackStaffingRoles();

    if (!OpenAiConfig.isConfigured) {
      return _fallbackStaffingRoles();
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'staffing specialist proposing role profiles for project delivery',
            strictJson: true,
            extraRules:
                'Return only valid JSON with a "roles" array and keep roles domain-specific to the project context.',
          ),
        },
        {
          'role': 'user',
          'content':
              _staffingRoleSuggestionsPrompt(trimmedContext, maxSuggestions),
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content = OpenAiConfig.extractContent(data);
      if (content.isNotEmpty) {
        final parsed = _decodeJsonSafely(content);
        if (parsed != null) {
          final roles = _parseStaffingRoleSuggestions(parsed);
          if (roles.isNotEmpty) return roles;
        }
      }
    } catch (e) {
      debugPrint('generateStaffingRoleSuggestions failed: $e');
    }

    return _fallbackStaffingRoles();
  }

  String _staffingRoleSuggestionsPrompt(String context, int maxSuggestions) {
    final escaped = _escape(context);
    return '''
Based on the project context below, suggest $maxSuggestions specific staffing roles that would be essential for executing this project.

Focus on roles that are:
- Domain-specific to the project type (e.g., healthcare, technology, construction)
- Relevant to the preferred solution
- Critical for project success

Return ONLY valid JSON with this exact structure:
{
  "roles": [
    "Role Name 1",
    "Role Name 2",
    "Role Name 3",
    "Role Name 4"
  ]
}

Project Context:
"""
$escaped
"""
''';
  }

  List<String> _parseStaffingRoleSuggestions(Map<String, dynamic> parsed) {
    final rolesRaw = parsed['roles'];
    if (rolesRaw is List) {
      return rolesRaw
          .map((r) => _stripAsterisks(r.toString().trim()))
          .where((r) => r.isNotEmpty)
          .toList();
    }
    return [];
  }

  List<String> _fallbackStaffingRoles() {
    return [
      'Project Manager',
      'Technical Lead',
      'Business Analyst',
      'Quality Assurance Specialist',
    ];
  }

  Future<List<StaffingRow>> generateStaffingRows({
    required String context,
    int maxRows = 4,
    int maxTokens = 900,
    double temperature = 0.4,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) {
      return _fallbackStaffingRows(trimmedContext, maxRows);
    }
    if (!OpenAiConfig.isConfigured) {
      return _fallbackStaffingRows(trimmedContext, maxRows);
    }

    final projectScale = _detectProjectScale(trimmedContext);
    final staffingGuidance = _scaleStaffingCostGuidance(projectScale);

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'execution phase staffing lead drafting staffing needs for project delivery',
            strictJson: true,
            extraRules:
                'Return only valid JSON with a "staffingRows" array. Keep roles and details aligned to the project context.',
          ),
        },
        {
          'role': 'user',
          'content': _staffingRowsPrompt(trimmedContext, maxRows, staffingGuidance),
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 14));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content = OpenAiConfig.extractContent(data);
      if (content.isNotEmpty) {
        final parsed = _decodeJsonSafely(content);
        if (parsed != null) {
          final rows = _parseStaffingRows(parsed, maxRows, projectScale);
          if (rows.isNotEmpty) return rows;
        }
      }
    } catch (e) {
      debugPrint('generateStaffingRows failed: $e');
    }

    return _fallbackStaffingRows(trimmedContext, maxRows);
  }

  String _staffingRowsPrompt(String context, int maxRows, String staffingGuidance) {
    final escaped = _escape(context);
    return '''
Generate up to $maxRows staffing rows for the execution phase based on the project context.

Return ONLY valid JSON with this structure:
{
  "staffingRows": [
    {
      "role": "Role title",
      "quantity": 2,
      "isInternal": true,
      "startDate": "Month 1",
      "durationMonths": "6",
      "monthlyCost": "4500",
      "roleDescription": "Single sentence summary of responsibilities.",
      "skillRequirements": ["Skill A", "Skill B"],
      "status": "Not Started"
    }
  ]
}

Guidelines:
- Keep roles specific to the project context.
- Use realistic quantities (1-4) and durations (1-12 months).
- Provide concise, actionable descriptions and 2-4 skill requirements.
- MONTHLY COSTS MUST be realistic for the project's scale and market. See constraints below.

$staffingGuidance

Project context:
"""
$escaped
"""
''';
  }

  List<StaffingRow> _parseStaffingRows(
      Map<String, dynamic> parsed, int maxRows,
      [_AiProjectScale projectScale = _AiProjectScale.medium]) {
    final rowsRaw = parsed['staffingRows'] ??
        parsed['rows'] ??
        parsed['staffing'] ??
        parsed['items'];
    if (rowsRaw is! List) return [];
    final rows = <StaffingRow>[];

    for (final entry in rowsRaw) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final role = _stripAsterisks(
          (map['role'] ?? map['title'] ?? map['position'] ?? '')
              .toString()
              .trim());
      if (role.isEmpty) continue;
      final quantityRaw = map['quantity'];
      final quantity = quantityRaw is num
          ? quantityRaw.toInt()
          : int.tryParse(quantityRaw?.toString() ?? '') ?? 1;
      final isInternalRaw = map['isInternal'] ?? map['internal'] ?? map['type'];
      final isInternal = isInternalRaw is bool
          ? isInternalRaw
          : (isInternalRaw?.toString().toLowerCase().contains('external') ??
                  false)
              ? false
              : true;
      final startDate = (map['startDate'] ?? map['start'] ?? '').toString();
      final duration =
          (map['durationMonths'] ?? map['duration'] ?? '').toString();
      final monthlyCostRaw =
          (map['monthlyCost'] ?? map['monthlyRate'] ?? map['cost'] ?? '')
              .toString();
      // Clamp monthly cost to scale-appropriate range
      final monthlyCostParsed = double.tryParse(
            monthlyCostRaw.replaceAll(RegExp(r'[^0-9.]'), ''),
          ) ?? 0;
      final monthlyCostClamped = _clampStaffCost(monthlyCostParsed, projectScale);
      final monthlyCost = monthlyCostClamped.toStringAsFixed(0);
      final description =
          (map['roleDescription'] ?? map['description'] ?? map['summary'] ?? '')
              .toString();
      final skillRequirements =
          _formatSkillRequirements(map['skillRequirements'] ?? map['skills']);
      final status =
          (map['status'] ?? map['phaseStatus'] ?? 'Not Started').toString();

      rows.add(
        StaffingRow(
          role: role,
          quantity: quantity <= 0 ? 1 : quantity,
          isInternal: isInternal,
          startDate: startDate,
          durationMonths: duration,
          monthlyCost: monthlyCost,
          roleDescription: description,
          skillRequirements: skillRequirements,
          status: status.isEmpty ? 'Not Started' : status,
        ),
      );
      if (rows.length >= maxRows) break;
    }

    return rows;
  }

  String _formatSkillRequirements(dynamic raw) {
    if (raw == null) return '';
    if (raw is List) {
      final items = raw
          .map((e) => _stripAsterisks(e.toString().trim()))
          .where((e) => e.isNotEmpty)
          .toList();
      if (items.isEmpty) return '';
      return items.map((e) => '. $e').join('\n');
    }
    final text = _stripAsterisks(raw.toString().trim());
    if (text.isEmpty) return '';
    if (text.contains('\n')) {
      final lines =
          text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);
      return lines.map((l) => l.startsWith('.') ? l : '. $l').join('\n');
    }
    return text.startsWith('.') ? text : '. $text';
  }

  List<StaffingRow> _fallbackStaffingRows(String context, int maxRows) {
    final roles = _fallbackStaffingRoles();
    final rows = <StaffingRow>[];
    for (final role in roles.take(maxRows)) {
      rows.add(
        StaffingRow(
          role: role,
          quantity: 1,
          isInternal: true,
          startDate: 'Month 1',
          durationMonths: '6',
          monthlyCost: '4000',
          roleDescription: 'Owns delivery responsibilities for $role.',
          skillRequirements: '. Planning\n. Execution\n. Stakeholder updates',
          status: 'Not Started',
        ),
      );
    }
    return rows;
  }

  Future<List<MeetingRow>> generateMeetingRows({
    required String context,
    required List<String> availableRoles,
    int maxRows = 3,
    int maxTokens = 900,
    double temperature = 0.4,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) {
      return _fallbackMeetingRows(availableRoles);
    }
    if (!OpenAiConfig.isConfigured) {
      return _fallbackMeetingRows(availableRoles);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'execution coordinator designing meeting cadences and objectives',
            strictJson: true,
            extraRules:
                'Return only valid JSON with a "meetings" array of meeting rows.',
          ),
        },
        {
          'role': 'user',
          'content':
              _meetingRowsPrompt(trimmedContext, availableRoles, maxRows),
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 14));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content = OpenAiConfig.extractContent(data);
      if (content.isNotEmpty) {
        final parsed = _decodeJsonSafely(content);
        if (parsed != null) {
          final rows = _parseMeetingRows(parsed, maxRows);
          if (rows.isNotEmpty) return rows;
        }
      }
    } catch (e) {
      debugPrint('generateMeetingRows failed: $e');
    }

    return _fallbackMeetingRows(availableRoles);
  }

  String _meetingRowsPrompt(String context, List<String> roles, int maxRows) {
    final escaped = _escape(context);
    final rolesLine =
        roles.isEmpty ? 'No roles provided' : roles.map(_escape).join(', ');
    return '''
Generate up to $maxRows meeting cadence rows for execution based on the project context.

Return ONLY valid JSON with this structure:
{
  "meetings": [
    {
      "meetingType": "Weekly Sync",
      "frequency": "Weekly",
      "keyParticipants": ["Project Manager", "Ops Lead"],
      "durationHours": "1",
      "meetingObjective": "Short, actionable objective",
      "actionItems": "Optional bullet list",
      "status": "Scheduled"
    }
  ]
}

Available roles (use these for keyParticipants when possible):
$rolesLine

Project context:
"""
$escaped
"""
''';
  }

  List<MeetingRow> _parseMeetingRows(Map<String, dynamic> parsed, int maxRows) {
    final raw = parsed['meetings'] ?? parsed['rows'] ?? parsed['items'];
    if (raw is! List) return [];
    final rows = <MeetingRow>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final meetingType =
          (map['meetingType'] ?? map['title'] ?? '').toString().trim();
      if (meetingType.isEmpty) continue;
      final frequency =
          (map['frequency'] ?? map['cadence'] ?? '').toString().trim();
      final duration =
          (map['durationHours'] ?? map['duration'] ?? '').toString().trim();
      final objective =
          (map['meetingObjective'] ?? map['objective'] ?? '').toString().trim();
      final actionItems =
          (map['actionItems'] ?? map['agenda'] ?? '').toString().trim();
      final status =
          (map['status'] ?? map['state'] ?? 'Scheduled').toString().trim();
      final participantsRaw =
          map['keyParticipants'] ?? map['participants'] ?? const [];
      final participants = <String>[];
      if (participantsRaw is List) {
        participants.addAll(participantsRaw
            .map((e) => _stripAsterisks(e.toString().trim()))
            .where((e) => e.isNotEmpty));
      } else if (participantsRaw != null) {
        final text = participantsRaw.toString();
        participants.addAll(text
            .split(RegExp(r'[,;\\n]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty));
      }

      rows.add(
        MeetingRow(
          meetingType: meetingType,
          frequency: frequency.isEmpty ? 'Weekly' : frequency,
          keyParticipants: participants,
          durationHours: duration.isEmpty ? '1' : duration,
          meetingObjective: objective,
          actionItems: actionItems,
          status: status.isEmpty ? 'Scheduled' : status,
        ),
      );
      if (rows.length >= maxRows) break;
    }
    return rows;
  }

  List<MeetingRow> _fallbackMeetingRows(List<String> roles) {
    final List<String> participants = roles.isNotEmpty
        ? roles.take(3).map((e) => e.toString()).toList()
        : const <String>[];
    return [
      MeetingRow(
        meetingType: 'Weekly Sync',
        frequency: 'Weekly',
        keyParticipants: participants,
        durationHours: '1',
        meetingObjective: 'Align on weekly priorities and blockers.',
        actionItems:
            '. Share updates\n. Resolve blockers\n. Confirm next steps',
        status: 'Scheduled',
      ),
      MeetingRow(
        meetingType: 'Stakeholder Update',
        frequency: 'Bi-Weekly',
        keyParticipants: participants,
        durationHours: '1',
        meetingObjective: 'Provide sponsors with progress and risk updates.',
        actionItems: '. Review milestones\n. Confirm decisions needed',
        status: 'Scheduled',
      ),
    ];
  }

  Future<Map<String, List<Map<String, String>>>>
      generateSecurityRolesAndPermissions({
    required String context,
    int maxRoles = 4,
    int maxPermissions = 5,
    int maxTokens = 700,
    double temperature = 0.4,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) {
      return _fallbackSecurityRolesPermissions(
          trimmedContext, maxRoles, maxPermissions);
    }
    if (!OpenAiConfig.isConfigured) {
      return _fallbackSecurityRolesPermissions(
          trimmedContext, maxRoles, maxPermissions);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'security governance lead defining roles and access permissions',
            strictJson: true,
            extraRules:
                'Return only valid JSON with "roles" and "permissions" arrays.',
          ),
        },
        {
          'role': 'user',
          'content': _securityRolesPermissionsPrompt(
              trimmedContext, maxRoles, maxPermissions),
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content = OpenAiConfig.extractContent(data);
      if (content.isNotEmpty) {
        final parsed = _decodeJsonSafely(content);
        if (parsed != null) {
          final results =
              _parseSecurityRolesPermissions(parsed, maxRoles, maxPermissions);
          if (results['roles']!.isNotEmpty ||
              results['permissions']!.isNotEmpty) {
            return results;
          }
        }
      }
    } catch (e) {
      debugPrint('generateSecurityRolesAndPermissions failed: $e');
    }

    return _fallbackSecurityRolesPermissions(
        trimmedContext, maxRoles, maxPermissions);
  }

  String _securityRolesPermissionsPrompt(
      String context, int maxRoles, int maxPermissions) {
    final escaped = _escape(context);
    return '''
Create security governance seed data for the project below.

Return ONLY valid JSON with this structure:
{
  "roles": [
    {"name": "Role title", "description": "Short responsibility summary"}
  ],
  "permissions": [
    {"resource": "System or data domain", "scope": "Access scope or level"}
  ]
}

Guidelines:
- Provide up to $maxRoles roles and up to $maxPermissions permissions.
- Keep each item specific to the project context.
- Permissions should mention the system/data area and the access level.

Project context:
"""
$escaped
"""
''';
  }

  Map<String, List<Map<String, String>>> _parseSecurityRolesPermissions(
      Map<String, dynamic> parsed, int maxRoles, int maxPermissions) {
    final rolesRaw =
        parsed['roles'] ?? parsed['security_roles'] ?? parsed['roleItems'];
    final permissionsRaw = parsed['permissions'] ??
        parsed['securityPermissions'] ??
        parsed['permissionItems'];

    final roles = <Map<String, String>>[];
    if (rolesRaw is List) {
      for (final entry in rolesRaw) {
        if (entry is Map) {
          final map = Map<String, dynamic>.from(entry);
          final name =
              _stripAsterisks((map['name'] ?? map['role'] ?? '').toString())
                  .trim();
          if (name.isEmpty) continue;
          final desc =
              (map['description'] ?? map['summary'] ?? '').toString().trim();
          roles.add({'name': name, 'description': desc});
        } else if (entry != null) {
          final name = _stripAsterisks(entry.toString().trim());
          if (name.isNotEmpty) {
            roles.add({'name': name, 'description': ''});
          }
        }
        if (roles.length >= maxRoles) break;
      }
    }

    final permissions = <Map<String, String>>[];
    if (permissionsRaw is List) {
      for (final entry in permissionsRaw) {
        if (entry is Map) {
          final map = Map<String, dynamic>.from(entry);
          final resource = _stripAsterisks(
                  (map['resource'] ?? map['system'] ?? map['area'] ?? '')
                      .toString())
              .trim();
          if (resource.isEmpty) continue;
          final scope =
              (map['scope'] ?? map['level'] ?? map['access'] ?? '').toString();
          permissions.add({'resource': resource, 'scope': scope.trim()});
        } else if (entry != null) {
          final resource = _stripAsterisks(entry.toString().trim());
          if (resource.isNotEmpty) {
            permissions.add({'resource': resource, 'scope': ''});
          }
        }
        if (permissions.length >= maxPermissions) break;
      }
    }

    return {
      'roles': roles,
      'permissions': permissions,
    };
  }

  Map<String, List<Map<String, String>>> _fallbackSecurityRolesPermissions(
      String context, int maxRoles, int maxPermissions) {
    final projectName = _extractProjectName(context);
    final assetName = projectName.isEmpty ? 'the project' : projectName;
    final roles = [
      {
        'name': 'Security Lead',
        'description':
            'Owns security controls and risk mitigation for $assetName.',
      },
      {
        'name': 'IT Administrator',
        'description':
            'Manages system access, credentials, and infrastructure safeguards.',
      },
      {
        'name': 'Compliance Officer',
        'description':
            'Ensures regulatory and policy compliance across delivery.',
      },
      {
        'name': 'Vendor Security Coordinator',
        'description':
            'Tracks vendor access, NDA compliance, and third-party risks.',
      },
    ].take(maxRoles).toList();

    final permissions = [
      {
        'resource': 'Core project systems',
        'scope': 'Admin access for delivery leads',
      },
      {
        'resource': 'Customer or stakeholder data',
        'scope': 'Read/write with approval',
      },
      {
        'resource': 'Vendor portals',
        'scope': 'Limited access with audit logging',
      },
      {
        'resource': 'Financial or contract documents',
        'scope': 'Read-only for authorized roles',
      },
    ].take(maxPermissions).toList();

    return {
      'roles': roles,
      'permissions': permissions,
    };
  }

  /// Generate meeting objective/agenda based on meeting type and participant roles
  /// Returns a prose meeting objective (no bullets) and optionally a 5-point agenda
  Future<Map<String, String>> generateMeetingObjective({
    required String context,
    required String meetingType,
    required List<String> participantRoles,
    int maxTokens = 600,
    double temperature = 0.6,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) {
      return _fallbackMeetingObjective(meetingType, participantRoles);
    }

    if (!OpenAiConfig.isConfigured) {
      return _fallbackMeetingObjective(meetingType, participantRoles);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a meeting facilitator. Generate a detailed meeting objective (prose format, no bullets) and a 5-point agenda based on the meeting type and participant roles. The objective should be tailored to the project context and roles involved. Return ONLY valid JSON with "objective" (prose text) and "agenda" (array of 5 agenda items).'
        },
        {
          'role': 'user',
          'content': _meetingObjectivePrompt(
              trimmedContext, meetingType, participantRoles),
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content = OpenAiConfig.extractContent(data);
      if (content.isNotEmpty) {
        final parsed = _decodeJsonSafely(content);
        if (parsed != null) {
          final result = _parseMeetingObjective(parsed);
          if (result.isNotEmpty) return result;
        }
      }
    } catch (e) {
      debugPrint('generateMeetingObjective failed: $e');
    }

    return _fallbackMeetingObjective(meetingType, participantRoles);
  }

  String _meetingObjectivePrompt(
      String context, String meetingType, List<String> roles) {
    final escaped = _escape(context);
    final rolesText = roles.isEmpty ? 'General team members' : roles.join(', ');
    return '''
Based on the project context below, generate a detailed meeting objective and 5-point agenda for a "$meetingType" meeting.

Participant Roles: $rolesText

Requirements:
- The objective should be prose format (no bullets, complete sentences)
- The agenda should be 5 specific, actionable items relevant to the meeting type and roles
- Consider the project context and preferred solution when generating content

Return ONLY valid JSON with this exact structure:
{
  "objective": "Detailed prose meeting objective that explains the purpose and expected outcomes of this meeting...",
  "agenda": [
    "Agenda item 1",
    "Agenda item 2",
    "Agenda item 3",
    "Agenda item 4",
    "Agenda item 5"
  ]
}

Project Context:
"""
$escaped
"""
''';
  }

  Map<String, String> _parseMeetingObjective(Map<String, dynamic> parsed) {
    final objective =
        _stripAsterisks((parsed['objective'] ?? '').toString().trim());
    final agendaRaw = parsed['agenda'];
    final agendaItems = <String>[];

    if (agendaRaw is List) {
      agendaItems.addAll(
        agendaRaw
            .map((a) => _stripAsterisks(a.toString().trim()))
            .where((a) => a.isNotEmpty),
      );
    }

    // Format agenda items with "." bullet prefix
    final agendaText = agendaItems.map((item) => '. $item').join('\n');

    return {
      'objective': objective.isNotEmpty
          ? objective
          : 'Review project progress and align on next steps.',
      'agenda': agendaText.isNotEmpty
          ? agendaText
          : '. Review status updates\n. Discuss blockers\n. Plan next sprint\n. Assign action items\n. Set follow-up date',
    };
  }

  Map<String, String> _fallbackMeetingObjective(
      String meetingType, List<String> roles) {
    final rolesText = roles.isEmpty ? 'team members' : roles.join(', ');
    return {
      'objective':
          'Conduct a $meetingType meeting with $rolesText to review progress, address challenges, and align on next steps.',
      'agenda':
          '. Review status updates\n. Discuss blockers\n. Plan next sprint\n. Assign action items\n. Set follow-up date',
    };
  }

  String _ssherSummaryPrompt(String context) {
    final escaped = _escape(context);
    return '''
 Using the project inputs below, write a single coherent SSHER summary (120-180 words) that highlights safety, security, health, environment, and regulatory priorities while tying the language directly to the context.

 Return ONLY valid JSON with this exact structure:
 {
   "summary": "Concise SSHER plan summary text goes here."
 }

 Project context:
 """
 $escaped
 """
 ''';
  }

  String _interfaceManagementPlanPrompt(
      String context, String additionalInterfaces, String stakeholderPlan) {
    final escapedContext = _escape(context);
    final escapedAdditional = _escape(additionalInterfaces);
    final escapedStakeholder = _escape(stakeholderPlan);
    return '''
Using the project context below, write a concise Interface Management Plan (180-260 words) that is SPECIFIC to this project. The plan MUST:
1. Reference actual project name, stakeholders, vendors, contractors, and scope elements from the context
2. Describe how interfaces will be identified, coordinated, and managed across stakeholders, organizations, systems, disciplines, and deliverables
3. Explain how the Interface Register will be used as the single source of truth
4. Reference the Risk Management process for interface-related risks
5. Define coordination meeting cadence (weekly/monthly) and governance escalation path
6. Incorporate the user's additional interfaces input below

Return ONLY valid JSON with this exact structure:
{
  "plan": "Concise Interface Management Plan text goes here."
}

User's additional interfaces input:
"""
$escapedAdditional
"""

Stakeholder Management Plan summary:
"""
$escapedStakeholder
"""

Project context:
"""
$escapedContext
"""
''';
  }

  String _fallbackInterfaceManagementPlan(
      String context, String additionalInterfaces, String stakeholderPlan) {
    final projectName = _extractProjectName(context);
    final assetName = projectName.isEmpty ? 'this project' : projectName;
    final addl = additionalInterfaces.trim().isEmpty
        ? 'No additional interfaces were identified beyond those already captured in the project scope.'
        : 'Additional interfaces identified by the project team: $additionalInterfaces';
    return 'Interface Management Plan for $assetName: The project team will maintain an Interface Register as the single source of truth for all internal and external interfaces, including vendors, contractors, and other organizational boundaries. Each interface will have a named owner, a defined criticality (Critical/Major/Minor), a coordination cadence, and a status that is reviewed weekly during the project coordination meeting. Interface-related risks will be captured in the project Risk Register with a reference back to the Interface Register entry, and mitigation actions will be tracked through the standard risk management process. Monthly interface governance reviews will be held with the project sponsor and key stakeholders to escalate unresolved interface issues, confirm handoff readiness, and approve new interfaces. Decision rights for each interface are defined in the RACI matrix. The change control process governs any additions, modifications, or closures of interfaces, with all changes logged in the Interface Change Log for audit traceability. $addl The stakeholder engagement approach is aligned with the Stakeholder Management Plan to ensure consistent communication across all interface parties.';
  }

  String _interfaceEntriesPrompt(String context, String additionalInterfaces,
      String programPortfolioContext, int maxItems) {
    final escapedContext = _escape(context);
    final escapedAdditional = _escape(additionalInterfaces);
    final escapedProgram = _escape(programPortfolioContext);
    return '''
Analyze the project context below and identify up to $maxItems cross-scope interfaces where project activities might cross with vendors, contractors, other companies, organizations, or businesses. Focus on REAL interfaces — places where data flows, physical handoffs occur, contractual dependencies exist, or organizational coordination is required.

For each interface, provide:
- boundary: short name (e.g. "Vendor X — Equipment Delivery", "Client IT — System Integration")
- interfaceType: one of Technical / Contractual / Organizational / Physical / Procedural
- partyA: the providing party (usually "Project Team" or a specific discipline)
- partyB: the receiving party (vendor, contractor, client department, external organization)
- criticality: Critical / Major / Minor
- priority: High / Medium / Low
- status: Pending / Active / Closed (default Pending)
- owner: role or name responsible for coordinating this interface
- notes: brief description of what crosses the boundary and why it matters

Also incorporate the user's additional interfaces input and any program/portfolio context provided.

Return ONLY valid JSON with this exact structure:
{
  "entries": [
    {
      "boundary": "...",
      "interfaceType": "...",
      "partyA": "...",
      "partyB": "...",
      "criticality": "...",
      "priority": "...",
      "status": "...",
      "owner": "...",
      "notes": "..."
    }
  ]
}

User's additional interfaces input:
"""
$escapedAdditional
"""

Program/Portfolio context (other projects that might share interfaces):
"""
$escapedProgram
"""

Project context:
"""
$escapedContext
"""
''';
  }

  List<Map<String, dynamic>> _fallbackInterfaceEntries(
      String context, String additionalInterfaces, int maxItems) {
    final projectName = _extractProjectName(context);
    final assetName = projectName.isEmpty ? 'the project' : projectName;
    final entries = <Map<String, dynamic>>[
      {
        'boundary': 'Client — Project Sponsor',
        'interfaceType': 'Organizational',
        'partyA': 'Project Team',
        'partyB': 'Client Sponsor',
        'criticality': 'Critical',
        'priority': 'High',
        'status': 'Pending',
        'owner': 'Project Manager',
        'notes':
            'Governance interface for $assetName — steering committee decisions, change approvals, and milestone sign-off.',
      },
      {
        'boundary': 'Vendor — Equipment/Service Delivery',
        'interfaceType': 'Contractual',
        'partyA': 'Project Team',
        'partyB': 'Primary Vendor',
        'criticality': 'Major',
        'priority': 'High',
        'status': 'Pending',
        'owner': 'Procurement Lead',
        'notes':
            'Contractual interface for vendor deliverables, acceptance criteria, and SLA tracking.',
      },
      {
        'boundary': 'IT — System Integration',
        'interfaceType': 'Technical',
        'partyA': 'Project Team',
        'partyB': 'Client IT / Infrastructure',
        'criticality': 'Major',
        'priority': 'Medium',
        'status': 'Pending',
        'owner': 'Technical Lead',
        'notes':
            'Technical interface for system integration, data migration, and environment provisioning.',
      },
      {
        'boundary': 'Regulatory — Permits & Compliance',
        'interfaceType': 'Procedural',
        'partyA': 'Project Team',
        'partyB': 'Regulatory Authority',
        'criticality': 'Critical',
        'priority': 'High',
        'status': 'Pending',
        'owner': 'Compliance Officer',
        'notes':
            'Regulatory interface for permits, inspections, and statutory reporting.',
      },
    ];
    // If the user provided additional interfaces, add a generic entry referencing them
    if (additionalInterfaces.trim().isNotEmpty &&
        additionalInterfaces.trim().toLowerCase() != 'not applicable') {
      entries.add({
        'boundary': 'Additional Interface (user-identified)',
        'interfaceType': 'Organizational',
        'partyA': 'Project Team',
        'partyB': 'See notes',
        'criticality': 'Major',
        'priority': 'Medium',
        'status': 'Pending',
        'owner': 'Project Manager',
        'notes': additionalInterfaces.trim(),
      });
    }
    return entries.take(maxItems).toList();
  }

  String _fallbackSsherSummary(String context) {
    final projectName = _extractProjectName(context);
    final assetName = projectName.isEmpty ? 'this project' : projectName;
    final highlights = _extractContextHighlights(
      context,
      const [
        'Project Objective:',
        'Business Case:',
        'Potential Solution:',
        'Front End Planning – Risks:',
        'Front End Planning – Security:',
        'Front End Planning – Requirements:',
        'Front End Planning – Procurement:',
      ],
      maxItems: 3,
    );
    final focusText = highlights.isEmpty
        ? 'project scope, delivery constraints, and stakeholder expectations'
        : highlights.join('; ');

    return 'SSHER priorities for $assetName focus on preventing safety incidents, securing assets and information, protecting workforce health, reducing environmental impact, and maintaining regulatory compliance. Current planning inputs emphasize $focusText. Each category should have clear ownership, risk ratings, mitigation actions, and weekly review cadence, with high-risk issues escalated to closure.';
  }

  List<String> _extractContextHighlights(
    String context,
    List<String> labels, {
    int maxItems = 3,
  }) {
    final highlights = <String>[];
    final lines = context.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      for (final label in labels) {
        if (!line.toLowerCase().startsWith(label.toLowerCase())) {
          continue;
        }

        var value = '';
        final colonIndex = line.indexOf(':');
        if (colonIndex != -1 && colonIndex + 1 < line.length) {
          value = line.substring(colonIndex + 1).trim();
        }
        if (value.isEmpty && i + 1 < lines.length) {
          value = lines[i + 1].trim();
        }
        value = _stripAsterisks(value);
        if (value.isEmpty) continue;

        final exists = highlights.any(
          (item) => item.toLowerCase() == value.toLowerCase(),
        );
        if (!exists) {
          highlights.add(value);
        }
        if (highlights.length >= maxItems) {
          return highlights;
        }
      }
    }

    return highlights;
  }

  String _ssherEntriesPrompt(String context, int itemsPerCategory) {
    final escaped = _escape(context);
    return '''
Using the project inputs below, generate $itemsPerCategory entries for each category (safety, security, health, environment, regulatory).
Each entry must be realistic, grounded in the project context, and customized for the project's type, location, and rules.

For each entry, include:
- A realistic estimated cost (estimated_cost as a number, e.g. 5000 or 12500.50)
- The currency (USD unless the project is in Zambia where ZMW applies)
- The cost frequency (One-time, Recurring, Monthly, Quarterly, or Annual)
- The cost unit (lump sum, per item, per month, per quarter, etc.)

Return ONLY valid JSON with this exact structure:
{
  "entries": [
    {
      "category": "safety|security|health|environment|regulatory",
      "department": "Department name",
      "teamMember": "Role or owner",
      "concern": "Short, specific concern",
      "riskLevel": "Low|Medium|High",
      "mitigation": "Short, specific mitigation action",
      "estimatedCost": "5000",
      "costCurrency": "USD",
      "costFrequency": "One-time",
      "costUnit": "lump sum"
    }
  ]
}

Project context:
"""
$escaped
"""
''';
  }

  String _launchPhaseEntriesPrompt(
      String context, Map<String, String> sections, int itemsPerSection) {
    final escaped = _escape(context);
    final sectionJson = sections.entries
        .map((entry) => '"${entry.key}": "${_escape(entry.value)}"')
        .join(',\n  ');
    return '''
You are a senior project management analyst preparing Launch Phase deliverables.
The project has progressed through Initiation → Front End Planning → Planning → Design → Execution → Launch.

CRITICAL CONTINUITY RULES:
1. CONTINUITY IS KEY: Every entry MUST directly reference and derive from actual prior-phase data provided below.
   - If the context mentions specific team members, vendors, contracts, milestones, or risks, those EXACT names and details MUST appear in your generated entries.
   - Do NOT invent new names, vendors, or team members that are not mentioned in the context.
   - If a contract exists in Execution Phase, reference THAT EXACT contract in Contract Close Out.
   - If team members are listed in Execution staffing, use THOSE EXACT names in Demobilize Team and Transition to Production.
   - If budget figures exist, carry those EXACT figures forward into Gap Analysis and Commerce Viability.
2. NO FABRICATION: If the context does not contain enough specific data for a section, generate fewer entries rather than fabricating content. It is better to return 1 accurate entry than 3 generic ones.
3. SPECIFIC OVER GENERIC: Every "title" and "details" field must contain specific references to actual data from the context — project names, person names, contract names, dollar amounts, dates, risk titles, etc.
4. DERIVE, DON'T CREATE: Your job is to carry forward and restructure existing project data into the Launch Phase format, not to create new project content from scratch.
5. Generate up to $itemsPerSection entries per section (fewer is acceptable if context is thin).

Return ONLY valid JSON with this exact structure:
{
  "sections": {
    "section_key": [
      {
        "title": "Short item title referencing actual prior-phase data",
        "details": "Supporting details that trace back to specific prior-phase entries",
        "status": "Realistic status value"
      }
    ]
  }
}

Sections:
{
  $sectionJson
}

Project context (includes data from ALL prior phases — USE THIS DATA DIRECTLY):
"""
$escaped
"""
''';
  }

  List<SsherEntry> _parseSsherEntries(
      Map<String, dynamic> parsed, int itemsPerCategory) {
    final entriesRaw = parsed['entries'] ??
        parsed['items'] ??
        parsed['rows'] ??
        parsed['data'];
    final counts = <String, int>{};
    final entries = <SsherEntry>[];

    void addEntry(String categoryKey, Map<String, dynamic> item) {
      final category = _normalizeSsherCategory(categoryKey);
      if (category.isEmpty) return;
      final count = counts[category] ?? 0;
      if (count >= itemsPerCategory) return;
      final department = (item['department'] ?? '').toString().trim();
      final teamMember =
          (item['teamMember'] ?? item['owner'] ?? item['lead'] ?? '')
              .toString()
              .trim();
      final concern = (item['concern'] ?? item['issue'] ?? item['risk'] ?? '')
          .toString()
          .trim();
      final riskLevel = _normalizeRiskLevel(
          (item['riskLevel'] ?? item['risk_level'] ?? '').toString().trim());
      final mitigation =
          (item['mitigation'] ?? item['response'] ?? item['action'] ?? '')
              .toString()
              .trim();
      if (department.isEmpty || concern.isEmpty) return;
      final estimatedCost = (item['estimatedCost'] ??
              item['estimated_cost'] ??
              item['cost'] ??
              '')
          .toString()
          .trim();
      final costCurrency =
          (item['costCurrency'] ?? item['cost_currency'] ?? 'USD')
              .toString()
              .trim();
      final costFrequency =
          (item['costFrequency'] ?? item['cost_frequency'] ?? 'One-time')
              .toString()
              .trim();
      final costUnit = (item['costUnit'] ?? item['cost_unit'] ?? 'lump sum')
          .toString()
          .trim();
      entries.add(SsherEntry(
        category: category,
        department: department,
        teamMember: teamMember.isEmpty ? 'Owner' : teamMember,
        concern: concern,
        riskLevel: riskLevel,
        mitigation:
            mitigation.isEmpty ? 'Mitigation plan in progress.' : mitigation,
        estimatedCost: estimatedCost,
        costCurrency: costCurrency.isEmpty ? 'USD' : costCurrency,
        costFrequency: costFrequency.isEmpty ? 'One-time' : costFrequency,
        costUnit: costUnit.isEmpty ? 'lump sum' : costUnit,
      ));
      counts[category] = count + 1;
    }

    if (entriesRaw is List) {
      for (final item in entriesRaw) {
        if (item is Map<String, dynamic>) {
          final category = (item['category'] ?? '').toString();
          addEntry(category, item);
        }
      }
    } else if (entriesRaw is Map) {
      for (final entry in entriesRaw.entries) {
        final category = entry.key.toString();
        final value = entry.value;
        if (value is List) {
          for (final item in value) {
            if (item is Map<String, dynamic>) {
              addEntry(category, item);
            }
          }
        }
      }
    }

    return entries;
  }

  Map<String, List<Map<String, dynamic>>> _parseLaunchPhaseEntries(
    Map<String, dynamic> parsed,
    Map<String, String> sections,
    int itemsPerSection,
  ) {
    final sectionsRaw = parsed['sections'] ?? parsed['data'] ?? parsed['items'];
    if (sectionsRaw is! Map) return {};

    final result = <String, List<Map<String, dynamic>>>{};
    for (final entry in sections.entries) {
      result[entry.key] = [];
    }

    for (final entry in sectionsRaw.entries) {
      final key = entry.key.toString();
      if (!result.containsKey(key)) continue;
      final value = entry.value;
      if (value is List) {
        for (final item in value) {
          if (result[key]!.length >= itemsPerSection) break;
          if (item is Map) {
            final mapped = Map<String, dynamic>.from(item);
            final title =
                (mapped['title'] ?? mapped['item'] ?? '').toString().trim();
            if (title.isEmpty) continue;
            result[key]!.add({
              'title': title,
              'details': (mapped['details'] ?? mapped['description'] ?? '')
                  .toString()
                  .trim(),
              'status': (mapped['status'] ?? '').toString().trim(),
            });
          }
        }
      }
    }

    result.removeWhere((key, value) => value.isEmpty);
    return result;
  }

  Map<String, List<Map<String, dynamic>>> _fallbackLaunchEntries(
    String context,
    Map<String, String> sections,
    int itemsPerSection,
  ) {
    final projectName = _extractProjectName(context);
    final assetName = projectName.isEmpty ? 'the project' : projectName;
    final result = <String, List<Map<String, dynamic>>>{};

    for (final entry in sections.entries) {
      final key = entry.key;
      final items = _fallbackLaunchEntriesForSection(key, assetName)
          .take(itemsPerSection)
          .toList();
      if (items.isNotEmpty) {
        result[key] = items;
      }
    }

    return result;
  }

  List<Map<String, dynamic>> _fallbackLaunchEntriesForSection(
      String key, String assetName) {
    switch (key) {
      case 'viability_checks':
        return [
          {
            'title': 'Revalidate value drivers for $assetName',
            'details':
                'Confirm the core business case assumptions still hold against current demand.',
            'status': 'In review',
          },
          {
            'title': 'Validate revenue model alignment',
            'details':
                'Check pricing and adoption signals against target segments.',
            'status': 'On track',
          },
        ];
      case 'financial_signals':
        return [
          {
            'title': 'Unit economics trend',
            'details':
                'Track margin per transaction and cost-to-serve against baseline.',
            'status': 'Monitor',
          },
          {
            'title': 'Demand velocity',
            'details': 'Compare weekly usage against forecasted ramp.',
            'status': 'At risk',
          },
        ];
      case 'decisions':
        return [
          {
            'title': 'Go / Grow decision checkpoint',
            'details': 'Proceed with scaled rollout once metrics stabilize.',
            'status': 'Go',
          },
          {
            'title': 'Risk mitigation action',
            'details': 'Pause expansion if cost-to-serve exceeds threshold.',
            'status': 'Guardrail',
          },
        ];
      case 'account_health':
        return [
          {
            'title': 'Launch readiness',
            'details': 'Delivery completed with minor open items.',
            'status': 'Healthy',
          },
          {
            'title': 'Stakeholder alignment',
            'details': 'Weekly cadence in place with sponsors and operations.',
            'status': 'Stable',
          },
        ];
      case 'highlights':
        return [
          {
            'title': 'Key milestone delivered',
            'details': 'Core platform capability delivered on schedule.',
            'status': '',
          },
          {
            'title': 'Strong cross-team collaboration',
            'details': 'Product and engineering aligned on release criteria.',
            'status': '',
          },
        ];
      case 'delivery_risks':
        return [
          {
            'title': 'Support coverage risk',
            'details': 'Ops coverage still staffing for night shifts.',
            'status': 'At risk',
          },
          {
            'title': 'Vendor dependency',
            'details': 'Third-party SLA review pending.',
            'status': 'In review',
          },
        ];
      case 'next_90_days':
        return [
          {
            'title': 'Post-launch optimization',
            'details': 'Stabilize latency and monitor user feedback.',
            'status': 'Planned',
          },
          {
            'title': 'Expand reporting',
            'details': 'Deliver weekly performance dashboards to sponsors.',
            'status': 'Planned',
          },
        ];
      case 'vendor_snapshot':
        return [
          {
            'title': 'Active vendor close-out items',
            'details': 'Finalize remaining invoices and service confirmations.',
            'status': 'In progress',
          },
          {
            'title': 'Access revocation status',
            'details': 'Remove unused vendor credentials by close-out date.',
            'status': 'Scheduled',
          },
        ];
      case 'guided_steps':
        return [
          {
            'title': 'Confirm deliverables received',
            'details': 'Validate all contract deliverables are archived.',
            'status': 'In review',
          },
          {
            'title': 'Close vendor accounts',
            'details': 'Execute termination checklist with procurement.',
            'status': 'Planned',
          },
        ];
      case 'vendors_attention':
        return [
          {
            'title': 'Payment reconciliation',
            'details': 'Resolve outstanding invoice with key vendor.',
            'status': 'At risk',
          },
          {
            'title': 'Compliance documentation',
            'details': 'Collect final compliance certificates.',
            'status': 'Pending',
          },
        ];
      case 'access_signoff':
        return [
          {
            'title': 'Ops sign-off',
            'details': 'Confirm access removal and handover completion.',
            'status': 'Pending',
          },
          {
            'title': 'Security approval',
            'details': 'Verify all vendor access audit logs are archived.',
            'status': 'In review',
          },
        ];
      case 'schedule_gaps':
        return [
          {
            'title': 'Milestone slip on core integration',
            'details':
                'Integration testing pushed by 1 sprint due to dependency delays.',
            'status': 'Investigate',
          },
          {
            'title': 'UAT readiness variance',
            'details': 'User acceptance testing started later than planned.',
            'status': 'In progress',
          },
        ];
      case 'cost_gaps':
        return [
          {
            'title': 'Cloud spend over baseline',
            'details': 'Compute usage exceeded forecast during load testing.',
            'status': 'At risk',
          },
          {
            'title': 'Vendor cost variance',
            'details': 'Support contract extension added unplanned cost.',
            'status': 'Review',
          },
        ];
      case 'scope_gaps':
        return [
          {
            'title': 'Deferred analytics dashboard',
            'details': 'Advanced reporting moved to post-launch release.',
            'status': 'Deferred',
          },
          {
            'title': 'Quality remediation',
            'details': 'Additional QA cycles added for critical workflows.',
            'status': 'In progress',
          },
        ];
      case 'benefits_causes':
        return [
          {
            'title': 'Efficiency gains behind forecast',
            'details': 'Operational throughput improved but below target.',
            'status': 'Monitor',
          },
          {
            'title': 'Root cause: integration rework',
            'details': 'Rework required due to upstream API changes.',
            'status': 'Identified',
          },
        ];
      case 'team_ramp_down':
        return [
          {
            'title': 'Release core engineers',
            'details': 'Transition ownership to ops team after stabilization.',
            'status': 'Planned',
          },
          {
            'title': 'Reassign QA support',
            'details': 'Move QA resources to next program after close-out.',
            'status': 'Scheduled',
          },
        ];
      case 'knowledge_transfer':
        return [
          {
            'title': 'Ops runbook walkthrough',
            'details': 'Finalize handover session with support leads.',
            'status': 'Planned',
          },
          {
            'title': 'Architecture deep-dive',
            'details': 'Record system overview for future maintenance.',
            'status': 'Scheduled',
          },
        ];
      case 'vendor_offboarding':
        return [
          {
            'title': 'Revoke vendor access',
            'details': 'Remove all third-party credentials post-contract.',
            'status': 'Pending',
          },
          {
            'title': 'Close vendor obligations',
            'details': 'Confirm deliverables and archive documentation.',
            'status': 'In progress',
          },
        ];
      case 'communications':
        return [
          {
            'title': 'Stakeholder update',
            'details': 'Communicate close-out timeline to business owners.',
            'status': '',
          },
          {
            'title': 'Support FAQ refresh',
            'details': 'Publish knowledge base updates for impacted users.',
            'status': '',
          },
        ];
      case 'impact_assessment':
        return [
          {
            'title': 'Schedule',
            'details':
                'Critical path recovery improved after scope reprioritization.',
            'status': 'Medium | Improving',
          },
          {
            'title': 'Cost',
            'details': 'Budget variance stabilized after vendor renegotiation.',
            'status': 'Low | Stable',
          },
          {
            'title': 'Quality',
            'details': 'Regression suite still pending final validation.',
            'status': 'Medium | Needs attention',
          },
        ];
      case 'reconciliation_workflow':
        return [
          {
            'title': 'Discovery',
            'details': 'Gap interviews and system scans captured.',
            'status': 'Complete',
          },
          {
            'title': 'Mitigation backlog',
            'details': 'Actions scheduled with delivery squads.',
            'status': 'In progress',
          },
          {
            'title': 'Validation & sign-off',
            'details': 'Stakeholder review targeted this week.',
            'status': 'Upcoming',
          },
        ];
      case 'lessons_learned':
        return [
          {
            'title': 'Align ops readiness early to avoid late scope drift.',
            'details': '',
            'status': '',
          },
          {
            'title': 'Validate vendor dependencies against launch timelines.',
            'details': '',
            'status': '',
          },
          {
            'title': 'Track adoption metrics weekly for early signals.',
            'details': '',
            'status': '',
          },
        ];
      case 'close_out_checklist':
        return [
          {
            'title': 'Finalize close-out documentation',
            'details': 'Compile acceptance notes, metrics, and closure report.',
            'status': 'In progress',
          },
          {
            'title': 'Confirm stakeholder sign-off',
            'details': 'Collect final approvals from sponsors and operations.',
            'status': 'Pending',
          },
        ];
      case 'approvals_signoff':
        return [
          {
            'title': 'Executive sponsor approval',
            'details': 'Sign-off on project outcomes and benefits.',
            'status': 'Pending',
          },
          {
            'title': 'Operations acceptance',
            'details': 'Ops lead confirms handover readiness.',
            'status': 'In review',
          },
        ];
      case 'archive_access':
        return [
          {
            'title': 'Archive project artifacts',
            'details': 'Store final deliverables and contracts in repository.',
            'status': '',
          },
          {
            'title': 'Revoke elevated access',
            'details': 'Remove temporary permissions and vendor credentials.',
            'status': '',
          },
        ];
      case 'transition_steps':
        return [
          {
            'title': 'Finalize production readiness checklist',
            'details': 'Confirm monitoring, alerting, and rollback plans.',
            'status': 'In review',
          },
          {
            'title': 'Run handover walkthrough',
            'details': 'Ops team reviews runbooks and escalation paths.',
            'status': 'Scheduled',
          },
        ];
      case 'handover_artifacts':
        return [
          {
            'title': 'Operational runbook',
            'details': 'Document SOPs, on-call playbooks, and recovery steps.',
            'status': '',
          },
          {
            'title': 'Service dashboard',
            'details': 'Share KPIs and health monitoring links.',
            'status': '',
          },
        ];
      case 'signoffs':
        return [
          {
            'title': 'Ops lead approval',
            'details': 'Ops confirms readiness for production handover.',
            'status': 'Pending',
          },
          {
            'title': 'Security sign-off',
            'details': 'Security review completed for production release.',
            'status': 'In review',
          },
        ];
      case 'closeout_summary':
        return [
          {
            'title': 'Close-out summary metric',
            'details': 'Track key close-out KPIs and status.',
            'status': 'On track',
          },
          {
            'title': 'Final deliverables status',
            'details': 'All required outputs verified and archived.',
            'status': 'Complete',
          },
        ];
      case 'closeout_steps':
        return [
          {
            'title': 'Complete contract checklist',
            'details': 'Verify obligations and handover evidence.',
            'status': 'In progress',
          },
          {
            'title': 'Confirm invoice reconciliation',
            'details': 'Finance validates final billing with vendors.',
            'status': 'Pending',
          },
        ];
      case 'contracts_attention':
        return [
          {
            'title': 'Outstanding vendor deliverable',
            'details': 'Awaiting final documentation from vendor.',
            'status': 'At risk',
          },
          {
            'title': 'SLA reconciliation',
            'details': 'Confirm SLA credits before closure.',
            'status': 'In review',
          },
        ];
      case 'closeout_signoff':
        return [
          {
            'title': 'Finance approval',
            'details': 'Finance validates final spend and closes ledger.',
            'status': 'Pending',
          },
          {
            'title': 'Compliance approval',
            'details': 'Compliance confirms regulatory close-out steps.',
            'status': 'Planned',
          },
        ];
      case 'closure_summary':
        return [
          {
            'title': 'Delivery status',
            'details': 'All launch deliverables completed.',
            'status': 'Complete',
          },
          {
            'title': 'Post-launch metrics',
            'details': 'Stability and adoption tracked for 2 weeks.',
            'status': 'Monitoring',
          },
        ];
      case 'scope_acceptance':
        return [
          {
            'title': 'Scope acceptance',
            'details': 'Stakeholders accept final scope outcomes.',
            'status': 'Approved',
          },
          {
            'title': 'Open scope items',
            'details': 'Minor backlog moved to next release.',
            'status': 'Deferred',
          },
        ];
      case 'risks_followups':
        return [
          {
            'title': 'Operational follow-up',
            'details': 'Monitor incidents during hypercare window.',
            'status': 'Planned',
          },
          {
            'title': 'Support readiness',
            'details': 'Ensure 24/7 coverage for first month.',
            'status': 'In progress',
          },
        ];
      case 'final_checklist':
        return [
          {
            'title': 'Archive project artifacts',
            'details': 'Ensure all documentation is stored.',
            'status': 'Pending',
          },
          {
            'title': 'Finalize stakeholder report',
            'details': 'Send closure summary to sponsors.',
            'status': 'Planned',
          },
        ];
      case 'contract_quotes':
        return [
          {
            'title': 'Build-ready engineering vendor',
            'details':
                'Structural engineering and inspection coverage for $assetName.',
            'status': '\$120,000 - \$150,000',
          },
          {
            'title': 'Systems integration partner',
            'details': 'Integration of platform services and delivery tooling.',
            'status': '\$60,000 - \$80,000',
          },
        ];
      case 'contract_overview':
        return [
          {
            'title': 'Published Date',
            'details': 'Aug 12, 2025',
            'status': '',
          },
          {
            'title': 'Submission Deadline',
            'details': 'Sep 5, 2025 (5:00 PM)',
            'status': 'Deadline',
          },
        ];
      case 'contract_description':
        return [
          {
            'title': 'Project Overview',
            'details':
                'Define vendor responsibilities, delivery timelines, and acceptance criteria tied to $assetName.',
            'status': '',
          },
        ];
      case 'scope_items':
        return [
          {
            'title': 'Define contracting scope and deliverables.',
            'details': '',
            'status': '',
          },
          {
            'title': 'Confirm service levels and escalation paths.',
            'details': '',
            'status': '',
          },
        ];
      case 'contract_documents':
        return [
          {
            'title': 'Scope of Work',
            'details': 'PDF, 2.4 MB',
            'status': 'PDF',
          },
          {
            'title': 'Technical Specifications',
            'details': 'DOCX, 1.1 MB',
            'status': 'DOCX',
          },
        ];
      case 'bidder_information':
        return [
          {
            'title': 'Eligibility',
            'details':
                'Vendors must meet compliance and certification requirements.',
            'status': '',
          },
          {
            'title': 'Evaluation Criteria',
            'details':
                'Weighted scoring across technical fit, delivery plan, and cost.',
            'status': '',
          },
        ];
      case 'contact_details':
        return [
          {
            'title': 'Procurement Lead',
            'details': 'Procurement Officer',
            'status': 'procurement@company.com',
          },
        ];
      case 'prebid_meeting':
        return [
          {
            'title': 'Sep 1, 2025',
            'details': '10:00 AM',
            'status': 'Virtual meeting link to follow.',
          },
        ];
      case 'contract_timeline':
        return [
          {
            'title': 'Award approvals',
            'details': 'Finalize vendor approvals and contract signatures.',
            'status': 'In progress',
          },
          {
            'title': 'Delivery readiness',
            'details': 'Ensure contract deliverables are on track.',
            'status': 'Planned',
          },
        ];
      case 'contract_status_summary':
        return [
          {
            'title': 'Average Bid Value',
            'details': '\$1,250,000',
            'status': '',
          },
          {
            'title': 'Total Contractors',
            'details': '4',
            'status': '',
          },
          {
            'title': 'Milestone Progress',
            'details': '2/4 Complete',
            'status': '',
          },
          {
            'title': 'Status',
            'details': 'Bid Evaluation',
            'status': '',
          },
        ];
      case 'contract_recent_activity':
        return [
          {
            'title': 'Vendor shortlist updated',
            'details': 'Aug 21, 2025',
            'status': '',
          },
          {
            'title': 'Bid clarifications requested',
            'details': 'Aug 18, 2025',
            'status': '',
          },
        ];
      case 'contract_milestones':
        return [
          {
            'title': 'Contract awards complete',
            'details': 'Sep 15, 2025',
            'status': 'Complete',
          },
          {
            'title': 'Equipment delivery',
            'details': 'Oct 10, 2025',
            'status': 'In progress',
          },
        ];
      case 'contract_execution_steps':
        return [
          {
            'title': 'Request for Quote (RFQ)',
            'details': 'Distribute RFQ and collect vendor responses.',
            'status': 'Not scheduled',
          },
          {
            'title': 'Review Quotes',
            'details': 'Evaluate proposals and document scoring.',
            'status': 'Pending',
          },
        ];
      case 'contractors_directory':
        return [
          {
            'title': 'BuildTech Engineering',
            'details': 'General Contractor | New York, NY | \$1,250,000',
            'status': 'Under Review',
          },
          {
            'title': 'MetroStructural Solutions',
            'details': 'Structural Engineering | Chicago, IL | \$1,180,000',
            'status': 'Bid Submitted',
          },
        ];
      case 'summary_rows':
        return [
          {
            'title': 'Core services contract',
            'details':
                'Primary vendor | Bidding / Lump Sum | \$750,000 | 120 days',
            'status': 'In progress',
          },
          {
            'title': 'Operations support',
            'details':
                'Support partner | Reimbursable / Monthly | \$180,000 | 90 days',
            'status': 'Planned',
          },
        ];
      case 'budget_impact':
        return [
          {
            'title': 'Original Budget',
            'details': '\$2,000,000',
            'status': '',
          },
          {
            'title': 'Current Estimate',
            'details': '\$1,250,000',
            'status': '',
          },
          {
            'title': 'Variance',
            'details': '\$750,000 (under)',
            'status': '',
          },
        ];
      case 'schedule_impact':
        return [
          {
            'title': 'Project Start',
            'details': 'Sep 1, 2025',
            'status': '',
          },
          {
            'title': 'Contracting Finish',
            'details': 'Dec 15, 2025',
            'status': '',
          },
          {
            'title': 'Total Duration',
            'details': '105 days',
            'status': '',
          },
        ];
      case 'warranty_support':
        return [
          {
            'title': 'Core services contract',
            'details': '12 months | Standard support | support@vendor.com',
            'status': 'View',
          },
        ];
      case 'summary_highlights':
        return [
          {
            'title': 'Contract Summary',
            'details':
                '3 Contracts Planned\n1 Contract In-Progress\n0 Contracts Completed',
            'status': '',
          },
          {
            'title': 'Budget Impact',
            'details':
                '\$1.25M Total Contract Value\nBudget tracking ongoing\nVariance pending',
            'status': '',
          },
        ];
      default:
        return [
          {
            'title': 'Launch action item',
            'details': 'Add details for $assetName.',
            'status': 'Planned',
          },
        ];
    }
  }

  List<SsherEntry> _fallbackSsherEntries(String context, int itemsPerCategory) {
    final projectName = _extractProjectName(context);
    final assetName = projectName.isEmpty ? 'the project' : projectName;
    final templates = <String, List<Map<String, String>>>{
      'safety': [
        {
          'department': 'Operations',
          'teamMember': 'Safety Lead',
          'concern':
              'Inconsistent PPE usage during ${assetName.toLowerCase()} rollout activities.',
          'riskLevel': 'High',
          'mitigation':
              'Enforce PPE checklists and daily toolbox talks across shifts.',
          'estimatedCost': '3500',
          'costCurrency': 'USD',
          'costFrequency': 'One-time',
          'costUnit': 'lump sum',
        },
        {
          'department': 'Facilities',
          'teamMember': 'Site Supervisor',
          'concern':
              'Limited emergency egress signage in newly activated zones.',
          'riskLevel': 'Medium',
          'mitigation':
              'Install signage and conduct evacuation drills before go-live.',
          'estimatedCost': '1800',
          'costCurrency': 'USD',
          'costFrequency': 'One-time',
          'costUnit': 'lump sum',
        },
      ],
      'security': [
        {
          'department': 'IT Security',
          'teamMember': 'Security Analyst',
          'concern':
              'Incomplete access reviews for vendors supporting ${assetName.toLowerCase()}.',
          'riskLevel': 'High',
          'mitigation':
              'Complete quarterly access audits and enforce least-privilege roles.',
          'estimatedCost': '6000',
          'costCurrency': 'USD',
          'costFrequency': 'Annual',
          'costUnit': 'per year',
        },
        {
          'department': 'Facilities',
          'teamMember': 'Security Manager',
          'concern': 'Badge access not synchronized with contractor schedules.',
          'riskLevel': 'Medium',
          'mitigation':
              'Align badge provisioning with approved rosters and auto-expire access.',
          'estimatedCost': '2200',
          'costCurrency': 'USD',
          'costFrequency': 'One-time',
          'costUnit': 'lump sum',
        },
      ],
      'health': [
        {
          'department': 'HR',
          'teamMember': 'Wellness Coordinator',
          'concern':
              'Shift fatigue risk during the ${assetName.toLowerCase()} launch window.',
          'riskLevel': 'Medium',
          'mitigation': 'Introduce rotation plans and mandatory rest breaks.',
          'estimatedCost': '1200',
          'costCurrency': 'USD',
          'costFrequency': 'Monthly',
          'costUnit': 'per month',
        },
        {
          'department': 'Operations',
          'teamMember': 'Ops Manager',
          'concern': 'Ergonomic strain reported at staging workstations.',
          'riskLevel': 'Low',
          'mitigation':
              'Provide adjustable workstations and ergonomics training.',
          'estimatedCost': '2800',
          'costCurrency': 'USD',
          'costFrequency': 'One-time',
          'costUnit': 'lump sum',
        },
      ],
      'environment': [
        {
          'department': 'Sustainability',
          'teamMember': 'Environmental Lead',
          'concern':
              'Waste segregation compliance gaps during ${assetName.toLowerCase()} prep.',
          'riskLevel': 'Medium',
          'mitigation':
              'Deploy labeled bins and weekly compliance inspections.',
          'estimatedCost': '1500',
          'costCurrency': 'USD',
          'costFrequency': 'One-time',
          'costUnit': 'lump sum',
        },
        {
          'department': 'Operations',
          'teamMember': 'Facilities Lead',
          'concern': 'Energy spikes expected from temporary equipment usage.',
          'riskLevel': 'Low',
          'mitigation':
              'Schedule equipment use off-peak and track energy KPIs.',
          'estimatedCost': '900',
          'costCurrency': 'USD',
          'costFrequency': 'Monthly',
          'costUnit': 'per month',
        },
      ],
      'regulatory': [
        {
          'department': 'Compliance',
          'teamMember': 'Compliance Officer',
          'concern':
              'Incomplete documentation for regulatory reporting milestones.',
          'riskLevel': 'High',
          'mitigation':
              'Complete audit trail and align reporting calendar with regulators.',
          'estimatedCost': '4500',
          'costCurrency': 'USD',
          'costFrequency': 'Quarterly',
          'costUnit': 'per quarter',
        },
        {
          'department': 'Legal',
          'teamMember': 'Regulatory Counsel',
          'concern':
              'Pending review of new policy changes impacting ${assetName.toLowerCase()}.',
          'riskLevel': 'Medium',
          'mitigation':
              'Validate policy updates and secure sign-off before launch.',
          'estimatedCost': '3000',
          'costCurrency': 'USD',
          'costFrequency': 'One-time',
          'costUnit': 'lump sum',
        },
      ],
    };

    final entries = <SsherEntry>[];
    for (final entry in templates.entries) {
      final category = entry.key;
      for (final item in entry.value.take(itemsPerCategory)) {
        entries.add(SsherEntry(
          category: category,
          department: item['department'] ?? '',
          teamMember: item['teamMember'] ?? 'Owner',
          concern: item['concern'] ?? '',
          riskLevel: _normalizeRiskLevel(item['riskLevel'] ?? ''),
          mitigation: item['mitigation'] ?? '',
          estimatedCost: item['estimatedCost'] ?? '5000',
          costCurrency: item['costCurrency'] ?? 'USD',
          costFrequency: item['costFrequency'] ?? 'One-time',
          costUnit: item['costUnit'] ?? 'lump sum',
        ));
      }
    }
    return entries;
  }

  String _normalizeSsherCategory(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('safety')) return 'safety';
    if (normalized.contains('security')) return 'security';
    if (normalized.contains('health')) return 'health';
    if (normalized.contains('environment')) return 'environment';
    if (normalized.contains('regulatory')) return 'regulatory';
    return '';
  }

  String _normalizeRiskLevel(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.startsWith('high')) return 'High';
    if (normalized.startsWith('low')) return 'Low';
    return 'Medium';
  }

  String _ssherCategoryPlanPrompt(String context, String category) {
    final escaped = _escape(context);
    final categoryDescriptions = {
      'safety':
          'physical safety hazards on the project site, PPE, emergency response, incident reporting, safe work practices, equipment safety',
      'security':
          'physical and information security threats, access control, asset protection, personnel security, cybersecurity, vendor security',
      'health':
          'occupational health, mental wellbeing, ergonomics, fatigue management, occupational illness prevention, health surveillance',
      'environment':
          'environmental impact, waste management, emissions, energy efficiency, water use, biodiversity, UN Sustainable Development Goals alignment',
      'regulatory':
          'applicable laws, permits, licenses, regulatory reporting, compliance obligations, audits, statutory deadlines',
    };
    final focus = categoryDescriptions[category] ?? category;
    final titleCase = category[0].toUpperCase() + category.substring(1);
    return '''
Using the project inputs below, write a concise $titleCase Plan (90-150 words) that addresses $focus for this project. The plan MUST be customized to the project's type, location, and applicable regulatory environment. Reference specific project details (project name, location, scope elements) where possible. Be concise, no fluff, no preamble.

Return ONLY valid JSON with this exact structure:
{
  "plan": "Concise $titleCase Plan text goes here."
}

Project context:
"""
$escaped
"""
''';
  }

  String _fallbackSsherCategoryPlan(String context, String category) {
    final projectName = _extractProjectName(context);
    final assetName = projectName.isEmpty ? 'this project' : projectName;
    final titleCase = category[0].toUpperCase() + category.substring(1);

    final templates = {
      'safety':
          '$titleCase Plan for $assetName: All site personnel must complete pre-mobilization safety inductions before access. A site-specific HSE plan will govern PPE requirements, permit-to-work procedures, and emergency response. Daily toolbox talks will reinforce hazards of the day. Incident reporting follows a 24-hour notification protocol with root-cause analysis for any lost-time event. High-risk activities (working at heights, hot work, confined space) require dedicated JSAs and standby rescuers. Safety performance is reviewed weekly by the project manager and tracked against an TRIR target of zero.',
      'security':
          '$titleCase Plan for $assetName: Physical site access is restricted to badged personnel and pre-approved visitors; all entry points are logged. Cyber assets follow least-privilege access with quarterly reviews and MFA enforcement. Vendor credentials are time-boxed and revoked on demobilization. Asset protection includes CCTV coverage at critical zones and secure storage for high-value equipment. Personnel security includes background screening for sensitive roles. Security incidents are escalated within 1 hour to the project manager and corporate security team. A weekly security posture review keeps access rosters aligned with active personnel.',
      'health':
          '$titleCase Plan for $assetName: Occupational health surveillance covers pre-deployment medicals, periodic screenings, and ergonomic assessments for at-risk roles. Mental wellbeing support includes EAP access and fatigue management protocols that cap consecutive working hours. Heat/cold stress controls adapt to local climate. Health KPIs (lost-time illness, medical treatment cases) are reported monthly. Site hygiene standards govern sanitation, potable water, and rest facilities. A designated Health Officer coordinates with local medical providers and ensures emergency medical response capability on site during active work.',
      'environment':
          '$titleCase Plan for $assetName: An Environmental Management Plan aligned with ISO 14001 governs waste segregation, hazardous material handling, and spill response. Energy and water use are tracked monthly against reduction targets. Applicable UN Sustainable Development Goals (SDGs 6, 7, 9, 11, 12, 13) are integrated into procurement and operations decisions. Biodiversity impacts are assessed for any greenfield work. Emissions are tracked and reported per local regulatory requirements. Environmental incidents trigger immediate containment and a 48-hour written report. A quarterly sustainability review tracks progress against SDG-aligned KPIs.',
      'regulatory':
          '$titleCase Plan for $assetName: A regulatory compliance matrix lists every applicable law, permit, and license for the project jurisdiction, with owners and renewal dates. Permits are obtained before any regulated activity begins. Statutory reporting (monthly safety, environmental, employment) is submitted on calendar cadence. Internal audits are conducted quarterly and external audits annually. Any regulatory change is reviewed within 10 business days and reflected in the compliance matrix. Non-conformances trigger corrective action plans with target closure dates. The Compliance Officer reports monthly status to the project sponsor.',
    };

    return templates[category] ??
        '$titleCase Plan for $assetName: tailored to project scope, location, and applicable regulatory requirements.';
  }

  String _ssherSdgPrompt(String context) {
    final escaped = _escape(context);
    return '''
Analyze the project context below and identify the UN Sustainable Development Goals (SDGs 1-17) that are most applicable to this project. For each applicable SDG, provide a brief rationale tied to specific aspects of the project scope, location, or impact areas.

Return ONLY valid JSON with this exact structure:
{
  "sdgs": [
    {
      "goal": "SDG 6",
      "title": "Clean Water and Sanitation",
      "rationale": "Brief, specific rationale tied to the project context."
    }
  ]
}

Project context:
"""
$escaped
"""
''';
  }

  List<Map<String, String>> _fallbackSdgRecommendations(String context) {
    final projectName = _extractProjectName(context);
    final assetName = projectName.isEmpty ? 'This project' : projectName;
    return [
      {
        'goal': 'SDG 8',
        'title': 'Decent Work and Economic Growth',
        'rationale':
            '$assetName supports decent work through safe working conditions, fair labor practices, and local economic participation.',
      },
      {
        'goal': 'SDG 9',
        'title': 'Industry, Innovation and Infrastructure',
        'rationale':
            '$assetName advances resilient infrastructure and sustainable industrialization through modern delivery practices.',
      },
      {
        'goal': 'SDG 12',
        'title': 'Responsible Consumption and Production',
        'rationale':
            'Waste segregation, energy tracking, and sustainable procurement for $assetName align with responsible production goals.',
      },
      {
        'goal': 'SDG 13',
        'title': 'Climate Action',
        'rationale':
            '$assetName tracks emissions and integrates climate considerations into environmental planning.',
      },
    ];
  }

  Map<String, dynamic>? _decodeJsonSafely(String content) {
    final cleaned = _extractJson(content);
    if (cleaned.isEmpty) return null;
    try {
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  String _technologiesPrompt(List<AiSolutionItem> solutions, String notes) {
    // Handle empty solutions by using project context from notes
    String list = '';
    if (solutions.isNotEmpty) {
      list = solutions
          .map((s) =>
              '{"title": "${_escape(s.title)}", "description": "${_escape(s.description)}"}')
          .join(',');
    } else if (notes.isNotEmpty) {
      // If no solutions but we have project context, create a placeholder
      list = '{"title": "Project", "description": "${_escape(notes)}"}';
    }

    return '''
For each solution below, list 3-6 core technologies/services/frameworks that would be SPECIFICALLY required to implement that particular solution.

IMPORTANT: Each solution must have DIFFERENT and UNIQUE technology recommendations tailored to its specific title, description, and requirements. Do NOT repeat the same generic technologies across all solutions. Consider:
- The nature of the solution (cloud-native vs on-premise, mobile vs web, etc.)
- Industry-specific requirements implied by the solution
- Scale and complexity differences between solutions
- Different architectural patterns suitable for each solution
IMPORTANT: Be detailed and specific. Do not use "etc.", "and similar", or vague groupings. State each item explicitly.

Return ONLY valid JSON with this exact structure:
{
  "technologies": [
    {"solution": "Solution Name", "items": ["Tech 1", "Tech 2", "Tech 3"]}
  ]
}

${list.isNotEmpty ? 'Solutions: [$list]' : 'Project Context: $notes'}

Context notes (optional): $notes
''';
  }

  // FEP RISKS GENERATION - Generate risks with all fields (Title, Category, Probability, Impact)
  Future<List<Map<String, String>>> generateFepRisks(
    String context, {
    int minCount = 5,
  }) async {
    if (context.trim().isEmpty) return [];
    if (!OpenAiConfig.isConfigured) throw const OpenAiNotConfiguredException();
    final count = minCount < 3 ? 3 : minCount;

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();
    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': 0.6,
      'max_completion_tokens': 2000,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'risk analyst generating realistic front-end planning risks from preferred-solution context',
            strictJson: true,
            extraRules:
                'Use project type and location cues from context, including regulatory, permitting, weather, labor, utilities, site, operational, service, or technology constraints as relevant. For each risk, provide title, category, probability, impact, mitigation strategy, discipline, and project role. Avoid generic filler and duplicate risks.',
          )
        },
        {
          'role': 'user',
          'content':
              '''Generate at least $count project risks based on this context:

$context

Return JSON in this format:
{
  "risks": [
    {
      "title": "Risk title",
      "description": "One-sentence risk description",
      "category": "Technical/Financial/Operational/Schedule/Resource",
      "probability": "Low/Medium/High",
      "impact": "Low/Medium/High",
      "mitigationStrategy": "Concise mitigation action",
      "discipline": "Owning discipline",
      "projectRole": "Responsible project role"
    }
  ]
}'''
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;
      final risks = (parsed['risks'] as List? ?? [])
          .map((e) {
            final item = e as Map<String, dynamic>;
            return {
              'title': (item['title'] ?? '').toString().trim(),
              'description': (item['description'] ?? '').toString().trim(),
              'category': (item['category'] ?? 'Technical').toString().trim(),
              'probability':
                  (item['probability'] ?? 'Medium').toString().trim(),
              'impact': (item['impact'] ?? 'Medium').toString().trim(),
              'mitigationStrategy':
                  (item['mitigationStrategy'] ?? item['mitigation'] ?? '')
                      .toString()
                      .trim(),
              'discipline':
                  (item['discipline'] ?? 'Risk Management').toString().trim(),
              'projectRole': (item['projectRole'] ??
                      item['role'] ??
                      item['ownerRole'] ??
                      'Risk Owner')
                  .toString()
                  .trim(),
            };
          })
          .where((r) => r['title']!.isNotEmpty)
          .toList();
      return risks;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<WorkItem>> generateWbsStructure({
    required String projectName,
    required String projectObjective,
    required String dimension,
    String dimensionDescription = '',
    List<ProjectGoal>? goals,
    String overallFramework = '',
    String contextNotes = '',
  }) async {
    if (!OpenAiConfig.isConfigured) return [];

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();
    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': 0.5,
      'max_completion_tokens': 1500,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a project management expert. Generate a hierarchical Work Breakdown Structure (WBS) in strict JSON format. Each item should have a title, description, and optionally children and dependencies.'
        },
        {
          'role': 'user',
          'content': _wbsPrompt(
            projectName: projectName,
            projectObjective: projectObjective,
            dimension: dimension,
            dimensionDescription: dimensionDescription,
            goals: goals,
            overallFramework: overallFramework,
            contextNotes: contextNotes,
          )
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 22));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;
      final List rawWbs = parsed['wbs'] as List? ?? [];

      final items = rawWbs
          .map((e) => WorkItem.fromJson(e as Map<String, dynamic>))
          .toList();
      _wireUpWbsTree(items);
      return items;
    } catch (e) {
      debugPrint('Error generating WBS: $e');
      return [];
    }
  }

  void _wireUpWbsTree(List<WorkItem> items, {String parentId = ''}) {
    for (var item in items) {
      item.parentId = parentId;
      if (item.children.isNotEmpty) {
        _wireUpWbsTree(item.children, parentId: item.id);
      }
    }
  }

  String _wbsPrompt({
    required String projectName,
    required String projectObjective,
    required String dimension,
    String dimensionDescription = '',
    List<ProjectGoal>? goals,
    String overallFramework = '',
    required String contextNotes,
  }) {
    String stripPrefix(String name) {
      return name.replaceFirst(RegExp(r'^[GS]\d+(?:\.\d+)*\s*[:\-]\s*'), '');
    }

    final goalsText = goals != null && goals.isNotEmpty
        ? "\nProject Goals (IMPORTANT: Use these as Level 1 items):\n${goals.map((g) {
            final framework = (g.framework ?? '').trim();
            final fw = framework.isNotEmpty ? ' | Framework: $framework' : '';
            return "- ${stripPrefix(g.name)}: ${g.description}$fw";
          }).join("\n")}"
        : "";

    final dimensionContext = dimensionDescription.isNotEmpty
        ? "\nDimension Guidance: $dimensionDescription"
        : "";

    final frameworkGuide = overallFramework.isEmpty
        ? ''
        : (overallFramework == 'Hybrid'
            ? '\nFramework Guidance: This is a HYBRID project. Each Level 1 item MUST include a "framework" value of either "Agile" or "Waterfall". If a Project Goal lists a framework, match it. Otherwise infer the best fit (Agile for iterative/software work, Waterfall for linear/physical work) and keep it consistent across that item and its children.'
            : '\nFramework Guidance: This is a ${overallFramework.toUpperCase()} project. Every WBS item MUST include "framework": "$overallFramework".');

    return '''
Generate a Work Breakdown Structure (WBS) for:
Project: $projectName
Objective: $projectObjective$goalsText$frameworkGuide
Segmentation Dimension: $dimension$dimensionContext

CRITICAL Requirements:
1. Level 1 items MUST be named after the Project Goals listed above (if goals are provided).
   - Names must reflect the selected segmentation dimension ("$dimension").
   - Use the dimension guidance to shape item names and descriptions (avoid generic activities).
2. Level 2 items are specific milestones/deliverables for each goal - these will populate the project milestones.
3. Each item MUST have a "title" and "description".
4. Use "children" for sub-items.
5. Use "dependencies" as a list of titles of sibling items that must be completed first.
6. Keep the structure 2-5 levels deep (supports up to Level 5 for complex projects).
7. Prefix titles with WBS numbering using the Segment-based scheme:
   - Level 1: "S1: Goal Title", "S2: Goal Title" in order
   - Level 2: "S1.1: Deliverable", "S1.2: Deliverable"
   - Level 3: "S1.1.1: Sub-deliverable"
   - Level 4: "S1.1.1.1: Work package component"
   - Level 5: "S1.1.1.1.1: Task element"
8. Include "framework" in each item (Waterfall or Agile only).

Return strict JSON only in this format:
{
  "wbs": [
    {
      "title": "Goal 1 Name Here",
      "description": "Goal 1 description",
      "framework": "Waterfall",
      "children": [
        {
          "title": "Milestone 1.1",
          "description": "First deliverable for this goal"
        },
        {
          "title": "Milestone 1.2",
          "description": "Second deliverable for this goal",
          "dependencies": ["Milestone 1.1"]
        }
      ]
    }
  ]
}

Additional Context: $contextNotes
''';
  }

  Future<List<ScheduleActivity>> generateScheduleActivities({
    required String context,
    required List<Map<String, String>> wbsItems,
    int maxTokens = 900,
    double temperature = 0.4,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty || wbsItems.isEmpty) {
      return _fallbackScheduleActivities(wbsItems);
    }

    if (!OpenAiConfig.isConfigured) {
      return _fallbackScheduleActivities(wbsItems);
    }

    final projectScale = _detectProjectScale(trimmedContext);
    final durationGuidance = _scaleDurationGuidance(projectScale);

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a senior scheduler. Return only JSON and obey the required schema.'
        },
        {
          'role': 'user',
          'content': _scheduleActivitiesPrompt(trimmedContext, wbsItems, durationGuidance),
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 14));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content = OpenAiConfig.extractContent(data);
      if (content.isNotEmpty) {
        final parsed = _decodeJsonSafely(content);
        if (parsed != null) {
          final list = parsed['activities'];
          if (list is List) {
            return list
                .whereType<Map>()
                .map((raw) => ScheduleActivity.fromJson(
                    raw.map((k, v) => MapEntry(k.toString(), v))))
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('generateScheduleActivities failed: $e');
    }

    return _fallbackScheduleActivities(wbsItems);
  }

  String _scheduleActivitiesPrompt(
      String context, List<Map<String, String>> wbsItems, String durationGuidance) {
    final escaped = _escape(context);
    final itemsJson = jsonEncode(wbsItems);
    return '''
Using the project context and the WBS items, generate a realistic schedule activity list.

Rules:
- Use the provided WBS item "id" values when referencing dependencies.
- Include all WBS items (one activity per item).
- Duration is in working days (integer).
- If something is a milestone, set durationDays to 0 and isMilestone true.
- Provide logical predecessorIds for sequencing.

$durationGuidance

Return ONLY valid JSON with this exact structure:
{
  "activities": [
    {
      "wbsId": "wbs-id",
      "title": "Activity title",
      "durationDays": 5,
      "predecessorIds": ["wbs-id-1"],
      "isMilestone": false
    }
  ]
}

WBS items (JSON):
$itemsJson

Project Context:
"""
$escaped
"""
''';
  }

  List<ScheduleActivity> _fallbackScheduleActivities(
      List<Map<String, String>> wbsItems) {
    return wbsItems
        .map((item) => ScheduleActivity(
              wbsId: item['id'] ?? '',
              title: item['title'] ?? '',
              durationDays: 5,
              predecessorIds: const [],
              isMilestone: false,
            ))
        .toList();
  }

  String _escape(String v) => v.replaceAll('"', '\\"').replaceAll('\n', ' ');

  String _excerpt(String value, int maxChars) {
    if (value.length <= maxChars) return value;
    return '${value.substring(0, maxChars - 3)}...';
  }

  // PROCUREMENT - VENDORS
  Future<Map<String, dynamic>> generateVendorSuggestion({
    required String projectName,
    required String solutionTitle,
    required String category,
    String contextNotes = '',
  }) async {
    if (!OpenAiConfig.isConfigured) {
      return _fallbackVendor(category);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();
    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': 0.6,
      'max_completion_tokens': 800,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'procurement specialist proposing realistic vendors for project procurement needs',
            strictJson: true,
            extraRules:
                'Return a JSON object with keys: name, category, rating, approved, preferred.',
          ),
        },
        {
          'role': 'user',
          'content':
              _vendorPrompt(projectName, solutionTitle, category, contextNotes)
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;

      return {
        'name': _stripAsterisks((parsed['name'] ?? '').toString().trim()),
        'category':
            _stripAsterisks((parsed['category'] ?? category).toString().trim()),
        'rating': (parsed['rating'] is num)
            ? (parsed['rating'] as num).toInt().clamp(1, 5)
            : 4,
        'approved': parsed['approved'] == true,
        'preferred': parsed['preferred'] == false, // Default to false
      };
    } catch (e) {
      debugPrint('generateVendorSuggestion failed: $e');
      return _fallbackVendor(category);
    }
  }

  Map<String, dynamic> _fallbackVendor(String category) {
    final names = {
      'IT Equipment': [
        'TechCorp Solutions',
        'Digital Systems Inc',
        'IT Partners Group'
      ],
      'Construction Services': [
        'BuildRight Contractors',
        'Premier Construction Co',
        'Apex Builders'
      ],
      'Furniture': [
        'Office Essentials Co',
        'Workspace Solutions',
        'Furniture Direct'
      ],
      'Security': [
        'SecureGuard Services',
        'Safety First Systems',
        'Protection Plus'
      ],
      'Logistics': [
        'FastTrack Logistics',
        'Global Shipping Co',
        'Express Delivery'
      ],
      'Services': [
        'Professional Services Group',
        'Expert Consultants',
        'Service Partners'
      ],
      'Materials': [
        'Material Supply Co',
        'Industrial Materials Inc',
        'Supply Chain Solutions'
      ],
    };
    final nameList = names[category] ?? ['Vendor Partner'];
    return {
      'name': nameList[0],
      'category': category,
      'rating': 4,
      'approved': true,
      'preferred': false,
    };
  }

  String _vendorPrompt(String projectName, String solutionTitle,
      String category, String contextNotes) {
    final notes = contextNotes.trim().isEmpty
        ? 'No additional context provided.'
        : contextNotes.trim();
    return '''
Generate a vendor suggestion for this procurement scenario:

Project: $projectName
Solution: $solutionTitle
Category: $category

Context: $notes

Provide a realistic vendor company name that specializes in $category. The vendor should be appropriate for a project involving "$solutionTitle".

Return a JSON object with:
- name: Company name (e.g., "Atlas Tech Supply" or "Premier Construction Co")
- category: "$category"
- rating: Integer 1-5 (typical range 3-5)
- approved: Boolean (typically true)
- preferred: Boolean (typically false unless explicitly noted)

Return ONLY valid JSON.
''';
  }

  // PROCUREMENT - ITEMS
  Future<Map<String, dynamic>> generateProcurementItemSuggestion({
    required String projectName,
    required String solutionTitle,
    required String category,
    String contextNotes = '',
  }) async {
    if (!OpenAiConfig.isConfigured) {
      return _fallbackProcurementItem(category);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();
    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': 0.6,
      'max_completion_tokens': 1000,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'procurement planner generating realistic procurement item suggestions',
            strictJson: true,
            extraRules:
                'Prioritize long-lead and schedule-critical items when relevant and return keys: name, description, category, budget, priority, estimatedDeliveryDays.',
          ),
        },
        {
          'role': 'user',
          'content': _procurementItemPrompt(
              projectName, solutionTitle, category, contextNotes)
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;

      final budget =
          (parsed['budget'] is num) ? (parsed['budget'] as num).toInt() : 50000;
      final deliveryDays = (parsed['estimatedDeliveryDays'] is num)
          ? (parsed['estimatedDeliveryDays'] as num).toInt().clamp(7, 365)
          : 90;

      return {
        'name': _stripAsterisks((parsed['name'] ?? '').toString().trim()),
        'description':
            _stripAsterisks((parsed['description'] ?? '').toString().trim()),
        'category':
            _stripAsterisks((parsed['category'] ?? category).toString().trim()),
        'budget': budget,
        'priority': _normalizePriority(
            (parsed['priority'] ?? 'medium').toString().trim()),
        'estimatedDeliveryDays': deliveryDays,
      };
    } catch (e) {
      debugPrint('generateProcurementItemSuggestion failed: $e');
      return _fallbackProcurementItem(category);
    }
  }

  Map<String, dynamic> _fallbackProcurementItem(String category) {
    final items = {
      'IT Equipment': {
        'name': 'Network Infrastructure Equipment',
        'description': 'Core networking hardware and switches',
        'budget': 85000
      },
      'Construction Services': {
        'name': 'Site Preparation Services',
        'description': 'Groundwork and site setup',
        'budget': 120000
      },
      'Furniture': {
        'name': 'Office Furniture Set',
        'description': 'Desks, chairs, and workspace furniture',
        'budget': 45000
      },
      'Security': {
        'name': 'Security System Installation',
        'description': 'Access control and monitoring systems',
        'budget': 65000
      },
      'Logistics': {
        'name': 'Shipping and Delivery Services',
        'description': 'Transportation and logistics coordination',
        'budget': 35000
      },
      'Services': {
        'name': 'Professional Services',
        'description': 'Consulting and implementation services',
        'budget': 95000
      },
      'Materials': {
        'name': 'Construction Materials',
        'description': 'Building materials and supplies',
        'budget': 75000
      },
    };
    final item = items[category] ??
        {
          'name': 'Procurement Item',
          'description': 'Item description',
          'budget': 50000
        };
    return {
      'name': item['name']!,
      'description': item['description']!,
      'category': category,
      'budget': item['budget']!,
      'priority': 'medium',
      'estimatedDeliveryDays': 90,
    };
  }

  String _normalizePriority(String priority) {
    final lower = priority.toLowerCase();
    if (lower.contains('critical')) return 'critical';
    if (lower.contains('high')) return 'high';
    if (lower.contains('low')) return 'low';
    return 'medium';
  }

  String _procurementItemPrompt(String projectName, String solutionTitle,
      String category, String contextNotes) {
    final notes = contextNotes.trim().isEmpty
        ? 'No additional context provided.'
        : contextNotes.trim();
    return '''
Generate a procurement item suggestion for this project:

Project: $projectName
Solution: $solutionTitle
Category: $category

Context: $notes

Provide a realistic procurement item that would be needed for a project involving "$solutionTitle" in the "$category" category.
Prefer long-lead or schedule-critical recommendations when context indicates that risk.
Tailor the recommendation to local/region constraints and what similar projects typically procure.

Return a JSON object with:
- name: Item name (e.g., "Network core switches" or "Office furniture set")
- description: Brief description (1-2 sentences)
- category: "$category"
- budget: Estimated cost as integer (typical range: 20000-200000)
- priority: One of: critical, high, medium, low (typically "medium" or "high")
- estimatedDeliveryDays: Days from now (typical range: 30-180)

Return ONLY valid JSON.
''';
  }

  // CONTRACTING SCOPE
  Future<Map<String, dynamic>> generateContractingScopeSuggestions({
    required String projectName,
    required String solutionTitle,
    required String projectType,
    required String contextNotes,
    String regionContext = '',
    int contractCount = 8,
    int scopeItemCount = 10,
  }) async {
    final safeContractCount = contractCount.clamp(3, 15).toInt();
    final safeScopeCount = scopeItemCount.clamp(4, 18).toInt();

    if (!OpenAiConfig.isConfigured) {
      return _fallbackContractingScopeSuggestions(
        projectName: projectName,
        solutionTitle: solutionTitle,
        projectType: projectType,
        regionContext: regionContext,
        contractCount: safeContractCount,
        scopeItemCount: safeScopeCount,
      );
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();
    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': 0.45,
      'max_completion_tokens': 2200,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'senior contracts strategist building context-aware contract scope packages',
            strictJson: true,
            extraRules:
                'Localize outputs for regional regulations, labor availability, logistics, permitting, and market conditions.',
          ),
        },
        {
          'role': 'user',
          'content': _contractingScopePrompt(
            projectName: projectName,
            solutionTitle: solutionTitle,
            projectType: projectType,
            contextNotes: contextNotes,
            regionContext: regionContext,
            contractCount: safeContractCount,
            scopeItemCount: safeScopeCount,
          ),
        },
      ],
    }));

    String clean(dynamic value) =>
        _stripAsterisks(value?.toString() ?? '').trim();

    double parseAmount(dynamic value, double fallback) {
      if (value is num) return value.toDouble();
      final normalized =
          (value?.toString() ?? '').replaceAll(RegExp(r'[^0-9\.-]'), '');
      return double.tryParse(normalized) ?? fallback;
    }

    String normalizeContractType(dynamic raw) {
      final value = clean(raw).toLowerCase();
      if (value.contains('lump')) return 'Lump Sum';
      if (value.contains('reimb') ||
          value.contains('time and material') ||
          value.contains('t&m')) {
        return 'Reimbursable';
      }
      return 'Unsure';
    }

    String normalizeBiddingRequired(dynamic raw) {
      final value = clean(raw).toLowerCase();
      if (value == 'no' ||
          value.contains('not required') ||
          value.contains('direct award')) {
        return 'No';
      }
      if (value == 'yes' ||
          value.contains('required') ||
          value.contains('competitive')) {
        return 'Yes';
      }
      return 'Not Sure';
    }

    List<Map<String, dynamic>> normalizeContracts(dynamic rawContracts) {
      final list = rawContracts is List ? rawContracts : const <dynamic>[];
      final seen = <String>{};
      final normalized = <Map<String, dynamic>>[];

      for (final raw in list) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final title = clean(map['title']);
        if (title.isEmpty) continue;
        final contractor = clean(map['contractor']);
        final signature = '${title.toLowerCase()}|${contractor.toLowerCase()}';
        if (!seen.add(signature)) continue;

        normalized.add({
          'title': title,
          'description': clean(map['description']),
          'contractor': contractor.isEmpty ? 'To be determined' : contractor,
          'cost': parseAmount(map['cost'], 0),
          'duration': clean(map['duration']).isEmpty
              ? '3-6 months'
              : clean(map['duration']),
          'owner':
              clean(map['owner']).isEmpty ? 'Unassigned' : clean(map['owner']),
          'status':
              clean(map['status']).isEmpty ? 'draft' : clean(map['status']),
        });
        if (normalized.length >= safeContractCount) break;
      }

      return normalized;
    }

    List<Map<String, dynamic>> normalizeScopeItems(dynamic rawItems) {
      final list = rawItems is List ? rawItems : const <dynamic>[];
      final seen = <String>{};
      final normalized = <Map<String, dynamic>>[];

      for (final raw in list) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final name = clean(map['name']).isNotEmpty
            ? clean(map['name'])
            : clean(map['contract_scope']);
        if (name.isEmpty) continue;
        final contractType = normalizeContractType(
          clean(map['contract_type']).isNotEmpty
              ? map['contract_type']
              : map['category'],
        );
        final signature = '${name.toLowerCase()}|${contractType.toLowerCase()}';
        if (!seen.add(signature)) continue;

        final estimatedValue =
            parseAmount(map['estimated_value'] ?? map['budget'], 0);
        final potentialContractors = clean(map['potential_contractors']).isEmpty
            ? clean(map['potential_vendors'])
            : clean(map['potential_contractors']);
        final estimatedDuration = clean(map['estimated_duration']).isEmpty
            ? (clean(map['comments']).isEmpty
                ? clean(map['duration'])
                : clean(map['comments']))
            : clean(map['estimated_duration']);
        final biddingRequired = normalizeBiddingRequired(
          clean(map['bidding_required']).isNotEmpty
              ? map['bidding_required']
              : map['responsible_member'],
        );

        normalized.add({
          'name': name,
          'description': clean(map['description']),
          'contract_type': contractType,
          'estimated_value': estimatedValue,
          'estimated_duration':
              estimatedDuration.isEmpty ? 'TBD' : estimatedDuration,
          'potential_contractors': potentialContractors,
          'bidding_required': biddingRequired,
          'project_phase': clean(map['project_phase']).isEmpty
              ? 'Contracting'
              : clean(map['project_phase']),
          'status':
              clean(map['status']).isEmpty ? 'planning' : clean(map['status']),
          'priority': _normalizePriority(
              clean(map['priority']).isEmpty ? 'high' : clean(map['priority'])),
          // Backward-compatible aliases
          'category': contractType,
          'budget': estimatedValue,
          'potential_vendors': potentialContractors,
          'responsible_member': biddingRequired,
          'comments': estimatedDuration.isEmpty ? 'TBD' : estimatedDuration,
        });
        if (normalized.length >= safeScopeCount) break;
      }

      return normalized;
    }

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;

      final contracts = normalizeContracts(parsed['contracts']);
      final items = normalizeScopeItems(
        parsed['contract_scope_items'] ?? parsed['procurement_items'],
      );
      if (contracts.isEmpty && items.isEmpty) {
        return _fallbackContractingScopeSuggestions(
          projectName: projectName,
          solutionTitle: solutionTitle,
          projectType: projectType,
          regionContext: regionContext,
          contractCount: safeContractCount,
          scopeItemCount: safeScopeCount,
        );
      }
      return {
        'contracts': contracts,
        'contract_scope_items': items,
        'procurement_items': items,
      };
    } catch (e) {
      debugPrint('generateContractingScopeSuggestions failed: $e');
      return _fallbackContractingScopeSuggestions(
        projectName: projectName,
        solutionTitle: solutionTitle,
        projectType: projectType,
        regionContext: regionContext,
        contractCount: safeContractCount,
        scopeItemCount: safeScopeCount,
      );
    }
  }

  String _contractingScopePrompt({
    required String projectName,
    required String solutionTitle,
    required String projectType,
    required String contextNotes,
    required String regionContext,
    required int contractCount,
    required int scopeItemCount,
  }) {
    final notes = contextNotes.trim().isEmpty
        ? 'No additional context provided.'
        : contextNotes.trim();
    final region = regionContext.trim().isEmpty
        ? 'Region not explicitly provided; infer cautiously from context.'
        : regionContext.trim();

    return '''
Generate contracting scope and contract-detail recommendations.

Project: $projectName
Preferred Solution: $solutionTitle
Project Type: $projectType
Regional Context: $region
Project Context Notes:
$notes

Requirements:
- Propose $contractCount contracts and $scopeItemCount contracting scope items.
- Use realistic practices seen in similar projects globally, but localize to the regional context above.
- Keep recommendations aligned to already-defined scope, milestones, and delivery constraints.
- Avoid generic software-only outputs unless context is clearly software-focused.
- Include contract packages that support schedule protection (long-lead, permitting, specialist scopes).
- Contract type must be one of: Lump Sum, Reimbursable, Unsure.
- Bidding required must be one of: Yes, No, Not Sure.

Return ONLY valid JSON in this exact structure:
{
  "contracts": [
    {
      "title": "Contract package title",
      "description": "Scope and deliverables",
      "contractor": "Suggested contractor type or profile",
      "cost": 120000,
      "duration": "4 months",
      "owner": "Responsible role",
      "status": "draft"
    }
  ],
  "contract_scope_items": [
    {
      "name": "Contracting scope item",
      "description": "What is covered in this contract scope",
      "potential_contractors": "List of contractor candidates or contractor profile examples",
      "contract_type": "Lump Sum|Reimbursable|Unsure",
      "estimated_value": 50000,
      "estimated_duration": "4 months",
      "bidding_required": "Yes|No|Not Sure",
      "project_phase": "Planning|Execution|Launch",
      "status": "planning|rfq_review|vendor_selection|ordered|delivered",
      "priority": "critical|high|medium|low"
    }
  ]
}
''';
  }

  Map<String, dynamic> _fallbackContractingScopeSuggestions({
    required String projectName,
    required String solutionTitle,
    required String projectType,
    required String regionContext,
    required int contractCount,
    required int scopeItemCount,
  }) {
    final region = regionContext.trim().isEmpty
        ? 'local jurisdiction'
        : regionContext.trim();

    final contractTemplates = <Map<String, dynamic>>[
      {
        'title': 'Primary Delivery Contract',
        'description':
            'Core delivery package for $projectType execution with milestone-linked outputs.',
        'contractor': 'Prime contractor with relevant delivery track record',
        'cost': 250000.0,
        'duration': '6 months',
        'owner': 'Project Manager',
        'status': 'draft',
      },
      {
        'title': 'Specialist Compliance Contract',
        'description':
            'Specialist support for permits, inspections, and compliance in $region.',
        'contractor': 'Regional compliance specialist',
        'cost': 90000.0,
        'duration': '4 months',
        'owner': 'Compliance Lead',
        'status': 'draft',
      },
      {
        'title': 'Long-Lead Supply Contract',
        'description':
            'Early procurement agreement for long-lead components to protect schedule.',
        'contractor': 'Tier-1 supplier with proven lead-time performance',
        'cost': 160000.0,
        'duration': '5 months',
        'owner': 'Procurement Lead',
        'status': 'draft',
      },
      {
        'title': 'Commissioning & Handover Contract',
        'description':
            'Testing, commissioning, and transition support for operational readiness.',
        'contractor': 'Commissioning and operations partner',
        'cost': 110000.0,
        'duration': '3 months',
        'owner': 'Delivery Manager',
        'status': 'draft',
      },
    ];

    final scopeTemplates = <Map<String, dynamic>>[
      {
        'name': 'Contract packaging and sequencing plan',
        'description':
            'Define package boundaries, dependencies, and award sequence against schedule-critical milestones.',
        'contract_type': 'Lump Sum',
        'estimated_value': 35000.0,
        'estimated_duration': '6 weeks',
        'potential_contractors': 'Regional contract management consultants',
        'bidding_required': 'Yes',
        'project_phase': 'Planning',
        'status': 'planning',
        'priority': 'high',
        'category': 'Lump Sum',
        'budget': 35000.0,
        'potential_vendors': 'Regional contract management consultants',
        'responsible_member': 'Yes',
        'comments': '6 weeks',
      },
      {
        'name': 'Permitting and approval support',
        'description':
            'Secure permitting scope aligned with local authority requirements in $region.',
        'contract_type': 'Reimbursable',
        'estimated_value': 45000.0,
        'estimated_duration': '10 weeks',
        'potential_contractors': 'Local permitting advisors and legal support',
        'bidding_required': 'No',
        'project_phase': 'Planning',
        'status': 'rfq_review',
        'priority': 'critical',
        'category': 'Reimbursable',
        'budget': 45000.0,
        'potential_vendors': 'Local permitting advisors and legal support',
        'responsible_member': 'No',
        'comments': '10 weeks',
      },
      {
        'name': 'Specialist execution services',
        'description':
            'Specialist execution package aligned to $solutionTitle implementation complexity.',
        'contract_type': 'Lump Sum',
        'estimated_value': 125000.0,
        'estimated_duration': '4 months',
        'potential_contractors': 'Certified specialist firms',
        'bidding_required': 'Yes',
        'project_phase': 'Execution',
        'status': 'vendor_selection',
        'priority': 'high',
        'category': 'Lump Sum',
        'budget': 125000.0,
        'potential_vendors': 'Certified specialist firms',
        'responsible_member': 'Yes',
        'comments': '4 months',
      },
      {
        'name': 'Critical equipment or systems supply',
        'description':
            'Long-lead supply package for schedule-critical systems and integration points.',
        'contract_type': 'Lump Sum',
        'estimated_value': 175000.0,
        'estimated_duration': '5 months',
        'potential_contractors': 'Tier-1 original equipment manufacturers',
        'bidding_required': 'Yes',
        'project_phase': 'Execution',
        'status': 'ordered',
        'priority': 'critical',
        'category': 'Lump Sum',
        'budget': 175000.0,
        'potential_vendors': 'Tier-1 original equipment manufacturers',
        'responsible_member': 'Yes',
        'comments': '5 months',
      },
      {
        'name': 'Testing and commissioning readiness',
        'description':
            'Commissioning package with acceptance criteria, test plans, and handover documentation.',
        'contract_type': 'Unsure',
        'estimated_value': 80000.0,
        'estimated_duration': '9 weeks',
        'potential_contractors': 'Commissioning engineers and QA specialists',
        'bidding_required': 'Not Sure',
        'project_phase': 'Launch',
        'status': 'planning',
        'priority': 'medium',
        'category': 'Unsure',
        'budget': 80000.0,
        'potential_vendors': 'Commissioning engineers and QA specialists',
        'responsible_member': 'Not Sure',
        'comments': '9 weeks',
      },
    ];

    return {
      'contracts': contractTemplates.take(contractCount).toList(),
      'contract_scope_items': scopeTemplates.take(scopeItemCount).toList(),
      'procurement_items': scopeTemplates.take(scopeItemCount).toList(),
    };
  }

  // PROCUREMENT - LIST HELPERS
  Future<List<Map<String, dynamic>>> generateProcurementVendors({
    required String projectName,
    required String solutionTitle,
    String contextNotes = '',
    int count = 5,
    List<String> preferredCategories = const [],
  }) async {
    final defaultCategories = [
      'IT Equipment',
      'Construction Services',
      'Furniture',
      'Security',
      'Logistics',
      'Services',
      'Materials',
    ];
    final categories = <String>[];
    for (final category in [...preferredCategories, ...defaultCategories]) {
      final normalized = category.trim();
      if (normalized.isEmpty || categories.contains(normalized)) continue;
      categories.add(normalized);
    }
    if (categories.isEmpty) {
      categories.addAll(defaultCategories);
    }
    final results = <Map<String, dynamic>>[];
    for (var i = 0; i < count; i++) {
      final category = categories[i % categories.length];
      try {
        final vendor = await generateVendorSuggestion(
          projectName: projectName,
          solutionTitle: solutionTitle,
          category: category,
          contextNotes: contextNotes,
        );
        results.add(vendor);
      } catch (_) {
        // Ignore and continue; screen already seeds fallback rows.
      }
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> generateProcurementRfqs({
    required String projectName,
    required String solutionTitle,
    String contextNotes = '',
    int count = 3,
  }) async {
    if (!OpenAiConfig.isConfigured) return [];
    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();
    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': 0.5,
      'max_completion_tokens': 1200,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'procurement specialist drafting context-aware RFQ entries',
            strictJson: true,
            extraRules:
                'Return strict JSON with an "items" array for RFQs only.',
          ),
        },
        {
          'role': 'user',
          'content': '''
Generate $count RFQs for project "$projectName" (solution: "$solutionTitle").
Each RFQ needs: title, category, owner, dueDate (YYYY-MM-DD), invited (int), responses (int), budget (int), status (draft/review/in_market/evaluation/awarded), priority (critical/high/medium/low).
Context: $contextNotes
Return ONLY JSON: {"items":[...]}'''
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 14));
      if (response.statusCode < 200 || response.statusCode >= 300) return [];
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;
      return (parsed['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('generateProcurementRfqs failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> generateProcurementPurchaseOrders({
    required String projectName,
    required String solutionTitle,
    String contextNotes = '',
    int count = 4,
  }) async {
    if (!OpenAiConfig.isConfigured) return [];
    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();
    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': 0.5,
      'max_completion_tokens': 1200,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'procurement specialist drafting context-aware purchase order entries',
            strictJson: true,
            extraRules:
                'Return strict JSON with an "items" array for purchase orders only.',
          ),
        },
        {
          'role': 'user',
          'content': '''
Generate $count purchase orders for "$projectName" (solution: "$solutionTitle").
Each PO needs: id, vendor, category, owner, orderedDate (YYYY-MM-DD), expectedDate (YYYY-MM-DD), amount (int), progress (0-1), status (awaiting_approval/issued/in_transit/received).
Context: $contextNotes
Return ONLY JSON: {"items":[...]}'''
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 14));
      if (response.statusCode < 200 || response.statusCode >= 300) return [];
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;
      return (parsed['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('generateProcurementPurchaseOrders failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> generateProcurementTrackableItems({
    required String projectName,
    required String solutionTitle,
    String contextNotes = '',
    int count = 3,
  }) async {
    if (!OpenAiConfig.isConfigured) return [];
    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();
    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': 0.5,
      'max_completion_tokens': 1400,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'procurement tracking analyst generating shipment and status tracking entries',
            strictJson: true,
            extraRules: 'Return strict JSON with an "items" array only.',
          ),
        },
        {
          'role': 'user',
          'content': '''
Generate $count trackable procurement items for "$projectName" (solution: "$solutionTitle").
Each item needs: name, description, orderStatus, currentStatus (inTransit/delivered/notTracked), lastUpdate (YYYY-MM-DD HH:MM), events (array of {title, date, status}).
Context: $contextNotes
Return ONLY JSON: {"items":[...]}'''
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 14));
      if (response.statusCode < 200 || response.statusCode >= 300) return [];
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;
      return (parsed['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('generateProcurementTrackableItems failed: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> generateProcurementReportsData() {
    return [
      {
        'kpis': [
          {
            'label': 'On-time delivery',
            'value': '86%',
            'delta': '+4%',
            'positive': true
          },
          {
            'label': 'Spend vs budget',
            'value': '92%',
            'delta': '-3%',
            'positive': true
          },
          {
            'label': 'Open RFQs',
            'value': '8',
            'delta': '+2',
            'positive': false
          },
        ],
        'spendBreakdown': [
          {
            'label': 'IT Equipment',
            'amount': 240000,
            'percent': 42,
            'color': 0xFF6366F1
          },
          {
            'label': 'Construction',
            'amount': 180000,
            'percent': 31,
            'color': 0xFFF59E0B
          },
          {
            'label': 'Security',
            'amount': 90000,
            'percent': 16,
            'color': 0xFF10B981
          },
          {
            'label': 'Other',
            'amount': 60000,
            'percent': 11,
            'color': 0xFF94A3B8
          },
        ],
        'leadTimeMetrics': [
          {'label': 'Critical items', 'onTimeRate': 0.78},
          {'label': 'Standard items', 'onTimeRate': 0.9},
        ],
        'savingsOpportunities': [
          {
            'title': 'Renegotiate security maintenance',
            'value': '\$18k',
            'owner': 'Procurement'
          },
          {'title': 'Consolidate IT vendors', 'value': '\$24k', 'owner': 'Ops'},
        ],
        'complianceMetrics': [
          {'label': 'Policy adherence', 'value': 0.84},
          {'label': 'Contract coverage', 'value': 0.91},
        ],
      }
    ];
  }

  /// Predict potential delays for deliverables based on current date and project context
  Future<Map<String, dynamic>> predictDeliverableDelays({
    required String context,
    required String deliverableTitle,
    required String dueDate,
    required String currentStatus,
    int maxTokens = 500,
    double temperature = 0.6,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) {
      return _fallbackDelayPrediction(deliverableTitle, dueDate);
    }

    if (!OpenAiConfig.isConfigured) {
      return _fallbackDelayPrediction(deliverableTitle, dueDate);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a project management AI. Analyze the deliverable and predict potential delays based on the project context, current status, and due date. Return ONLY valid JSON with risk assessment and mitigation suggestions.'
        },
        {
          'role': 'user',
          'content': _delayPredictionPrompt(
            trimmedContext,
            deliverableTitle,
            dueDate,
            currentStatus,
          ),
        },
      ],
    }));

    try {
      final response = await http.post(uri, headers: headers, body: body);
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body) as Map<String, dynamic>;
        final content = parsed['choices']?[0]?['message']?['content'];
        if (content != null) {
          final result = jsonDecode(content.toString()) as Map<String, dynamic>;
          return _parseDelayPrediction(result, deliverableTitle, dueDate);
        }
      }
    } catch (e) {
      debugPrint('predictDeliverableDelays failed: $e');
    }

    return _fallbackDelayPrediction(deliverableTitle, dueDate);
  }

  String _delayPredictionPrompt(
    String context,
    String deliverableTitle,
    String dueDate,
    String currentStatus,
  ) {
    final escaped = _escape(context);
    return '''
Analyze the following deliverable and predict potential delays based on the project context.

Deliverable: $deliverableTitle
Due Date: $dueDate
Current Status: $currentStatus

Consider:
- Project complexity and dependencies
- Current progress vs timeline
- Resource availability
- Historical project patterns
- Risk factors

Return ONLY valid JSON with this exact structure:
{
  "riskLevel": "Low" | "Medium" | "High",
  "predictedDelayDays": 0-30,
  "riskFactors": [
    "Factor 1",
    "Factor 2",
    "Factor 3"
  ],
  "mitigationSuggestions": [
    ". Suggestion 1",
    ". Suggestion 2",
    ". Suggestion 3"
  ],
  "recommendedAction": "Prose description of recommended action (no bullets)"
}

Project Context:
"""
$escaped
"""
''';
  }

  Map<String, dynamic> _parseDelayPrediction(
    Map<String, dynamic> parsed,
    String deliverableTitle,
    String dueDate,
  ) {
    final riskLevel = _stripAsterisks(
      (parsed['riskLevel'] ?? 'Medium').toString().trim(),
    );
    final delayDays = (parsed['predictedDelayDays'] as num?)?.toInt() ?? 0;
    final riskFactorsRaw = parsed['riskFactors'];
    final riskFactors = <String>[];
    if (riskFactorsRaw is List) {
      riskFactors.addAll(
        riskFactorsRaw
            .map((f) => _stripAsterisks(f.toString().trim()))
            .where((f) => f.isNotEmpty),
      );
    }
    final mitigationRaw = parsed['mitigationSuggestions'];
    final mitigations = <String>[];
    if (mitigationRaw is List) {
      mitigations.addAll(
        mitigationRaw
            .map((m) => _stripAsterisks(m.toString().trim()))
            .where((m) => m.isNotEmpty),
      );
    }
    final recommendedAction = _stripAsterisks(
      (parsed['recommendedAction'] ?? '').toString().trim(),
    );

    return {
      'riskLevel': riskLevel,
      'predictedDelayDays': delayDays,
      'riskFactors': riskFactors,
      'mitigationSuggestions': mitigations,
      'recommendedAction': recommendedAction.isNotEmpty
          ? recommendedAction
          : 'Monitor progress closely and adjust resources if needed.',
    };
  }

  Map<String, dynamic> _fallbackDelayPrediction(
    String deliverableTitle,
    String dueDate,
  ) {
    return {
      'riskLevel': 'Medium',
      'predictedDelayDays': 0,
      'riskFactors': [
        'Insufficient data to assess risk',
        'Monitor progress regularly',
      ],
      'mitigationSuggestions': [
        '. Review dependencies',
        '. Allocate additional resources if needed',
        '. Communicate with stakeholders',
      ],
      'recommendedAction':
          'Continue monitoring the deliverable progress and adjust timeline if necessary.',
    };
  }

  /// Suggest cost-saving measures if spending exceeds plan
  Future<List<String>> suggestCostSavingMeasures({
    required String context,
    required double plannedAmount,
    required double actualAmount,
    int maxSuggestions = 5,
    int maxTokens = 600,
    double temperature = 0.6,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) {
      return _fallbackCostSavingMeasures();
    }

    if (!OpenAiConfig.isConfigured) {
      return _fallbackCostSavingMeasures();
    }

    final variance = actualAmount - plannedAmount;
    final variancePercent = plannedAmount > 0
        ? ((variance / plannedAmount) * 100).toStringAsFixed(1)
        : '0';

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a financial analysis AI. Analyze spending patterns and suggest practical cost-saving measures. Return ONLY valid JSON with an array of suggestions.'
        },
        {
          'role': 'user',
          'content': _costSavingPrompt(
            trimmedContext,
            plannedAmount,
            actualAmount,
            variancePercent,
            maxSuggestions,
          ),
        },
      ],
    }));

    try {
      final response = await http.post(uri, headers: headers, body: body);
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body) as Map<String, dynamic>;
        final content = parsed['choices']?[0]?['message']?['content'];
        if (content != null) {
          final result = jsonDecode(content.toString()) as Map<String, dynamic>;
          return _parseCostSavingSuggestions(result);
        }
      }
    } catch (e) {
      debugPrint('suggestCostSavingMeasures failed: $e');
    }

    return _fallbackCostSavingMeasures();
  }

  String _costSavingPrompt(
    String context,
    double plannedAmount,
    double actualAmount,
    String variancePercent,
    int maxSuggestions,
  ) {
    final escaped = _escape(context);
    final isOverBudget = actualAmount > plannedAmount;
    return '''
Analyze the project spending and suggest $maxSuggestions practical cost-saving measures.

Planned Amount: \$${plannedAmount.toStringAsFixed(2)}
Actual Amount: \$${actualAmount.toStringAsFixed(2)}
Variance: ${isOverBudget ? '+' : ''}$variancePercent%

${isOverBudget ? '⚠️ Spending exceeds plan. Suggest specific, actionable cost-saving measures.' : 'Spending is within plan. Suggest proactive cost optimization measures.'}

Return ONLY valid JSON with this exact structure:
{
  "suggestions": [
    ". Suggestion 1",
    ". Suggestion 2",
    ". Suggestion 3",
    ". Suggestion 4",
    ". Suggestion 5"
  ]
}

Each suggestion should:
- Be specific and actionable
- Use "." bullet format
- Consider the project context and constraints
- Be realistic and implementable

Project Context:
"""
$escaped
"""
''';
  }

  List<String> _parseCostSavingSuggestions(Map<String, dynamic> parsed) {
    final suggestionsRaw = parsed['suggestions'];
    if (suggestionsRaw is List) {
      return suggestionsRaw
          .map((s) => _stripAsterisks(s.toString().trim()))
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return _fallbackCostSavingMeasures();
  }

  List<String> _fallbackCostSavingMeasures() {
    return [
      '. Review and optimize vendor contracts',
      '. Identify non-essential expenses that can be deferred',
      '. Negotiate better rates with suppliers',
      '. Consolidate similar activities to reduce overhead',
      '. Implement stricter budget approval processes',
    ];
  }

  /// Auto-summarize weekly wins from completed tasks
  Future<String> summarizeWeeklyWins({
    required String context,
    required List<String> completedTasks,
    int maxTokens = 400,
    double temperature = 0.5,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty || completedTasks.isEmpty) {
      return _fallbackWeeklyWinsSummary(completedTasks);
    }

    if (!OpenAiConfig.isConfigured) {
      return _fallbackWeeklyWinsSummary(completedTasks);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final tasksText = completedTasks.join('\n');

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a project communication AI. Summarize completed tasks into a concise, positive "Weekly Wins" summary. Use prose format (no bullets, complete sentences).'
        },
        {
          'role': 'user',
          'content': _weeklyWinsPrompt(trimmedContext, tasksText),
        },
      ],
    }));

    try {
      final response = await http.post(uri, headers: headers, body: body);
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body) as Map<String, dynamic>;
        final content = parsed['choices']?[0]?['message']?['content'];
        if (content != null) {
          final result = jsonDecode(content.toString()) as Map<String, dynamic>;
          final summary = _stripAsterisks(
            (result['summary'] ?? '').toString().trim(),
          );
          if (summary.isNotEmpty) {
            return summary;
          }
        }
      }
    } catch (e) {
      debugPrint('summarizeWeeklyWins failed: $e');
    }

    return _fallbackWeeklyWinsSummary(completedTasks);
  }

  String _weeklyWinsPrompt(String context, String tasksText) {
    final escaped = _escape(context);
    return '''
Based on the project context and completed tasks below, generate a concise "Weekly Wins" summary.

Requirements:
- Use prose format (no bullets, complete sentences)
- Highlight key achievements and progress
- Keep it positive and motivating
- Be specific about what was accomplished
- 2-3 sentences maximum

Return ONLY valid JSON with this exact structure:
{
  "summary": "Prose summary of weekly wins highlighting key achievements..."
}

Completed Tasks:
"""
$tasksText
"""

Project Context:
"""
$escaped
"""
''';
  }

  String _fallbackWeeklyWinsSummary(List<String> completedTasks) {
    if (completedTasks.isEmpty) {
      return 'No completed tasks to summarize this week.';
    }
    final count = completedTasks.length;
    return 'This week, the team successfully completed $count ${count == 1 ? 'task' : 'tasks'}, demonstrating strong progress toward project goals.';
  }

  /// Generate standard contract key terms based on contract type and preferred solution
  Future<String> generateContractKeyTerms({
    required String context,
    required String contractType,
    int maxTokens = 600,
    double temperature = 0.6,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) {
      return _fallbackContractKeyTerms(contractType);
    }

    if (!OpenAiConfig.isConfigured) {
      return _fallbackContractKeyTerms(contractType);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a legal contract specialist AI. Generate standard key terms for contracts based on the contract type and project context. Return ONLY valid JSON with key terms formatted with "." bullet prefix.'
        },
        {
          'role': 'user',
          'content': _contractKeyTermsPrompt(trimmedContext, contractType),
        },
      ],
    }));

    try {
      final response = await http.post(uri, headers: headers, body: body);
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body) as Map<String, dynamic>;
        final content = parsed['choices']?[0]?['message']?['content'];
        if (content != null) {
          final result = jsonDecode(content.toString()) as Map<String, dynamic>;
          final keyTerms = _stripAsterisks(
            (result['keyTerms'] ?? '').toString().trim(),
          );
          if (keyTerms.isNotEmpty) {
            return keyTerms;
          }
        }
      }
    } catch (e) {
      debugPrint('generateContractKeyTerms failed: $e');
    }

    return _fallbackContractKeyTerms(contractType);
  }

  String _contractKeyTermsPrompt(String context, String contractType) {
    final escaped = _escape(context);
    return '''
Generate standard key terms for a "$contractType" contract based on the project context below.

Requirements:
- Generate 5-7 key terms specific to this contract type
- Each term should be a complete, actionable clause
- Use "." bullet format (each line should start with ". ")
- Terms should be relevant to the project's preferred solution and domain
- Focus on standard legal and business terms appropriate for this contract type

Return ONLY valid JSON with this exact structure:
{
  "keyTerms": ". Term 1\\n. Term 2\\n. Term 3\\n. Term 4\\n. Term 5"
}

Contract Type: $contractType

Project Context:
"""
$escaped
"""
''';
  }

  String _fallbackContractKeyTerms(String contractType) {
    switch (contractType.toLowerCase()) {
      case 'service level agreement (sla)':
      case 'sla':
        return '. Service availability target: 99.9% uptime\n. Response time: Critical issues within 2 hours\n. Escalation procedures defined\n. Performance metrics and reporting requirements\n. Penalties for service level breaches\n. Review and renewal terms';
      case 'nda':
      case 'non-disclosure agreement':
        return '. Confidential information definition\n. Obligations of receiving party\n. Exclusions from confidentiality\n. Term and duration of agreement\n. Return or destruction of materials\n. Remedies for breach';
      case 'procurement':
        return '. Delivery schedule and milestones\n. Quality standards and acceptance criteria\n. Payment terms and invoicing\n. Warranty and support provisions\n. Change order procedures\n. Termination and cancellation terms';
      case 'employment':
        return '. Job title and responsibilities\n. Compensation and benefits\n. Work schedule and location\n. Confidentiality and non-compete clauses\n. Termination notice requirements\n. Intellectual property assignment';
      default:
        return '. Scope of work and deliverables\n. Payment terms and schedule\n. Term and termination conditions\n. Confidentiality provisions\n. Dispute resolution procedures';
    }
  }

  /// Generate vendor SLA/Terms based on vendor category and project context
  Future<String> generateVendorSLATerms({
    required String context,
    required String vendorCategory,
    int maxTokens = 600,
    double temperature = 0.6,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) {
      return _fallbackVendorSLATerms(vendorCategory);
    }

    if (!OpenAiConfig.isConfigured) {
      return _fallbackVendorSLATerms(vendorCategory);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a vendor management specialist AI. Generate standard SLA terms and required deliverables for vendors based on their category and project context. Return ONLY valid JSON with terms formatted with "." bullet prefix.'
        },
        {
          'role': 'user',
          'content': _vendorSLATermsPrompt(trimmedContext, vendorCategory),
        },
      ],
    }));

    try {
      final response = await http.post(uri, headers: headers, body: body);
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body) as Map<String, dynamic>;
        final content = parsed['choices']?[0]?['message']?['content'];
        if (content != null) {
          final result = jsonDecode(content.toString()) as Map<String, dynamic>;
          final terms = _stripAsterisks(
            (result['slaTerms'] ?? '').toString().trim(),
          );
          if (terms.isNotEmpty) {
            return terms;
          }
        }
      }
    } catch (e) {
      debugPrint('generateVendorSLATerms failed: $e');
    }

    return _fallbackVendorSLATerms(vendorCategory);
  }

  String _vendorSLATermsPrompt(String context, String vendorCategory) {
    final escaped = _escape(context);
    return '''
Generate standard SLA terms and required deliverables for a vendor in the "$vendorCategory" category based on the project context below.

Requirements:
- Generate 5-7 specific deliverables and performance requirements
- Each item should be a complete, actionable requirement
- Use "." bullet format (each line should start with ". ")
- Terms should be relevant to the vendor category and project's preferred solution
- Focus on measurable performance metrics, delivery timelines, and quality standards

Return ONLY valid JSON with this exact structure:
{
  "slaTerms": ". Deliverable 1\\n. Deliverable 2\\n. Deliverable 3\\n. Deliverable 4\\n. Deliverable 5"
}

Vendor Category: $vendorCategory

Project Context:
"""
$escaped
"""
''';
  }

  String _fallbackVendorSLATerms(String category) {
    switch (category.toLowerCase()) {
      case 'logistics':
        return '. On-time delivery target: 95% within agreed timeframe\n. Real-time shipment tracking and status updates\n. Damage-free delivery with proper packaging\n. 24-hour customer support for urgent issues\n. Monthly performance reports\n. Compliance with all regulatory requirements';
      case 'it hardware':
        return '. Hardware delivery within 14 business days\n. Pre-installation testing and quality assurance\n. Warranty coverage for minimum 12 months\n. Technical support during business hours\n. Installation and configuration services\n. Return and replacement procedures for defective items';
      case 'consulting':
        return '. Weekly progress reports and status updates\n. Deliverable milestones aligned with project timeline\n. Subject matter expertise in specified domain\n. Availability for meetings and consultations\n. Documentation and knowledge transfer\n. Post-engagement support period';
      case 'raw materials':
        return '. Material quality meets specified standards\n. Batch tracking and traceability\n. Delivery schedule adherence\n. Proper storage and handling procedures\n. Material safety data sheets provided\n. Minimum order quantities and lead times';
      case 'utilities':
        return '. Service availability: 99.5% uptime\n. Response time for outages: within 4 hours\n. Monthly usage reports and billing transparency\n. Emergency contact availability 24/7\n. Scheduled maintenance notifications\n. Compliance with service level commitments';
      default:
        return '. Deliverables meet specified quality standards\n. Delivery timelines aligned with project schedule\n. Regular status updates and communication\n. Compliance with all contractual requirements\n. Support and issue resolution procedures';
    }
  }

  /// Generate technical specification details for design components
  Future<String> generateDesignSpecification({
    required String context,
    required String componentName,
    required String category,
    int maxTokens = 800,
    double temperature = 0.6,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) {
      return _fallbackDesignSpecification(componentName, category);
    }

    if (!OpenAiConfig.isConfigured) {
      return _fallbackDesignSpecification(componentName, category);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a technical architect AI. Generate detailed technical specifications for design components based on component name, category, and project context. Return ONLY valid JSON with specifications formatted with "." bullet prefix.'
        },
        {
          'role': 'user',
          'content': _designSpecificationPrompt(
              trimmedContext, componentName, category),
        },
      ],
    }));

    try {
      final response = await http.post(uri, headers: headers, body: body);
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body) as Map<String, dynamic>;
        final content = parsed['choices']?[0]?['message']?['content'];
        if (content != null) {
          final result = jsonDecode(content.toString()) as Map<String, dynamic>;
          final specs = _stripAsterisks(
            (result['specifications'] ?? '').toString().trim(),
          );
          if (specs.isNotEmpty) {
            return specs;
          }
        }
      }
    } catch (e) {
      debugPrint('generateDesignSpecification failed: $e');
    }

    return _fallbackDesignSpecification(componentName, category);
  }

  String _designSpecificationPrompt(
      String context, String componentName, String category) {
    final escaped = _escape(context);
    return '''
Generate detailed technical specifications for a design component named "$componentName" in the "$category" category based on the project context below.

Requirements:
- Generate 6-8 specific technical requirements and specifications
- Each item should be a complete, actionable technical requirement
- Use "." bullet format (each line should start with ". ")
- Specifications should be relevant to the component name, category, and project's preferred solution
- Focus on technical details: architecture, protocols, standards, interfaces, performance, security, scalability

Return ONLY valid JSON with this exact structure:
{
  "specifications": ". Requirement 1\\n. Requirement 2\\n. Requirement 3\\n. Requirement 4\\n. Requirement 5\\n. Requirement 6"
}

Component Name: $componentName
Category: $category

Project Context:
"""
$escaped
"""
''';
  }

  String _fallbackDesignSpecification(String componentName, String category) {
    switch (category.toLowerCase()) {
      case 'ui/ux':
        return '. Responsive design supporting mobile, tablet, and desktop viewports\n. Accessibility compliance (WCAG 2.1 AA minimum)\n. Consistent design system with reusable component library\n. User authentication and authorization UI flows\n. Error handling and loading state management\n. Cross-browser compatibility (Chrome, Firefox, Safari, Edge)';
      case 'backend':
        return '. RESTful API design with versioning strategy\n. Database schema with proper indexing and relationships\n. Authentication and authorization middleware\n. Error handling and logging mechanisms\n. API rate limiting and throttling\n. Data validation and sanitization\n. Caching strategy for performance optimization';
      case 'security':
        return '. Encryption at rest and in transit (TLS 1.3 minimum)\n. Authentication using OAuth 2.0 or JWT tokens\n. Role-based access control (RBAC) implementation\n. Security audit logging and monitoring\n. Input validation and SQL injection prevention\n. Regular security vulnerability assessments';
      case 'networking':
        return '. Network topology and segmentation design\n. Load balancing and failover mechanisms\n. Firewall rules and network security policies\n. VPN configuration for remote access\n. DNS and CDN configuration\n. Network monitoring and alerting setup';
      case 'physical infrastructure':
        return '. Server hardware specifications and capacity planning\n. Data center location and redundancy requirements\n. Power and cooling infrastructure\n. Network cabling and physical security\n. Backup and disaster recovery procedures\n. Hardware lifecycle management';
      default:
        return '. Define clear technical requirements and interfaces\n. Establish performance and scalability targets\n. Implement proper error handling and logging\n. Ensure security best practices are followed\n. Document integration points and dependencies';
    }
  }

  /// Break down a user story into specific sub-tasks based on Detailed Design components
  Future<String> breakDownUserStory({
    required String context,
    required String userStory,
    required List<String> designComponents,
    int maxTokens = 800,
    double temperature = 0.6,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) {
      return _fallbackTaskBreakdown(userStory);
    }

    if (!OpenAiConfig.isConfigured) {
      return _fallbackTaskBreakdown(userStory);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'agile delivery specialist decomposing implementation work into executable sub-tasks',
            strictJson: true,
            extraRules:
                'Return ONLY valid JSON with key "subTasks". Use "." bullets and generate practical steps aligned to project type and starting point.',
          ),
        },
        {
          'role': 'user',
          'content':
              _taskBreakdownPrompt(trimmedContext, userStory, designComponents),
        },
      ],
    }));

    try {
      final response = await http.post(uri, headers: headers, body: body);
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body) as Map<String, dynamic>;
        final content = parsed['choices']?[0]?['message']?['content'];
        if (content != null) {
          final result = jsonDecode(content.toString()) as Map<String, dynamic>;
          final breakdown = _stripAsterisks(
            (result['subTasks'] ?? '').toString().trim(),
          );
          if (breakdown.isNotEmpty) {
            return breakdown;
          }
        }
      }
    } catch (e) {
      debugPrint('breakDownUserStory failed: $e');
    }

    return _fallbackTaskBreakdown(userStory);
  }

  String _taskBreakdownPrompt(
      String context, String userStory, List<String> designComponents) {
    final escaped = _escape(context);
    final componentsText = designComponents.isEmpty
        ? 'No specific design components identified yet.'
        : designComponents.map((c) => '- $c').join('\n');

    return '''
Break down the following user story into 3-5 specific, actionable sub-tasks based on the project context and available design components.

Requirements:
- Generate 3-5 specific sub-tasks that can be completed independently
- Each sub-task should be a complete, actionable task
- Use "." bullet format (each line should start with ". ")
- Sub-tasks should align with the design components identified
- Focus on technical implementation steps

Return ONLY valid JSON with this exact structure:
{
  "subTasks": ". Sub-task 1\\n. Sub-task 2\\n. Sub-task 3\\n. Sub-task 4\\n. Sub-task 5"
}

User Story: $userStory

Available Design Components:
$componentsText

Project Context:
"""
$escaped
"""
''';
  }

  String _fallbackTaskBreakdown(String userStory) {
    return '. Analyze requirements and design specifications\n. Implement core functionality\n. Add error handling and validation\n. Write unit tests\n. Update documentation';
  }

  /// Generate verification steps for a scope item based on Detailed Design components
  Future<String> generateVerificationSteps({
    required String context,
    required String scopeItem,
    required List<String> designComponents,
    int maxTokens = 600,
    double temperature = 0.6,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) {
      return _fallbackVerificationSteps(scopeItem);
    }

    if (!OpenAiConfig.isConfigured) {
      return _fallbackVerificationSteps(scopeItem);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'quality assurance specialist defining verification steps for execution deliverables',
            strictJson: true,
            extraRules:
                'Return JSON only with key "verificationSteps". Provide domain-appropriate verification actions for the detected project type and starting point.',
          ),
        },
        {
          'role': 'user',
          'content': _verificationStepsPrompt(
              trimmedContext, scopeItem, designComponents),
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content = OpenAiConfig.extractContent(data);
      if (content.isNotEmpty) {
        final parsed = _decodeJsonSafely(content);
        if (parsed != null) {
          final result = parsed['verificationSteps']?.toString().trim() ?? '';
          if (result.isNotEmpty) {
            return _stripAsterisks(result);
          }
        }
      }
    } catch (e) {
      debugPrint('generateVerificationSteps failed: $e');
    }

    return _fallbackVerificationSteps(scopeItem);
  }

  String _verificationStepsPrompt(
      String context, String scopeItem, List<String> designComponents) {
    final escaped = _escape(context);
    final componentsText = designComponents.isEmpty
        ? 'No specific design components identified yet.'
        : designComponents.map((c) => '- $c').join('\n');

    return '''
Generate specific verification steps for the following scope item based on the project context and available design components.

Requirements:
- Generate 3-5 specific verification steps that can be used to validate the scope item
- Each step should be a complete, actionable verification task
- Use "." bullet format (each line should start with ". ")
- Steps should align with the design components and verification methods (Testing, UAT, Stakeholder Review)
- Focus on practical validation approaches

Return ONLY valid JSON with this exact structure:
{
  "verificationSteps": ". Verification step 1\\n. Verification step 2\\n. Verification step 3\\n. Verification step 4\\n. Verification step 5"
}

Scope Item: $scopeItem

Available Design Components:
$componentsText

Project Context:
"""
$escaped
"""
''';
  }

  String _fallbackVerificationSteps(String scopeItem) {
    return '. Review design specifications against requirements\n. Execute functional testing\n. Conduct user acceptance testing\n. Validate integration points\n. Document test results and sign-off';
  }

  /// Generate acceptance criteria for a planning requirement
  Future<String> generateAcceptanceCriteria({
    required String context,
    required String requirementText,
    int maxTokens = 600,
    double temperature = 0.6,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) {
      return _fallbackAcceptanceCriteria(requirementText);
    }

    if (!OpenAiConfig.isConfigured) {
      return _fallbackAcceptanceCriteria(requirementText);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a senior project manager helping to write measurable acceptance criteria for requirements. Always reply with JSON only and obey the required schema.'
        },
        {
          'role': 'user',
          'content': _acceptanceCriteriaPrompt(trimmedContext, requirementText),
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content = OpenAiConfig.extractContent(data);
      if (content.isNotEmpty) {
        final parsed = _decodeJsonSafely(content);
        if (parsed != null) {
          final result = parsed['acceptanceCriteria']?.toString().trim() ?? '';
          if (result.isNotEmpty) {
            return _stripAsterisks(result);
          }
        }
      }
    } catch (e) {
      debugPrint('generateAcceptanceCriteria failed: $e');
    }

    return _fallbackAcceptanceCriteria(requirementText);
  }

  String _acceptanceCriteriaPrompt(String context, String requirementText) {
    final escaped = _escape(context);
    final req = _escape(requirementText);
    return '''
Generate measurable acceptance criteria for the requirement below using the project context.

Requirements:
- Generate 3-5 specific acceptance criteria
- Each criterion should be testable and measurable
- Use "." bullet format (each line should start with ". ")
- Avoid vague language like "appropriate" or "adequate"

Return ONLY valid JSON with this exact structure:
{
  "acceptanceCriteria": ". Criterion 1\\n. Criterion 2\\n. Criterion 3\\n. Criterion 4\\n. Criterion 5"
}

Requirement: $req

Project Context:
"""
$escaped
"""
''';
  }

  String _fallbackAcceptanceCriteria(String requirementText) {
    final req = requirementText.trim();
    if (req.isEmpty) {
      return '. Acceptance criteria are defined and agreed by stakeholders\n. Evidence is recorded for verification and sign-off\n. All required deliverables are completed to specification';
    }
    return '. $req is delivered as specified and verified by testing\n. Stakeholders review and approve the outcome\n. Evidence is documented for sign-off';
  }

  /// Generate engagement strategy for a stakeholder based on their alignment status and key interest
  Future<String> generateEngagementStrategy({
    required String context,
    required String stakeholderName,
    required String stakeholderRole,
    required String keyInterest,
    required String alignmentStatus,
    String feedbackSummary = '',
    int maxTokens = 600,
    double temperature = 0.6,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) {
      return _fallbackEngagementStrategy(
          stakeholderName, keyInterest, alignmentStatus);
    }

    if (!OpenAiConfig.isConfigured) {
      return _fallbackEngagementStrategy(
          stakeholderName, keyInterest, alignmentStatus);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': _nduProjectSystemPrompt(
            specialistRole:
                'stakeholder engagement specialist drafting execution-phase engagement strategies',
            strictJson: true,
            extraRules:
                'Return JSON only with key "engagementStrategy". Keep actions specific to stakeholder role, alignment status, and project type context.',
          ),
        },
        {
          'role': 'user',
          'content': _engagementStrategyPrompt(
            trimmedContext,
            stakeholderName,
            stakeholderRole,
            keyInterest,
            alignmentStatus,
            feedbackSummary,
          ),
        },
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content = OpenAiConfig.extractContent(data);
      if (content.isNotEmpty) {
        final parsed = _decodeJsonSafely(content);
        if (parsed != null) {
          final result = parsed['engagementStrategy']?.toString().trim() ?? '';
          if (result.isNotEmpty) {
            return _stripAsterisks(result);
          }
        }
      }
    } catch (e) {
      debugPrint('generateEngagementStrategy failed: $e');
    }

    return _fallbackEngagementStrategy(
        stakeholderName, keyInterest, alignmentStatus);
  }

  String _engagementStrategyPrompt(
    String context,
    String stakeholderName,
    String stakeholderRole,
    String keyInterest,
    String alignmentStatus,
    String feedbackSummary,
  ) {
    final escaped = _escape(context);
    final feedbackText = feedbackSummary.isEmpty
        ? 'No specific feedback provided yet.'
        : feedbackSummary;

    return '''
Generate a specific engagement strategy for the following stakeholder based on their alignment status and key interest.

Requirements:
- Generate 3-5 specific engagement actions or communication steps
- Each step should be a complete, actionable engagement task
- Use "." bullet format (each line should start with ". ")
- Steps should address their key interest and alignment status
- If alignment status is "Concerned" or "Resistent", include steps to address concerns
- Focus on practical communication and engagement approaches

Return ONLY valid JSON with this exact structure:
{
  "engagementStrategy": ". Engagement step 1\\n. Engagement step 2\\n. Engagement step 3\\n. Engagement step 4\\n. Engagement step 5"
}

Stakeholder: $stakeholderName
Role: $stakeholderRole
Key Interest: $keyInterest
Alignment Status: $alignmentStatus
Feedback Summary: $feedbackText

Project Context:
"""
$escaped
"""
''';
  }

  String _fallbackEngagementStrategy(
    String stakeholderName,
    String keyInterest,
    String alignmentStatus,
  ) {
    final baseStrategy =
        '. Schedule one-on-one meeting to discuss $keyInterest\n. Share relevant project updates and metrics\n. Address any concerns and gather feedback\n. Establish regular communication cadence\n. Document agreed outcomes and next steps';

    if (alignmentStatus == 'Concerned' || alignmentStatus == 'Resistent') {
      return '. Schedule urgent meeting to address concerns\n. Prepare detailed response addressing $keyInterest\n. Provide additional data and context\n. Offer alternative solutions or compromises\n. Follow up within 48 hours to confirm resolution';
    }

    return baseStrategy;
  }

  /// Generate a concise goal title based on description in G1, G2, G3 format
  /// Example: "Establish a comprehensive budget" -> "G1 ESTABLISH BUDGET"
  Future<String> generateGoalTitle({
    required String description,
    required int goalNumber,
    int maxTokens = 50,
    double temperature = 0.3,
  }) async {
    final trimmedDescription = description.trim();
    if (trimmedDescription.isEmpty) return 'Goal $goalNumber';

    if (!OpenAiConfig.isConfigured) {
      // Fallback to simple keyword extraction
      return _fallbackGoalTitle(trimmedDescription, goalNumber);
    }

    final uri = OpenAiConfig.chatUri();
    final headers = OpenAiConfig.headers();

    final prompt = '''
Based on this goal description, generate a concise, impactful title in the format "G$goalNumber [ACTION_KEYWORD]".

Description: $trimmedDescription

Requirements:
- Use G$goalNumber prefix exactly
- Use 2-3 powerful action words in ALL CAPS
- Focus on the main objective/outcome
- Be concise and professional
- Examples: "G1 ESTABLISH BUDGET", "G2 DEVELOP SYSTEM", "G3 LAUNCH PLATFORM"

Return only the title, no additional text.''';

    final body = jsonEncode(OpenAiConfig.wrapBody({
      'model': OpenAiConfig.model,
      'temperature': temperature,
      'max_completion_tokens': maxTokens,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a project management expert. Generate concise, impactful goal titles in the specified format. Return only the title.'
        },
        {
          'role': 'user',
          'content': prompt,
        }
      ],
    }));

    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 401) throw Exception('Invalid API key');
      if (response.statusCode == 429) throw Exception('API quota exceeded');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content =
          OpenAiConfig.extractContent(data);
      final title = content.trim().toUpperCase();

      // Ensure it starts with G[goalNumber]
      if (!RegExp(r'^G\d+\s').hasMatch(title)) {
        return 'G$goalNumber ${title.replaceAll(RegExp(r'[^A-Z\s]'), '').trim()}';
      }

      return title;
    } catch (e) {
      // Fallback to simple keyword extraction
      return _fallbackGoalTitle(trimmedDescription, goalNumber);
    }
  }

  /// Fallback method for goal title generation without AI
  String _fallbackGoalTitle(String description, int goalNumber) {
    final words = description
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(3)
        .map((w) => w.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), ''))
        .where((w) => w.isNotEmpty)
        .toList();

    if (words.isEmpty) return 'Goal $goalNumber';
    return 'G$goalNumber ${words.join(' ')}';
  }

  Future<List<String>> generateScopeTrackingItems({
    required String context,
    required List<String> existingScopeItems,
    int maxTokens = 1000,
  }) async {
    final trimmedContext = context.trim();
    if (trimmedContext.isEmpty) return [];

    if (!OpenAiConfig.isConfigured) return _fallbackScopeItems();

    final existing = existingScopeItems.isEmpty
        ? 'None yet.'
        : existingScopeItems.map((s) => '  - $s').join('\n');

    final prompt = '''Based on the project context below, generate a comprehensive list of scope items.

Project Context:
$trimmedContext

Already tracked scope items:
$existing

IMPORTANT RULES:
- Identify scope items that are NOT already tracked in the "Already tracked" list
- Each scope item should be a specific deliverable, feature, or work product
- Cover all phases: initiation, planning, design, execution, and close-out
- Return the items as a JSON object with a single key "scopeItems" containing an array of strings
- Only include the JSON in your response, nothing else''';

    try {
      final uri = OpenAiConfig.chatUri();
      final headers = OpenAiConfig.headers();

      final body = jsonEncode(OpenAiConfig.wrapBody({
        'model': OpenAiConfig.model,
        'temperature': 0.5,
        'max_completion_tokens': maxTokens,
        'response_format': {'type': 'json_object'},
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a senior project controls engineer. Generate specific, actionable scope tracking items based on project context. Return ONLY valid JSON.'
          },
          {'role': 'user', 'content': prompt},
        ],
      }));

      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body) as Map<String, dynamic>;
        final content =
            parsed['choices']?[0]?['message']?['content']?.toString();
        if (content != null) {
          final result = jsonDecode(_extractJson(content)) as Map<String, dynamic>;
          final items = result['scopeItems'];
          if (items is List) {
            return items
                .map((e) => e.toString().trim())
                .where((s) => s.isNotEmpty)
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('generateScopeTrackingItems failed: $e');
    }

    return _fallbackScopeItems();
  }

  List<String> _fallbackScopeItems() {
    return [
      'Project charter and governance framework',
      'Stakeholder engagement plan',
      'Risk register and mitigation strategies',
      'Work breakdown structure (WBS)',
      'Schedule baseline with critical path',
      'Cost estimate and budget baseline',
      'Scope baseline and change control plan',
      'Quality management plan',
      'Communication and reporting plan',
      'Procurement and contracts management',
    ];
  }
}
