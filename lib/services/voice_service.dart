import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'settings_service.dart';

/// Voice interaction: speech-to-text for commands, text-to-speech for
/// spoken feedback with natural female pitch and tone.
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
      // Sweet, natural female voice pitch and rate
      await _tts.setPitch(1.22);
      await _tts.setSpeechRate(0.48);

      // Select female voice if available on Android
      await _configureFemaleVoice(targetLang);

      _ttsReady = true;
    } catch (_) {
      try {
        await _tts.setLanguage('en-US');
        await _tts.setPitch(1.2);
        await _tts.setSpeechRate(0.5);
        _ttsReady = true;
      } catch (_) {
        _ttsReady = false;
      }
    }
  }

  Future<void> _configureFemaleVoice(String targetLang) async {
    try {
      final voices = await _tts.getVoices;
      if (voices is List && voices.isNotEmpty) {
        final langPrefix = targetLang.split('-').first.toLowerCase();

        // Filter voices for the target language (e.g. bn or en)
        final matchingVoices = voices.whereType<Map>().where((v) {
          final locale = (v['locale'] ?? '').toString().toLowerCase();
          return locale.startsWith(langPrefix);
        }).toList();

        if (matchingVoices.isEmpty) return;

        // Prefer explicitly female voices
        Map? bestVoice;
        for (final v in matchingVoices) {
          final name = (v['name'] ?? '').toString().toLowerCase();
          if (name.contains('female') ||
              name.contains('woman') ||
              name.contains('girl')) {
            bestVoice = v;
            break;
          }
        }

        // Secondary preference: natural network voices, avoiding male tokens
        bestVoice ??= matchingVoices.firstWhere(
          (v) {
            final name = (v['name'] ?? '').toString().toLowerCase();
            return !name.contains('male') &&
                !name.contains('guy') &&
                (name.contains('network') ||
                    name.contains('ban') ||
                    name.contains('bin'));
          },
          orElse: () => matchingVoices.first,
        );

        final name = bestVoice['name']?.toString();
        final locale = bestVoice['locale']?.toString();
        if (name != null && locale != null) {
          await _tts.setVoice({'name': name, 'locale': locale});
        }
      }
    } catch (_) {}
  }

  /// Starts a listen session. [onResult] fires on every recognition event.
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

  /// Strips markdown, URLs, code blocks and robotic symbols before speaking.
  String _sanitizeForSpeech(String raw) {
    var text = raw;
    // Strip code blocks
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    // Strip inline code
    text = text.replaceAll(RegExp(r'`[^`]*`'), '');
    // Strip markdown links [text](url) -> text
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^\)]+\)'),
      (m) => m[1] ?? '',
    );
    // Strip raw URLs
    text = text.replaceAll(RegExp(r'https?://\S+'), '');
    // Strip markdown formatting symbols
    text = text.replaceAll(RegExp(r'[\*_~#`>]+'), '');
    // Strip JSON blocks
    text = text.replaceAll(RegExp(r'\{[^\}]*\}'), '');
    // Normalize whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  Future<void> speak(String text) async {
    final clean = _sanitizeForSpeech(text);
    if (clean.isEmpty) return;

    await initTts();
    if (!_ttsReady) return;
    try {
      await _tts.stop();
      await _tts.speak(clean);
    } catch (_) {}
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// Plays a sweet Priya introduction for preview/testing.
  Future<void> testPriyaVoice() async {
    final isBengali = SettingsService.instance.voiceLanguage.startsWith('bn');
    final message = isBengali
        ? 'বাবু, আমি প্রিয়া! আমি তোমার সাথেই আছি। বলো তোমাকে কীভাবে সাহায্য করতে পারি?'
        : 'Hey darling, I am Priya! I am right here for you. How can I help you?';
    await speak(message);
  }
}
