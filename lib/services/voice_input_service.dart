import 'dart:async';
import 'package:flutter/foundation.dart';

// Conditional import: web bridge on web, stub on native
import 'voice_input_web_bridge_stub.dart'
    if (dart.library.js_interop) 'voice_input_web_bridge_web.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

/// Cross-platform voice input service.
///
/// - **Web**: Uses the browser's Web Speech API directly via dart:js_interop,
///   bypassing the `speech_to_text` web plugin which has a known issue with
///   `_SpeechRecognition` constructor in release mode.
/// - **Mobile/Desktop**: Uses the `speech_to_text` package which wraps
///   platform-native speech recognition.
class VoiceInputService {
  VoiceInputService._();
  static final VoiceInputService instance = VoiceInputService._();

  // Native (speech_to_text) instance
  stt.SpeechToText? _speech;

  // Web Speech Recognition JS object
  dynamic _webRecognition;

  bool _initialized = false;
  bool _isAvailable = false;
  bool _isListening = false;
  bool _intentionalStop = false;
  String _currentText = '';
  String _previousText = '';
  String _lastErrorMessage = '';

  final StreamController<VoiceResult> _resultController =
      StreamController<VoiceResult>.broadcast();
  final StreamController<VoiceStatus> _statusController =
      StreamController<VoiceStatus>.broadcast();

  // --- Getters ---

  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;
  String get currentText => _currentText;
  String get lastErrorMessage => _lastErrorMessage;
  String get previousText => _previousText;
  Stream<VoiceResult> get onResult => _resultController.stream;
  Stream<VoiceStatus> get onStatusChanged => _statusController.stream;

  // --- Initialization ---

  Future<bool> initialize() async {
    if (_initialized) return _isAvailable;

    if (kIsWeb) {
      return _initializeWeb();
    } else {
      return _initializeNative();
    }
  }

  // ===================== WEB =====================

  Future<bool> _initializeWeb() async {
    try {
      _isAvailable = webVoiceInit(this);
      if (_isAvailable) {
        debugPrint('[VoiceInputService] Web Speech API initialized successfully');
      } else {
        debugPrint('[VoiceInputService] Web Speech API not available. '
            'Use Chrome/Edge/Safari over HTTPS and allow mic access.');
      }
    } catch (e) {
      debugPrint('[VoiceInputService] Web init failed: $e');
      _isAvailable = false;
    }
    _initialized = true;
    return _isAvailable;
  }

  /// Stores the web SpeechRecognition JS object (called from web bridge).
  void setWebRecognition(dynamic recognition) {
    _webRecognition = recognition;
  }

  /// Callback from web bridge: result received
  ///
  /// On web with continuous mode, [isFinal] means the current utterance
  /// is finalized, NOT that the recognition session is done. We must not
  /// stop listening here — the session continues until [onWebEnd] fires
  /// or the user explicitly stops.
  void onWebResult(String text, bool isFinal) {
    _currentText = text;
    final fullText = _buildFullText();
    if (!_resultController.isClosed) {
      // Always emit as non-final during the session so the widget keeps
      // listening. The true session-end is signaled by onWebEnd / stop.
      _resultController.add(VoiceResult(text: fullText, isFinal: false));
    }
  }

  /// Callback from web bridge: error occurred
  void onWebError(String error) {
    debugPrint('[VoiceInputService] Web error: $error');
    // 'no-speech' and 'aborted' are not fatal — don't stop the session.
    // The recognition may auto-restart via onWebEnd.
    if (error == 'no-speech' || error == 'aborted') return;

    _lastErrorMessage = _humanizeWebError(error);
    _isListening = false;
    _intentionalStop = true;
    final fullText = _buildFullText();
    if (!_resultController.isClosed) {
      _resultController.add(VoiceResult(text: fullText, isFinal: true));
    }
    if (!_statusController.isClosed) {
      _statusController.add(VoiceStatus.error);
    }
  }

  /// Converts a raw Web Speech API error code into a user-friendly message.
  String _humanizeWebError(String error) {
    switch (error) {
      case 'not-allowed':
      case 'service-not-allowed':
        return 'Microphone access was blocked. Please allow mic access in your browser settings (click the lock icon in the address bar → Site settings → Microphone → Allow).';
      case 'audio-capture':
        return 'No microphone was found on your device. Please connect a microphone and try again.';
      case 'network':
        return 'Network error during speech recognition. Please check your internet connection and try again.';
      case 'bad-grammar':
      case 'language-not-supported':
        return 'Speech recognition language is not supported. Try using English (US).';
      default:
        return 'Voice input error: $error. Try again, or type manually.';
    }
  }

  /// Callback from web bridge: recognition ended
  ///
  /// Distinguishes between intentional stops (user clicked stop/cancel)
  /// and unexpected ends (silence timeout). On unexpected end with
  /// continuous mode, attempts to auto-restart recognition.
  void onWebEnd() {
    if (_intentionalStop) {
      // stopListening()/cancelListening() already handled state cleanup.
      return;
    }

    // Recognition ended unexpectedly (e.g., silence timeout).
    // Try to auto-restart if we're still supposed to be listening.
    if (_isListening) {
      try {
        final restarted = webVoiceStart(_webRecognition, null);
        if (restarted) {
          debugPrint('[VoiceInputService] Web recognition auto-restarted');
          return;
        }
      } catch (e) {
        debugPrint('[VoiceInputService] Web auto-restart failed: $e');
      }
    }

    // Could not restart — mark session as stopped
    _isListening = false;
    final fullText = _buildFullText();
    if (!_resultController.isClosed) {
      _resultController.add(VoiceResult(text: fullText, isFinal: true));
    }
    if (!_statusController.isClosed) {
      _statusController.add(VoiceStatus.stopped);
    }
  }

