import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Service wrapping native Android/iOS Speech-to-Text engine.
/// 100% Free, zero cloud API fees, using on-device Speech Services.
class VoiceNavigationService {
  VoiceNavigationService({stt.SpeechToText? speech})
      : _speech = speech ?? stt.SpeechToText();

  final stt.SpeechToText _speech;
  bool _isInitialized = false;
  String _selectedLocaleId = 'ar_IQ';

  bool get isInitialized => _isInitialized;
  bool get isListening => _speech.isListening;
  bool get isAvailable => _speech.isAvailable;

  /// Initializes native speech recognition engine.
  Future<bool> initialize({void Function(String status)? onStatus}) async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speech.initialize(
        onError: (err) {
          debugPrint('Darb Voice Recognition Error: ${err.errorMsg}');
        },
        onStatus: (status) {
          debugPrint('Darb Voice Recognition Status: $status');
          onStatus?.call(status);
        },
        debugLogging: kDebugMode,
      );

      if (_isInitialized) {
        final locales = await _speech.locales();
        final localeIds = locales.map((l) => l.localeId).toList();
        debugPrint('Available Voice Locales: $localeIds');

        // Prefer Iraqi Arabic, then general Arabic, then default
        if (localeIds.any((id) => id.toLowerCase().contains('ar_iq') || id.toLowerCase().contains('ar-iq'))) {
          _selectedLocaleId = localeIds.firstWhere((id) => id.toLowerCase().contains('ar_iq') || id.toLowerCase().contains('ar-iq'));
        } else if (localeIds.any((id) => id.toLowerCase().startsWith('ar'))) {
          _selectedLocaleId = localeIds.firstWhere((id) => id.toLowerCase().startsWith('ar'));
        }
      }
      return _isInitialized;
    } catch (e) {
      debugPrint('Darb Voice Init Exception: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Start listening for voice commands with sentence dictation mode.
  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
    void Function(double level)? onSoundLevelChange,
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 5),
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return false;
    }

    if (_speech.isListening) {
      await _speech.stop();
    }

    try {
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        onSoundLevelChange: onSoundLevelChange,
        localeId: _selectedLocaleId,
        listenFor: listenFor,
        pauseFor: pauseFor,
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
      );
      return true;
    } catch (e) {
      debugPrint('Darb Voice Listen Exception: $e');
      return false;
    }
  }

  /// Stop listening explicitly.
  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  /// Cancel listening session.
  Future<void> cancelListening() async {
    await _speech.cancel();
  }
}
