import 'dart:convert';
import 'package:flutter/services.dart';
import 'app_launcher_service.dart';
import 'screen_automation_service.dart';
import 'voice_service.dart';

/// Declarative Macro Runner Service.
/// 100% mirrors Maya's `builtin_macros.json` and autonomous macro execution pipeline.
class MacroRunnerService {
  MacroRunnerService._();
  static final MacroRunnerService instance = MacroRunnerService._();

  final _automation = ScreenAutomationService.instance;
  final _launcher = AppLauncherService.instance;
  final _voice = VoiceService.instance;

  List<Map<String, dynamic>> _macros = [];
  bool _loaded = false;

  Future<void> init() async {
    if (_loaded) return;
    try {
      final jsonString =
          await rootBundle.loadString('assets/macros/builtin_macros.json');
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final list = data['macros'] as List<dynamic>? ?? [];
      _macros = list.whereType<Map<String, dynamic>>().toList();
      _loaded = true;
    } catch (_) {
      _macros = [];
    }
  }

  List<Map<String, dynamic>> get macros => _macros;

  /// Checks if a natural language [goal] matches a pre-trained macro.
  Map<String, dynamic>? findMatchingMacro(String goal) {
    final q = goal.trim().toLowerCase();
    for (final m in _macros) {
      final name = (m['name'] ?? '').toString().toLowerCase();
      final intent = (m['intent'] ?? '').toString().toLowerCase();
      final aliases = (m['aliases'] as List<dynamic>? ?? []).map((e) => e.toString().toLowerCase());

      // Check name or alias match
      if (q.contains(name) || name.contains(q)) return m;
      for (final alias in aliases) {
        if (q.contains(alias) || alias.contains(q)) return m;
      }

      // Check keyword intent match
      if (q.contains('image') && q.contains('chatgpt') && name.contains('chatgpt image')) {
        return m;
      }
      if (q.contains('ছবি') && q.contains('chatgpt') && name.contains('chatgpt image')) {
        return m;
      }
      if ((q.contains('image') || q.contains('ছবি')) && q.contains('gemini') && name.contains('gemini image')) {
        return m;
      }
      if ((q.contains('video') || q.contains('ভিডিও')) && q.contains('gemini') && name.contains('gemini video')) {
        return m;
      }
      if (q.contains('youtube') || q.contains('গান') || q.contains('গান চালাও')) {
        if (name.contains('youtube play')) return m;
      }
      if (q.contains('whatsapp') || q.contains('মেসেজ')) {
        if (name.contains('whatsapp message')) return m;
      }
      if (q.contains('chatgpt') && (q.contains('pooch') || q.contains('ask') || q.contains('প্রশ্ন')) && name.contains('chatgpt se poochho')) {
        return m;
      }
      if (q.contains('gemini') && (q.contains('pooch') || q.contains('ask') || q.contains('প্রশ্ন')) && name.contains('gemini se poochho')) {
        return m;
      }
    }
    return null;
  }

  /// Executes a macro step-by-step with [parameterValue] (e.g. image prompt).
  Future<bool> executeMacro({
    required Map<String, dynamic> macro,
    String parameterValue = '',
    Function(String status)? onProgress,
  }) async {
    final steps = (macro['steps'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();
    final name = macro['name'] ?? 'Macro';

    onProgress?.call('Starting $name...');
    _voice.speak('ম্যাক্রো শুরু করছি: $name [giggles]');

    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      final tool = step['tool'] as String? ?? '';
      final args = (step['args'] as Map<String, dynamic>?) ?? {};

      onProgress?.call('Step ${i + 1}/${steps.length}: $tool');

      switch (tool) {
        case 'open_app_by_name':
          final appName = args['name'] as String? ?? '';
          if (appName.isNotEmpty) {
            await _launcher.launchAppByName(appName);
          }
          break;

        case 'wait':
          final seconds = (args['seconds'] as num?)?.toInt() ?? 2;
          await Future.delayed(Duration(seconds: seconds));
          break;

        case 'tap_text':
          final text = args['text'] as String? ?? '';
          final optional = args['_optional'] as bool? ?? false;
          if (text.isNotEmpty) {
            await _automation.tapText(text, optional: optional);
          }
          break;

        case 'type_text':
          var rawText = args['text'] as String? ?? '';
          // Inject prompt parameter if present (e.g. {image_prompt})
          rawText = rawText.replaceAll(RegExp(r'\{[a-zA-Z0-9_]+\}'), parameterValue);
          if (rawText.isNotEmpty) {
            await _automation.typeText(rawText);
          }
          break;

        case 'wait_for_screen_text':
          final text = args['text'] as String? ?? '';
          final mode = args['mode'] as String? ?? 'appear';
          final timeout = (args['timeout_seconds'] as num?)?.toInt() ?? 60;
          if (text.isNotEmpty) {
            await _automation.waitForScreenText(text, mode: mode, timeoutSeconds: timeout);
          }
          break;

        case 'go_back':
          await _automation.pressBack();
          break;

        case 'press_enter':
          await _automation.pressEnter();
          break;

        default:
          break;
      }
    }

    onProgress?.call('Completed $name successfully!');
    _voice.speak('কাজটা সফলভাবে সম্পন্ন হয়েছে সোনা! [happy]');
    return true;
  }
}