  // ===================== NATIVE =====================

  Future<bool> _initializeNative() async {
    try {
      _speech = stt.SpeechToText();
      _isAvailable = await _speech!.initialize(
        onError: _onNativeError,
        onStatus: _onNativeStatus,
        debugLogging: false,
      );
    } catch (e) {
      debugPrint('[VoiceInputService] Native init failed: $e');
      _isAvailable = false;
    }
    _initialized = true;
    return _isAvailable;
  }

  void _onNativeError(SpeechRecognitionError error) {
    debugPrint('[VoiceInputService] Error: ${error.errorMsg} (permanent: ${error.permanent})');
    if (error.permanent) {
      _isListening = false;
      if (!_statusController.isClosed) {
        _statusController.add(VoiceStatus.error);
      }
    }
  }

  void _onNativeStatus(String status) {
    switch (status) {
      case 'listening':
        _isListening = true;
        if (!_statusController.isClosed) {
          _statusController.add(VoiceStatus.listening);
        }
        break;
      case 'notListening':
      case 'done':
        _isListening = false;
        if (!_statusController.isClosed) {
          _statusController.add(VoiceStatus.stopped);
        }
        break;
    }
  }

  void _onNativeResult(SpeechRecognitionResult result) {
    _currentText = result.recognizedWords;
    final fullText = _buildFullText();
    if (!_resultController.isClosed) {
      _resultController.add(VoiceResult(
        text: fullText,
        isFinal: result.finalResult,
      ));
    }
  }

  // ===================== LISTENING =====================

  Future<bool> startListening({
    String existingText = '',
    String? localeId,
  }) async {
    if (_isListening) return true;

    if (!_initialized) {
      await initialize();
    }

    if (!_isAvailable) {
      debugPrint('[VoiceInputService] Speech recognition not available');
      return false;
    }

    _previousText = existingText;
    _currentText = '';
    _intentionalStop = false;

    if (kIsWeb) {
      // On web, verify recognition actually starts before updating state.
      final started = webVoiceStart(_webRecognition, localeId);
      if (!started) {
        debugPrint('[VoiceInputService] Web startListening failed');
        return false;
      }
      _isListening = true;
      if (!_statusController.isClosed) {
        _statusController.add(VoiceStatus.listening);
      }
      return true;
    } else {
      // On native, set state optimistically (the speech_to_text package
      // fires the onStatus callback asynchronously after listen() starts).
      _isListening = true;
      if (!_statusController.isClosed) {
        _statusController.add(VoiceStatus.listening);
      }
      return _startNativeListening(localeId: localeId);
    }
  }

  Future<bool> _startNativeListening({
    String? localeId,
  }) async {
    try {
      await _speech!.listen(
        onResult: _onNativeResult,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 4),
        localeId: localeId,
        partialResults: true,
        cancelOnError: true,
      );
      return true;
    } catch (e) {
      debugPrint('[VoiceInputService] Native startListening failed: $e');
      _isListening = false;
      if (!_statusController.isClosed) {
        _statusController.add(VoiceStatus.stopped);
      }
      return false;
    }
  }

  Future<String> stopListening() async {
    if (!_isListening) return _currentText;

    _intentionalStop = true;

    if (kIsWeb) {
      webVoiceStop(_webRecognition);
    } else {
      try {
        _speech?.stop();
      } catch (e) {
        debugPrint('[VoiceInputService] Native stop error: $e');
      }
    }

    _isListening = false;

    // Emit the final result BEFORE the stopped status so the widget
    // receives the last text update before its subscriptions are cleaned up.
    final fullText = _buildFullText();
    if (!_resultController.isClosed) {
      _resultController.add(VoiceResult(text: fullText, isFinal: true));
    }
    if (!_statusController.isClosed) {
      _statusController.add(VoiceStatus.stopped);
    }

    return fullText;
  }

  Future<void> cancelListening() async {
    if (!_isListening) return;

    _intentionalStop = true;

    if (kIsWeb) {
      webVoiceAbort(_webRecognition);
    } else {
      try {
        _speech?.cancel();
      } catch (e) {
        debugPrint('[VoiceInputService] Native cancel error: $e');
      }
    }

    _isListening = false;
    _currentText = '';
    if (!_statusController.isClosed) {
      _statusController.add(VoiceStatus.stopped);
    }
  }

  String _buildFullText() {
    if (_previousText.isEmpty) return _currentText;
    if (_currentText.isEmpty) return _previousText;

    final separator = _previousText.endsWith(' ') || _previousText.endsWith('\n')
        ? ''
        : ' ';
    return '$_previousText$separator$_currentText';
  }

  void dispose() {
    _intentionalStop = true;
    _resultController.close();
    _statusController.close();
    if (kIsWeb) {
      webVoiceAbort(_webRecognition);
    } else {
      try {
        _speech?.cancel();
      } catch (_) {}
    }
  }
}

/// Result of a voice recognition session
class VoiceResult {
  final String text;
  final bool isFinal;

  const VoiceResult({required this.text, required this.isFinal});
}

/// Status of the voice input service
enum VoiceStatus {
  listening,
  stopped,
  error,
}
