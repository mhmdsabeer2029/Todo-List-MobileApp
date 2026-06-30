import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';

/// Live, streaming speech-to-text service.
///
/// Unlike the old implementation, this exposes every partial result
/// immediately via [onPartial] so the UI can render words as they're
/// spoken, with no buffering delay.
class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;
  bool _listening = false;
  String _lastWords = '';

  bool get isAvailable => _available;
  bool get isListening => _listening;
  String get lastWords => _lastWords;

  /// Called on every recognition update (partial AND final), as fast as
  /// the platform speech engine delivers them — usually every 100-300ms.
  void Function(String text, bool isFinal)? onPartial;

  /// Called if listening stops due to an error.
  void Function(String message)? onError;

  /// Called when listening stops (manually, on silence, or on completion).
  void Function()? onDone;

  Future<bool> initialize() async {
    final permission = await Permission.microphone.request();
    if (permission != PermissionStatus.granted) {
      _available = false;
      return false;
    }

    _available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          if (_listening) {
            _listening = false;
            onDone?.call();
          }
        }
      },
      onError: (SpeechRecognitionError error) {
        _listening = false;
        onError?.call(error.errorMsg);
        onDone?.call();
      },
      debugLogging: false,
    );
    return _available;
  }

  /// Starts continuous, low-latency listening. Results stream live through
  /// [onPartial] — call this once and read updates from the callback rather
  /// than awaiting a single final value.
  Future<void> startListening({String localeId = 'ar-EG'}) async {
    if (!_available) {
      final initialized = await initialize();
      if (!initialized) {
        onError?.call('Microphone permission denied');
        return;
      }
    }

    if (_speech.isListening) {
      await _speech.stop();
    }

    _lastWords = '';
    _listening = true;

    try {
      await _speech.listen(
        localeId: localeId,
        // Long window so the user can keep talking; pauseFor is short so
        // we still get snappy partials and a fast natural stop on silence.
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        onResult: (result) {
          _lastWords = result.recognizedWords;
          // Fire immediately — every partial is forwarded with zero delay.
          onPartial?.call(_lastWords, result.finalResult);
          if (result.finalResult) {
            _listening = false;
            onDone?.call();
          }
        },
      );
    } catch (e) {
      _listening = false;
      onError?.call(e.toString());
      onDone?.call();
    }
  }

  /// Stops listening and finalizes whatever has been recognized so far.
  Future<String> stop() async {
    if (_listening || _speech.isListening) {
      await _speech.stop();
      _listening = false;
    }
    return _lastWords.trim();
  }

  /// Cancels listening and discards the current result.
  Future<void> cancel() async {
    if (_listening || _speech.isListening) {
      await _speech.cancel();
      _listening = false;
      _lastWords = '';
    }
  }

  /// One-shot convenience wrapper kept for backward compatibility: starts
  /// listening and resolves once a final result (or timeout) is reached.
  ///
  /// Temporarily swaps in its own [onPartial]/[onDone]/[onError] handlers
  /// and restores whatever was set beforehand once done, so this doesn't
  /// permanently clobber a caller's own live-update handlers (e.g. a UI
  /// that wants to render partial results as the user speaks) if they call
  /// this convenience method afterward.
  Future<String?> listen({String localeId = 'ar-EG'}) async {
    final completer = Completer<String?>();
    final previousOnPartial = onPartial;
    final previousOnDone = onDone;
    final previousOnError = onError;

    void restore() {
      onPartial = previousOnPartial;
      onDone = previousOnDone;
      onError = previousOnError;
    }

    onPartial = (text, isFinal) {
      if (isFinal) {
        if (!completer.isCompleted) completer.complete(text.trim());
      }
    };
    onDone = () {
      if (!completer.isCompleted) completer.complete(_lastWords.trim());
    };
    onError = (_) {
      if (!completer.isCompleted) completer.complete(null);
    };
    await startListening(localeId: localeId);
    final result = await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        stop();
        return _lastWords.trim().isEmpty ? null : _lastWords.trim();
      },
    );
    restore();
    return result;
  }
}
