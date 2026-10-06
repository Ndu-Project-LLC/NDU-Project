// End-to-end check for local (no-AI) generation mode.
//
// This drives the *real* service the screens use — OpenAiServiceSecure — with
// AI_MODE=local semantics, and asserts that representative AI surfaces return
// usable content while the network is completely unavailable. The injected
// client throws on any use, so a passing test proves the content was generated
// in code, exactly as the app would when no provider is reachable.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ndu_project/services/ai/ai_mode.dart';
import 'package:ndu_project/services/ai/local_ai_client.dart';
import 'package:ndu_project/services/openai_service_secure.dart';

/// Fails the test if anything actually tries to reach a provider.
class _OfflineClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw StateError(
        'local AI mode must not perform network I/O (${request.url})');
  }
}

void main() {
  late OpenAiServiceSecure ai;

  setUp(() {
    AiMode.override = true;
    ai = OpenAiServiceSecure(client: LocalAiClient(_OfflineClient()));
  });

  tearDown(() => AiMode.override = null);

  test('generateCompletion returns prose with no provider', () async {
    final text = await ai.generateCompletion(
      'Draft a short charter summary for the platform migration project.',
    );
    expect(text.trim(), isNotEmpty);
  });

  test('generateFepSectionText returns a section write-up', () async {
    final text = await ai.generateFepSectionText(
      section: 'Risk Management',
      context: 'A 12-month platform migration for a construction programme.',
    );
    expect(text.trim(), isNotEmpty);
  });

  test('generateProjectScope returns structured scope lists', () async {
    final scope = await ai.generateProjectScope(
      context: 'Platform migration with data cleanup and training.',
    );
    expect(scope['in'], isNotNull);
    expect(scope['out'], isNotNull);
  });

  test('generateAcceptanceCriteria returns criteria text', () async {
    final text = await ai.generateAcceptanceCriteria(
      context: 'Software delivery programme.',
      requirementText: 'The system shall export reports to CSV.',
    );
    expect(text.trim(), isNotEmpty);
  });

  test('generateScopeTrackingItems returns tracked items', () async {
    final items = await ai.generateScopeTrackingItems(
      context: 'Platform migration programme.',
      existingScopeItems: const [],
    );
    expect(items, isNotEmpty);
    expect(items.first.trim(), isNotEmpty);
  });

  test('generateGoalTitle returns a goal title', () async {
    final title = await ai.generateGoalTitle(
      description: 'Establish a comprehensive delivery budget',
      goalNumber: 1,
    );
    expect(title.trim(), isNotEmpty);
  });

  test('generateWbsStructure returns a work breakdown', () async {
    final structure = await ai.generateWbsStructure(
      projectName: 'NDU Platform Migration',
      projectObjective: 'Migrate the platform with minimal disruption.',
      dimension: 'Deliverable',
    );
    expect(structure, isNotEmpty);
  });

  test('the local completion body is valid OpenAI-shaped JSON', () async {
    // Confirm the transport contract as well: callers decode this shape.
    final body = jsonEncode({
      'model': 'gpt-5.6-terra',
      'messages': [
        {'role': 'user', 'content': 'Summarise the delivery plan.'},
      ],
    });
    final response = await LocalAiClient.wrap(_OfflineClient()).post(
      Uri.parse('https://example.invalid/chat/completions'),
      headers: const {'Content-Type': 'application/json'},
      body: body,
    );
    expect(response.statusCode, 200);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    expect(decoded['ndu_local_generation'], isTrue);
  });
}
