/// [LocalAiClient] — an [http.Client] that answers AI completions in code.
///
/// When [AiMode.isLocal] is on, every AI chat-completion request is answered
/// locally by [LocalAiEngine] and never touches the network. Any non-AI
/// request (and every request while in live mode) is passed straight through
/// to the wrapped client, so this wrapper is safe to install unconditionally.
///
/// Install it wherever the app creates an AI HTTP client:
///
///   final client = LocalAiClient(http.Client());
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_mode.dart';
import 'local_ai_engine.dart';

class LocalAiClient extends http.BaseClient {
  LocalAiClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  /// Small artificial latency so AI loading states remain visible and
  /// deterministic UI tests can observe them. Kept well below any caller
  /// timeout.
  static const Duration latency = Duration(milliseconds: 150);

  /// Wraps [client] so AI completions are served locally. Returns [client]
  /// unchanged when it is already a [LocalAiClient].
  static http.Client wrap(http.Client client) {
    if (client is LocalAiClient) return client;
    return LocalAiClient(client);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!AiMode.isLocal) return _inner.send(request);

    final body = _readJsonBody(request);
    if (body == null) return _inner.send(request);

    final payload = LocalAiEngine.chatResponse(body);
    final bytes = utf8.encode(jsonEncode(payload));
    if (latency > Duration.zero) await Future<void>.delayed(latency);

    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      200,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json; charset=utf-8'},
      request: request,
    );
  }

  /// Reads the JSON body of [request] when it is a buffered [http.Request]
  /// (which is what `client.post(..., body: jsonEncode(...))` produces).
  /// Streamed/multipart requests are not AI completions, so they return null
  /// and are delegated.
  Map<String, dynamic>? _readJsonBody(http.BaseRequest request) {
    if (request is! http.Request) return null;
    final raw = request.body;
    if (raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Not JSON — not an AI completion request.
    }
    return null;
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
