// Tests for LocalAiEngine — the code-level content generator used when the
// app runs with AI_MODE=local. The engine stands in for the model, so these
// tests pin the contract every AI screen depends on:
//   * JSON-requesting prompts get JSON in the shape they declared;
//   * the same request always yields the same answer (determinism);
//   * text-requesting prompts get prose;
//   * autocomplete gets newline-separated continuations.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/services/ai/local_ai_engine.dart';

Map<String, dynamic> _request(String prompt, {bool json = false}) => {
      'model': 'ndu-local-generator',
      'messages': [
        {'role': 'system', 'content': 'You are a project planning assistant.'},
        {'role': 'user', 'content': prompt},
      ],
      if (json) 'response_format': {'type': 'json_object'},
    };

void main() {
  group('LocalAiEngine JSON answers', () {
    test('fills the declared JSON template with non-empty content', () {
      final request = _request(
        'Generate solution options for the project.\n'
        'Return ONLY valid JSON with this exact structure:\n'
        '{"solutions": [{"title": "", "description": "", '
        '"impact": "high|medium|low"}]}',
        json: true,
      );

      final content = LocalAiEngine.completion(request);
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      final solutions = decoded['solutions'] as List;

      expect(solutions, isNotEmpty);
      for (final item in solutions) {
        final map = item as Map<String, dynamic>;
        expect((map['title'] as String).trim(), isNotEmpty);
        expect((map['description'] as String).trim(), isNotEmpty);
        expect(map['impact'], 'high'); // enum hint resolves to a valid value
      }
    });

    test('is deterministic — identical requests give identical answers', () {
      final request = _request(
        'List risks.\nReturn JSON: {"risks": [{"title": "", "reason": ""}]}',
        json: true,
      );
      expect(
        LocalAiEngine.completion(request),
        LocalAiEngine.completion(request),
      );
    });

    test('builds a diagram whose edges reference generated node ids', () {
      final request = _request(
        'Produce a reasoning diagram.\n'
        'Return ONLY valid JSON with this exact structure:\n'
        '{"nodes": [{"id": "unique_id", "label": "Descriptive Label", '
        '"type": "start|objective|action"}], '
        '"edges": [{"from": "source_id", "to": "target_id", '
        '"label": "relationship"}]}',
        json: true,
      );

      final decoded =
          jsonDecode(LocalAiEngine.completion(request)) as Map<String, dynamic>;
      final nodes = (decoded['nodes'] as List).cast<Map>();
      final edges = (decoded['edges'] as List).cast<Map>();

      final nodeIds = nodes.map((n) => n['id']).toSet();
      expect(nodeIds, isNotEmpty);
      for (final edge in edges) {
        expect(nodeIds, contains(edge['from']));
        expect(nodeIds, contains(edge['to']));
      }
    });

    test('falls back to a JSON object with a text field when no template exists',
        () {
      final request = _request('Summarise the delivery plan.', json: true);
      final decoded =
          jsonDecode(LocalAiEngine.completion(request)) as Map<String, dynamic>;
      expect(decoded['text'], isA<String>());
      expect((decoded['text'] as String).trim(), isNotEmpty);
    });
  });

  group('LocalAiEngine prose answers', () {
    test('returns on-topic prose plus the SME disclaimer', () {
      final content = LocalAiEngine.completion(
        _request('Explain the rollout approach for the platform migration.'),
      );
      // Topic is distilled from the prompt ("the rollout approach" → Rollout).
      expect(content, contains('Rollout'));
      expect(content,
          contains('validate with a qualified Subject Matter Expert'));
    });

    test('returns autocomplete suggestions as newline-separated lines', () {
      final content = LocalAiEngine.completion({
        'purpose': 'autocomplete',
        'messages': [
          {
            'role': 'user',
            'content': 'Field: scope\nCurrent draft: "The project"',
          },
        ],
      });
      final lines = content
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      expect(lines.length, 3);
    });

    test('returns the disclaimer for an empty prompt instead of throwing', () {
      expect(LocalAiEngine.completion({'messages': const []}),
          contains('validate with a qualified Subject Matter Expert'));
    });
  });

  group('LocalAiEngine domain-aware content', () {
    test('a cost request yields cost categories and real rates', () {
      final request = _request(
        'Generate cost estimate line items for the programme.\n'
        'Return JSON: {"suggestions": [{"category": "", '
        '"subCategory": "", "description": "", "quantity": 0, '
        '"unit": "", "rate": 0, "rationale": ""}]}',
        json: true,
      );

      final decoded =
          jsonDecode(LocalAiEngine.completion(request)) as Map<String, dynamic>;
      final items = (decoded['suggestions'] as List).cast<Map>();

      final subCategories = items.map((i) => i['subCategory']).toList();
      expect(subCategories, contains('Project Management'));
      for (final item in items) {
        expect(item['rate'] as num, greaterThan(0));
        expect((item['description'] as String).trim(), isNotEmpty);
      }
    });

    test('a risk request yields named risks with distinct descriptions', () {
      final request = _request(
        'List delivery risks.\n'
        'Return JSON: {"risks": [{"title": "", "description": "", '
        '"mitigation": ""}]}',
        json: true,
      );

      final decoded =
          jsonDecode(LocalAiEngine.completion(request)) as Map<String, dynamic>;
      final risks = (decoded['risks'] as List).cast<Map>();

      expect(risks.map((r) => r['title']), contains('Scope Creep'));
      final descriptions = risks.map((r) => r['description']).toSet();
      expect(descriptions.length, risks.length,
          reason: 'each risk should read differently');
    });
  });

  group('LocalAiEngine.chatResponse', () {
    test('wraps the answer in an OpenAI-shaped completion body', () {
      final response = LocalAiEngine.chatResponse(
        _request('Draft the charter summary.'),
      );
      expect(response['ndu_local_generation'], isTrue);
      final choices = response['choices'] as List;
      expect(choices, isNotEmpty);
      final message = (choices.first as Map)['message'] as Map;
      expect(message['role'], 'assistant');
      expect((message['content'] as String).trim(), isNotEmpty);
    });
  });
}
