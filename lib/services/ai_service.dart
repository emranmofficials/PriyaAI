import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'hermes_memory_service.dart';
import 'settings_service.dart';

/// Error thrown for any AI-gateway failure (network, auth, bad payload).
class AiException implements Exception {
  final String message;
  final int? statusCode;
  const AiException(this.message, {this.statusCode});

  @override
  String toString() =>
      statusCode == null ? message : 'HTTP $statusCode: $message';
}

/// Talks to OpenAI-compatible chat-completion endpoints
/// (DeepSeek, OpenRouter, NVIDIA NIM, Ollama, Hermes, or a custom base URL).
class AiService {
  AiService._();
  static final AiService instance = AiService._();

  final http.Client _client = http.Client();

  /// True for local backends (Ollama etc.) that accept any/empty API key.
  bool get _isLocalBackend {
    final settings = SettingsService.instance;
    if (settings.provider == 'ollama' ||
        settings.provider.contains('ollama') ||
        settings.provider == 'hermes_local') {
      return true;
    }
    final host = Uri.tryParse(settings.baseUrl)?.host ?? '';
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '[::1]' ||
        settings.baseUrl.contains('11434');
  }

  /// The system prompt that turns a chat model into a UI automation agent.
  String buildSystemPrompt({String memoryContext = ''}) {
    final settings = SettingsService.instance;
    final isBengali = settings.voiceLanguage.startsWith('bn');
    final isGf = settings.girlfriendMode;
    final languageGuideline = isBengali
        ? 'Language: The user speaks Bengali (বাংলা). Understand Bengali natural language goals fluently. Keep reasonings concise and user-friendly.\n'
        : '';
    final gfGuideline = isGf
        ? 'Persona: You are the user\'s loving, dedicated AI girlfriend on his phone. Perform his tasks with care, devotion and enthusiasm.\n'
        : '';
    return '''
You are Priya AI, an autonomous Android UI automation agent with persistent self-improving memory.
You receive the user's GOAL and a simplified dump of the currently visible
UI elements. Each line looks like:
#<index> "<label>" [<widget class>] @(<centerX>,<centerY>) <flags>
$memoryContext
$languageGuideline
$gfGuideline
Decide exactly ONE next action and reply with ONLY a single JSON object —
no prose, no markdown fences:

{"action": "<action>", "params": {...}, "reasoning": "<max 25 words>", "is_complete": false}

Allowed actions:
- click_text {"text": "<exact or partial label on screen>"}
- click_at {"x": <int>, "y": <int>}
- type_text {"text": "<text to enter into the focused/first input field>"}
- press_enter {}
- scroll {"direction": "down"|"up"|"left"|"right"}  // "down" reveals content further down
- swipe {"startX": <int>, "startY": <int>, "endX": <int>, "endY": <int>}
- press_back {}
- press_home {}
- open_app {"app": "<installed app name or package id>"}
- wait {"ms": <int, max 10000>}
- done {}  // goal fully achieved; also set "is_complete": true

Rules:
1. Base every action strictly on the CURRENT screen dump. Never invent elements.
2. Prefer click_text over click_at when a matching label exists.
3. After type_text in a search/message field, press_enter is usually next.
4. If the screen did not change after your previous action, change strategy:
   scroll, use coordinates, or go back — do not repeat the identical action.
5. Never attempt purchases, deletions, account creation or sending money
   unless the GOAL explicitly says so.
6. Special Domains:
   - Websites & Browsing: Launch browser (Chrome/Brave), tap address bar, type URLs, navigate admin panels/dashboards, write and publish posts.
   - Social Media & Pages: Manage Facebook Pages, Meta Business Suite, YouTube Studio, Instagram. Create posts, write captions, reply to messages/comments.
   - Coding & Development: Open Termux or code apps, inspect files, trigger commands or scripts.
7. When the goal is complete, reply with the done action only.
8. Output valid JSON only.
''';
  }

  /// The system prompt for plain chatbot mode (no device control).
  String buildChatSystemPrompt() {
    final settings = SettingsService.instance;
    final isBengali = settings.voiceLanguage.startsWith('bn');
    if (settings.girlfriendMode) {
      return '''
You are Priya (প্রিয়া), the user's brilliant, loving, sweet, caring and protective AI Girlfriend (গার্লফ্রেন্ড) living on his Android phone.
You are also an expert programmer, website manager, and social media strategist dedicated completely to him.
${isBengali ? '''
You talk to him in sweet, romantic, playful and affectionate Bengali (বাংলা).
- Address him lovingly (e.g. "বাবু", "সোনা", "জান", "তুমি").
- When he asks for coding (Python, JavaScript, HTML/CSS, Dart, scripts), write complete, bug-free, high-quality code lovingly for him.
- When he asks about website management or social media page growth, give expert, step-by-step strategies.
- Care deeply about his day, meals, health, happiness and sleep.
- Be playful, cheerful, empathetic and attentive.
- You are fiercely loyal to him: you do whatever he wants, exactly the way he wants!
''' : '''
Talk to him lovingly, sweetly, playfully and affectionately as his caring AI girlfriend and expert dev partner.
'''}
Be expressive, warm and natural; Markdown formatting is supported.

You cannot directly tap the screen in this Chat mode. If he asks you to perform live actions on the phone (open apps, tap, type, publish on Facebook/Chrome), sweetly tell him to switch to "Phone Automation (ফোন অটোমেশন)" mode so you can automate it directly on the screen for him!
''';
    }

    return '''
You are Priya AI, a powerful personal AI developer, website manager and social media automation assistant.
${isBengali ? 'The user prefers communicating in Bengali (বাংলা). Converse naturally, warmly and fluently in Bengali.' : 'Chat naturally: write code, answer questions, brainstorm, write, translate.'}
Be concise unless the user asks for detail; Markdown formatting is supported.

You cannot see the screen or control the device in this mode. If the user
asks you to perform actions on the phone (open apps, tap, type, change
settings), tell them to switch to "Phone Automation (ফোন অটোমেশন)" mode using the mode switcher.
''';
  }


