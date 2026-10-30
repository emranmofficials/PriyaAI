import 'dart:convert';

/// One atomic action decided by the LLM (or replayed from skill memory).
///
/// Wire format expected from the model:
/// ```json
/// {
///   "action": "click_text" | "click_at" | "type_text" | "press_enter" |
///             "scroll" | "swipe" | "press_back" | "press_home" |
///             "open_app" | "wait" | "done",
///   "params": { ... },
///   "reasoning": "short explanation",
///   "is_complete": false
/// }
/// ```
class TaskStep {
  static const actionClickText = 'click_text';
  static const actionClickAt = 'click_at';
  static const actionTypeText = 'type_text';
  static const actionPressEnter = 'press_enter';
  static const actionScroll = 'scroll';
  static const actionSwipe = 'swipe';
  static const actionPressBack = 'press_back';
  static const actionPressHome = 'press_home';
  static const actionOpenApp = 'open_app';
  static const actionWait = 'wait';
  static const actionDone = 'done';

  static const supportedActions = <String>{
    actionClickText,
    actionClickAt,
    actionTypeText,
    actionPressEnter,
    actionScroll,
    actionSwipe,
    actionPressBack,
    actionPressHome,
    actionOpenApp,
    actionWait,
    actionDone,
  };

  final String action;
  final Map<String, dynamic> params;
  final String reasoning;
  final bool isComplete;

  const TaskStep({
    required this.action,
    this.params = const {},
    this.reasoning = '',
    this.isComplete = false,
  });

  factory TaskStep.fromJson(Map<String, dynamic> json) {
    final rawAction = (json['action'] ?? '').toString().trim().toLowerCase();
    final rawParams = json['params'];
    return TaskStep(
      action: rawAction,
      params: rawParams is Map
          ? rawParams.map((k, v) => MapEntry(k.toString(), v))
          : const {},
      reasoning: (json['reasoning'] ?? '').toString(),
      isComplete: json['is_complete'] == true || json['isComplete'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'action': action,
        'params': params,
        'reasoning': reasoning,
        'is_complete': isComplete,
      };

  bool get isSupported => supportedActions.contains(action);

  /// Stable signature used by the recovery engine to detect repeated actions.
  String get signature => '$action:${jsonEncode(params)}';

  /// Numeric param with forgiving parsing (int / double / numeric string).
  int? intParam(String key) {
    final v = params[key];
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.round();
    return null;
  }

  String? stringParam(String key) {
    final v = params[key];
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  /// Robustly extracts the first JSON object from raw LLM output, tolerating
  /// markdown fences, leading prose and trailing commentary.
  static TaskStep? tryParse(String aiText) {
    var text = aiText.trim();
    // Strip reasoning / thought tags common in Hermes, DeepSeek, and thinking models.
    text = text.replaceAll(
      RegExp(r'<(?:thought|thinking)>[\s\S]*?<\/(?:thought|thinking)>', caseSensitive: false),
      '',
    ).trim();

    // Strip markdown code fences if present.
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false);
    final fenceMatch = fence.firstMatch(text);
    if (fenceMatch != null) text = fenceMatch.group(1)!.trim();

    Map<String, dynamic>? decode(String candidate) {
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map<String, dynamic> && decoded.containsKey('action')) {
          return decoded;
        }
      } catch (_) {}
      return null;
    }

    var parsed = decode(text);
    if (parsed == null) {
      // Fall back to the widest balanced { ... } region.
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start >= 0 && end > start) {
        parsed = decode(text.substring(start, end + 1));
      }
    }
    if (parsed == null) return null;
    final step = TaskStep.fromJson(parsed);
    return step.isSupported ? step : null;
  }

  @override
  String toString() =>
      'TaskStep($action, params=$params, complete=$isComplete)';
}
