/// Stub implementation for non-web platforms.
/// All functions return false/no-op since the Web Speech API is not available.
import 'voice_input_service.dart';

/// Creates a SpeechRecognition JS object. No-op on non-web.
bool webVoiceInit(VoiceInputService service) => false;

/// Starts listening on web SpeechRecognition. No-op on non-web.
bool webVoiceStart(dynamic recognition, String? localeId) => false;

/// Stops listening on web SpeechRecognition. No-op on non-web.
void webVoiceStop(dynamic recognition) {}

/// Aborts listening on web SpeechRecognition. No-op on non-web.
void webVoiceAbort(dynamic recognition) {}
