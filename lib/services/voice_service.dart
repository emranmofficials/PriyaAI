import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'settings_service.dart';

/// Voice interaction: speech-to-text for commands, text-to-speech for
/// spoken feedback.
class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _speechReady = false;
  bool _ttsReady = false;
  bool _listening = false;

  bool get isListening => _listening;
  bool get isAvailable => _speechReady;

  Future<bool> _ensureMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> initSpeech() async {
    if (_speechReady) return true;
    if (!await _ensureMicPermission()) return false;
    try {
      _speechReady = await _speech.initialize(
        onError: (_) => _listening = false,
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            _listening = false;
          }
        },
      );
    } catch (_) {
      _speechReady = false;
    }
    return _speechReady;
  }

  Future<void> initTts({String? lang}) async {
    final targetLang = lang ?? SettingsService.instance.voiceLanguage;
    try {
      await _tts.setLanguage(targetLang);
      await _tts.setSpeechRate(0.5);
      _ttsReady = true;
    } catch (_) {
      try {
        await _tts.setLanguage('en-US');
        _ttsReady = true;
      } catch (_) {
        _ttsReady = false;
      }
    }
  }

  /// Starts a listen session. [onResult] fires on every recognition event
  /// (check `result.finalResult` for the definitive text).
  Future<bool> startListening({
    required void Function(SpeechRecognitionResult result) onResult,
    String? localeId,
  }) async {
    if (!await initSpeech()) return false;
    if (_listening) await stopListening();
    _listening = true;

    final lang = localeId ?? SettingsService.instance.voiceLanguage;
    final locale = lang == 'bn-BD'
        ? 'bn_BD'
        : (lang == 'bn-IN' ? 'bn_IN' : 'en_US');

    try {
      await _speech.listen(
        onResult: onResult,
        localeId: locale,
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
        ),
      );
      return true;
    } catch (_) {
      _listening = false;
      return false;
    }
  }

  Future<void> stopListening() async {
    if (!_listening) return;
    _listening = false;
    try {
      await _speech.stop();
    } catch (_) {}
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await initTts();
    if (!_ttsReady) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