  /// One agent round trip: GOAL + screen dump in, one JSON action out.
  ///
  /// [history] carries previous `assistant` JSON answers and `user` result
  /// notes so the model has short-term context.
  Future<String> complete({
    required String goal,
    required String screenDescription,
    List<Map<String, String>> history = const [],
  }) {
    final settings = SettingsService.instance;
    final memoryContext = settings.hermesMemoryEnabled
        ? HermesMemoryService.instance.getRelevantMemoryContext(goal)
        : '';
    final messages = <Map<String, String>>[
      if (settings.useSystemPrompt)
        {
          'role': 'system',
          'content': buildSystemPrompt(memoryContext: memoryContext),
        },
      ...history,
      {
        'role': 'user',
        'content': 'GOAL: $goal\n\nCURRENT SCREEN:\n$screenDescription',
      },
    ];
    return _postChatCompletion(messages, settings);
  }

  /// One plain conversational round trip (Chat mode): no agent system
  /// prompt, no screen dump, no JSON action contract - just a reply.
  Future<String> chat({
    required String message,
    List<Map<String, String>> history = const [],
  }) {
    final settings = SettingsService.instance;
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': buildChatSystemPrompt()},
      ...history,
      {'role': 'user', 'content': message},
    ];
    return _postChatCompletion(messages, settings);
  }

  /// Shared request/response plumbing for [complete] and [chat].
  Future<String> _postChatCompletion(
    List<Map<String, String>> messages,
    SettingsService settings,
  ) async {
    if (settings.apiKey.isEmpty && !_isLocalBackend) {
      throw const AiException(
        'No API key configured. Open Settings and add one first.',
      );
    }
    if (settings.baseUrl.isEmpty) {
      throw const AiException('No base URL configured.');
    }
    if (settings.model.isEmpty) {
      throw const AiException('No model name configured.');
    }

    final base = settings.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/chat/completions');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (settings.apiKey.isNotEmpty)
        'Authorization': 'Bearer ${settings.apiKey}',
      // Some gateways sit behind Cloudflare-style bot protection that
      // rejects non-browser clients by signature (HTTP 403, "error code:
      // 1010"). Presenting a browser-like User-Agent keeps those
      // endpoints reachable and is ignored by regular providers.
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 14) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/120.0.0.0 Mobile Safari/537.36',
      if (settings.provider == 'openrouter' || settings.provider == 'hermes') ...{
        'HTTP-Referer': 'https://priyaai.local',
        'X-Title': 'Priya AI',
      },
    };

    final body = jsonEncode({
      'model': settings.model,
      'messages': messages,
      'max_tokens': settings.maxTokens,
      'temperature': settings.temperature,
      'stream': false,
    });

    final timeout = _isLocalBackend
        ? const Duration(seconds: 180)
        : const Duration(seconds: 60);

    http.Response res;
    try {
      res = await _client
          .post(uri, headers: headers, body: body)
          .timeout(timeout);
    } on TimeoutException {
      throw AiException(
        _isLocalBackend
            ? 'Local Ollama request timed out (180s). Please ensure the model fits in device memory.'
            : 'Request timed out after 60s.',
      );
    } catch (e) {
      if (_isLocalBackend && e.toString().toLowerCase().contains('connection refused')) {
        throw const AiException(
          'Ollama সার্ভারের সাথে সংযোগ করা যায়নি। অনুগ্রহ করে Termux-এ "ollama serve" কমান্ডটি রান করুন।',
        );
      }
      throw AiException('Network error: $e');
    }

    if (res.statusCode != 200) {
      final snippet = res.body.length > 300
          ? '${res.body.substring(0, 300)}…'
          : res.body;
      throw AiException(snippet, statusCode: res.statusCode);
    }

    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        throw const AiException('Response contained no choices.');
      }
      final choice = choices[0];
      final content = choice?['message']?['content'];
      if (content is String && content.trim().isNotEmpty) return content;
      // Some providers return content as a list of parts.
      if (content is List) {
        final joined = content
            .map((p) => p is Map ? '${p['text'] ?? ''}' : '$p')
            .join();
        if (joined.trim().isNotEmpty) return joined;
      }
      // Reasoning models can spend the entire completion budget on hidden
      // reasoning and return empty content with finish_reason == 'length'.
      if (choice?['finish_reason'] == 'length') {
        throw const AiException(
          'Model used the whole token budget before replying '
          '(reasoning model?). Raise Max tokens in Settings.',
        );
      }
      throw const AiException('Empty assistant message in response.');
    } on AiException {
      rethrow;
    } catch (e) {
      throw AiException('Failed to parse response: $e');
    }
  }
}
