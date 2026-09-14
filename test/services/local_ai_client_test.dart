// Tests for LocalAiClient — the HTTP wrapper that serves AI completions from
// LocalAiEngine when AI_MODE=local. The key guarantee is that in local mode a
// completion request never reaches the wrapped client (no network at all),
// while live mode stays transparent.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ndu_project/services/ai/ai_mode.dart';
import 'package:ndu_project/services/ai/local_ai_client.dart';

/// Records calls and can be told to explode, so a test can assert that the
/// network was or was not touched.
class _RecordingClient extends http.BaseClient {
  _RecordingClient({this.throwOnUse = false});

  final bool throwOnUse;
  int calls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    if (throwOnUse) {
      throw StateError('network must not be used in local AI mode');
    }
    final bytes = utf8.encode('{"choices":[{"message":{"content":"remote"}}]}');
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      200,
      headers: const {'content-type': 'application/json'},
      request: request,
    );
  }
}

Map<String, dynamic> _completionBody() => {
      'model': 'gpt-5.6-terra',
      'messages': [
        {'role': 'user', 'content': 'Summarise the delivery plan.'},
      ],
    };

void main() {
  tearDown(() => AiMode.override = null);

  test('local mode answers completions without touching the network', () async {
    final inner = _RecordingClient(throwOnUse: true);
    final client = LocalAiClient(inner);
    AiMode.override = true;

    final response = await client.post(
      Uri.parse('https://example.invalid/chat/completions'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(_completionBody()),
    );

    expect(response.statusCode, 200);
    expect(inner.calls, 0, reason: 'local mode must not hit the network');

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    expect(decoded['ndu_local_generation'], isTrue);
    final content =
        ((decoded['choices'] as List).first as Map)['message'] as Map;
    expect((content['content'] as String).trim(), isNotEmpty);
  });

  test('live mode delegates to the wrapped client', () async {
    final inner = _RecordingClient();
    final client = LocalAiClient(inner);
    AiMode.override = false;

    final response = await client.post(
      Uri.parse('https://example.invalid/chat/completions'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(_completionBody()),
    );

    expect(inner.calls, 1);
    expect(response.body, contains('remote'));
  });

  test('non-JSON requests are delegated even in local mode', () async {
    final inner = _RecordingClient();
    final client = LocalAiClient(inner);
    AiMode.override = true;

    await client.post(
      Uri.parse('https://example.invalid/telemetry'),
      body: 'not-json',
    );

    expect(inner.calls, 1);
  });

  test('wrap() does not double-wrap a client', () {
    final inner = _RecordingClient();
    final once = LocalAiClient.wrap(inner);
    expect(identical(LocalAiClient.wrap(once), once), isTrue);
  });
}
