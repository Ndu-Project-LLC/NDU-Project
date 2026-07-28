/// Web implementation of the voice input bridge using dart:js_interop
/// and dart:js_interop_unsafe to access the browser's Web Speech API.
///
/// This file is only imported when compiling for web (conditional import
/// based on dart.library.js_interop).
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';
import 'voice_input_service.dart';

/// Creates a SpeechRecognition JS object using the browser's Web Speech API.
/// Returns true if the API is available and the object was created.
bool webVoiceInit(VoiceInputService service) {
  try {
    final globalThis = globalContext;

    // Check for SpeechRecognition support (standard + webkit prefix)
    final hasStandard = globalThis.hasProperty('SpeechRecognition'.toJS).toDart;
    final hasWebkit = globalThis.hasProperty('webkitSpeechRecognition'.toJS).toDart;

    if (!hasStandard && !hasWebkit) {
      debugPrint('[VoiceInputWeb] Browser does not support SpeechRecognition. '
          'Please use Chrome, Edge, or Safari.');
      return false;
    }

    // Create the recognition instance using 'new' operator
    JSObject recognition;
    if (hasStandard) {
      // Use new operator via dart:js_interop — construct SpeechRecognition
      recognition = (globalThis['SpeechRecognition'] as JSFunction)
          .callAsConstructor() as JSObject;
    } else {
      recognition = (globalThis['webkitSpeechRecognition'] as JSFunction)
          .callAsConstructor() as JSObject;
    }

    // Configure recognition
    recognition['continuous'] = true.toJS;
    recognition['interimResults'] = true.toJS;
    // Use browser locale, fallback to en-US
    String locale = 'en-US';
    try {
      final nav = globalThis['navigator'] as JSObject;
      final lang = (nav['language'] as JSString).toDart;
      if (lang.isNotEmpty) locale = lang;
    } catch (_) {}
    recognition['lang'] = locale.toJS;

    // Wire up onresult handler
    recognition['onresult'] = ((JSObject event) {
      try {
        final results = event['results'] as JSObject;
        final length = (results['length'] as JSNumber).toDartInt;

        String interimTranscript = '';
        String finalTranscript = '';

        for (int i = 0; i < length; i++) {
          final result = results['$i'] as JSObject;
          final isFinal = (result['isFinal'] as JSBoolean).toDart;
          final firstAlternative = result['0'] as JSObject;
          final transcript =
              (firstAlternative['transcript'] as JSString).toDart;

          if (isFinal) {
            finalTranscript += transcript;
          } else {
            interimTranscript += transcript;
          }
        }

        final text =
            finalTranscript.isNotEmpty ? finalTranscript : interimTranscript;
        final isFinalResult = finalTranscript.isNotEmpty;

        service.onWebResult(text, isFinalResult);
      } catch (e) {
        debugPrint('[VoiceInputWeb] onresult error: $e');
      }
    }).toJS;

    // Wire up onerror handler
    recognition['onerror'] = ((JSObject event) {
      try {
        final error = (event['error'] as JSString).toDart;
        service.onWebError(error);
      } catch (e) {
        service.onWebError('unknown');
      }
    }).toJS;

    // Wire up onend handler
    recognition['onend'] = ((JSObject _) {
      service.onWebEnd();
    }).toJS;

    // Store on service
    service.setWebRecognition(recognition);
    return true;
  } catch (e) {
    debugPrint('[VoiceInputWeb] webVoiceInit failed: $e');
    return false;
  }
}

/// Starts listening on the web SpeechRecognition object.
bool webVoiceStart(dynamic recognition, String? localeId) {
  try {
    if (recognition == null) return false;
    final rec = recognition as JSObject;
    if (localeId != null) {
      rec['lang'] = localeId.toJS;
    }
    rec.callMethod('start'.toJS);
    return true;
  } catch (e) {
    debugPrint('[VoiceInputWeb] startListening failed: $e');
    return false;
  }
}

/// Stops listening on the web SpeechRecognition object.
void webVoiceStop(dynamic recognition) {
  try {
    if (recognition == null) return;
    (recognition as JSObject).callMethod('stop'.toJS);
  } catch (e) {
    debugPrint('[VoiceInputWeb] stop failed: $e');
  }
}

/// Aborts listening on the web SpeechRecognition object.
void webVoiceAbort(dynamic recognition) {
  try {
    if (recognition == null) return;
    (recognition as JSObject).callMethod('abort'.toJS);
  } catch (e) {
    debugPrint('[VoiceInputWeb] abort failed: $e');
  }
}
