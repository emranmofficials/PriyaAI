import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'settings_service.dart';

/// Voice interaction: speech-to-text for commands, and emotional text-to-speech
/// with dynamic pitch, cadence, and vocal styling matching Maya's soul.
class VoiceService extends ChangeNotifier {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  static const MethodChannel _nativeChannel =
      MethodChannel('com.privateagent/accessibility');

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _speechReady = false;
  bool _ttsReady = false;
  bool _listening = false;
  bool _speaking = false;

  bool get isListening => _listening;
  bool get isSpeaking => _speaking;
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
        onError: (_) {
          _listening = false;
          notifyListeners();
        },
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            _listening = false;
            notifyListeners();
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
      // 1. Explicitly select Google TTS Engine for neural WaveNet voices if present
      final engines = await _tts.getEngines;
      if (engines is List) {
        final engineList = engines.map((e) => e.toString().toLowerCase()).toList();
        if (engineList.contains('com.google.android.tts')) {
          await _tts.setEngine('com.google.android.tts');
        }
      }

      await _tts.setLanguage(targetLang);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.26);
      await _tts.setSpeechRate(0.46);

      _tts.setStartHandler(() {
        _speaking = true;
        notifyListeners();
      });
      _tts.setCompletionHandler(() {
        _speaking = false;
        notifyListeners();
      });
      _tts.setErrorHandler((_) {
        _speaking = false;
        notifyListeners();
      });

      // Select female voice if available on Android
      await _configureFemaleVoice(targetLang);

      _ttsReady = true;
    } catch (_) {
      try {
        await _tts.setLanguage('en-US');
        await _tts.setPitch(1.22);
        await _tts.setSpeechRate(0.48);
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

        final matchingVoices = voices.whereType<Map>().where((v) {
          final locale = (v['locale'] ?? '').toString().toLowerCase();
          return locale.startsWith(langPrefix);
        }).toList();

        if (matchingVoices.isEmpty) return;

        bool isMale(String name) {
          final n = name.toLowerCase();
          return n.contains('male') ||
              n.contains('guy') ||
              n.contains('boy') ||
              n.contains('man') ||
              n.contains('bif') ||
              n.contains('bad');
        }

        // 1. Priority: Google Neural Network Female Voice (WaveNet quality)
        Map? bestVoice;
        for (final v in matchingVoices) {
          final name = (v['name'] ?? '').toString().toLowerCase();
          if (isMale(name)) continue;
          if (name.contains('ban-network') || name.contains('bin-network')) {
            bestVoice = v;
            break;
          }
        }

        // 2. Priority: Explicit female tag
        bestVoice ??= matchingVoices.firstWhere(
          (v) {
            final name = (v['name'] ?? '').toString().toLowerCase();
            if (isMale(name)) return false;
            return name.contains('female') ||
                name.contains('woman') ||
                name.contains('girl');
          },
          orElse: () => <dynamic, dynamic>{},
        );
        if (bestVoice.isEmpty) bestVoice = null;

        // 3. Priority: High-quality local female voice (ban-local or bin-local)
        bestVoice ??= matchingVoices.firstWhere(
          (v) {
            final name = (v['name'] ?? '').toString().toLowerCase();
            if (isMale(name)) return false;
            return name.contains('ban') || name.contains('bin');
          },
          orElse: () => <dynamic, dynamic>{},
        );
        if (bestVoice.isEmpty) bestVoice = null;

        // Apply best female voice if found
        if (bestVoice != null) {
          final voiceMap = Map<String, String>.from(
            bestVoice.map((k, v) => MapEntry(k.toString(), v.toString())),
          );
          await _tts.setVoice(voiceMap);
        }
      }
    } catch (_) {}
  }

  Future<bool> startListening({
    required Function(SpeechRecognitionResult) onResult,
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    if (!await initSpeech()) return false;
    if (_listening) return true;

    try {
      final lang = SettingsService.instance.voiceLanguage;
      await _speech.listen(
        onResult: onResult,
        localeId: lang,
        listenMode: ListenMode.confirmation,
        pauseFor: pauseFor,
        cancelOnError: true,
      );
      _listening = true;
      notifyListeners();
      return true;
    } catch (_) {
      _listening = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> stopListening() async {
    _listening = false;
    notifyListeners();
    try {
      await _speech.stop();
    } catch (_) {}
  }

  /// Extracts emotion tags from Maya's bracketed notation (e.g. [happy], [giggles])
  /// and cleans the speech buffer so the TTS synthesizer pronounces it naturally.
  (String, String) _extractEmotionAndClean(String raw) {
    var text = raw;
    String emotion = '';

    final tagRegex = RegExp(r'\[([a-zA-Z,\s]+)\]');
    final matches = tagRegex.allMatches(text);
    if (matches.isNotEmpty) {
      emotion = matches.map((m) => m.group(1) ?? '').join(' ').toLowerCase();
    }

    // Strip bracketed emotional tags
    text = text.replaceAll(tagRegex, '');

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

    return (text, emotion);
  }

  Future<void> speak(String rawText) async {
    final (clean, emotion) = _extractEmotionAndClean(rawText);
    if (clean.isEmpty) return;

    final settings = SettingsService.instance;
    final persona = settings.activePersona; // maya, friday, venom

    // 1. Try ElevenLabs studio-quality voice if API key is present
    final elevenKey = settings.elevenLabsApiKey.trim();
    if (elevenKey.isNotEmpty) {
      final success = await _speakWithElevenLabs(clean, elevenKey);
      if (success) return;
    }

    // 2. Seamless fallback to Neural TTS with dynamic Maya modulation
    await initTts();
    if (!_ttsReady) return;

    try {
      await stopSpeaking();

      // Configure emotion-based pitch & rate
      double targetPitch = 1.25;
      double targetRate = 0.46;

      if (persona == 'friday') {
        targetPitch = 1.0;
        targetRate = 0.52;
      } else if (persona == 'venom') {
        targetPitch = 0.70;
        targetRate = 0.43;
      } else {
        // Maya / Priya
        if (emotion.contains('happy') || emotion.contains('giggle') || emotion.contains('excite')) {
          targetPitch = 1.36;
          targetRate = 0.50;
        } else if (emotion.contains('soft') || emotion.contains('whisper') || emotion.contains('shy')) {
          targetPitch = 1.15;
          targetRate = 0.38;
        } else if (emotion.contains('cry') || emotion.contains('sad') || emotion.contains('break')) {
          targetPitch = 1.18;
          targetRate = 0.40;
        } else if (emotion.contains('teas') || emotion.contains('playful')) {
          targetPitch = 1.30;
          targetRate = 0.48;
        }
      }

      await _tts.setPitch(targetPitch);
      await _tts.setSpeechRate(targetRate);

      _speaking = true;
      notifyListeners();
      await _tts.speak(clean);
    } catch (_) {
      _speaking = false;
      notifyListeners();
    }
  }

  Future<bool> _speakWithElevenLabs(String text, String apiKey) async {
    try {
      await stopSpeaking();
      final voiceId = SettingsService.instance.elevenLabsVoiceId.isNotEmpty
          ? SettingsService.instance.elevenLabsVoiceId
          : 'XB0fDUnXU5powFXDhCwa'; // Charlotte

      final uri = Uri.parse(
        'https://api.elevenlabs.io/v1/text-to-speech/$voiceId?output_format=mp3_44100_128',
      );

      final headers = {
        'xi-api-key': apiKey,
        'Content-Type': 'application/json',
      };

      final body = jsonEncode({
        'text': text,
        'model_id': 'eleven_multilingual_v2',
        'voice_settings': {
          'stability': 0.5,
          'similarity_boost': 0.8,
          'use_speaker_boost': true,
        },
      });

      final response = await http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/eleven_speech.mp3');
        await file.writeAsBytes(response.bodyBytes);

        _speaking = true;
        notifyListeners();

        // Play via native Android MediaPlayer bridge
        await _nativeChannel.invokeMethod('playAudio', {'path': file.path});

        _speaking = false;
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> stopSpeaking() async {
    _speaking = false;
    notifyListeners();
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
