import 'package:flutter/services.dart';

import '../models/screen_node.dart';

/// Thin, safe wrapper around the `com.privateagent/accessibility`
/// MethodChannel implemented by `MainActivity` / `AgentAccessibilityService`.
///
/// Also owns the text formatting that turns the raw node list into a compact,
/// LLM-friendly screen description (minimizing token usage).
class ScreenAutomationService {
  ScreenAutomationService._();
  static final ScreenAutomationService instance = ScreenAutomationService._();

  static const MethodChannel _channel =
      MethodChannel('com.privateagent/accessibility');

  List<ScreenNode> _lastNodes = const [];

  /// Nodes from the most recent [dumpScreen] call (used to resolve
  /// `click_text` actions without re-dumping).
  List<ScreenNode> get lastNodes => _lastNodes;

  // ------------------------------------------------------------------
  // Service status / settings shortcuts
  // ------------------------------------------------------------------

  Future<bool> isServiceEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isServiceEnabled');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openAccessibilitySettings() =>
      _channel.invokeMethod<void>('openAccessibilitySettings');

  Future<void> openAppInfoSettings() =>
      _channel.invokeMethod<void>('openAppInfoSettings');

  Future<Size> getScreenSize() async {
    final map = await _channel
        .invokeMapMethod<String, dynamic>('getScreenSize');
    return Size(
      (map?['width'] as num?)?.toInt() ?? 0,
      (map?['height'] as num?)?.toInt() ?? 0,
    );
  }

  // ------------------------------------------------------------------
  // Screen reading
  // ------------------------------------------------------------------

  /// Dumps the current accessibility tree. Returns an empty list when the
  /// service is off or the screen is locked.
  Future<List<ScreenNode>> dumpScreen() async {
    final raw = await _channel.invokeListMethod<dynamic>('dumpScreen');
    if (raw == null) {
      _lastNodes = const [];
      return _lastNodes;
    }
    _lastNodes = raw
        .whereType<Map>()
        .map((m) => ScreenNode.fromMap(m))
        .toList(growable: false);
    return _lastNodes;
  }

  /// Base64-encoded PNG of the screen (Android 11+). Null on failure.
  Future<String?> takeScreenshotBase64() async {
    try {
      return await _channel.invokeMethod<String>('takeScreenshot');
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------------
  // Actions
  // ------------------------------------------------------------------

  Future<bool> clickAt(int x, int y) async =>
      await _channel.invokeMethod<bool>('clickAt', {'x': x, 'y': y}) ?? false;

  Future<bool> clickNode(ScreenNode node) =>
      clickAt(node.centerX, node.centerY);

  /// Finds a node by label within [nodes] (or the last dump) and taps its
  /// center. Exact matches win over partial matches.
  Future<bool> clickText(String text, {List<ScreenNode>? nodes}) async {
    final pool = nodes ?? _lastNodes;
    final q = text.trim().toLowerCase();
    if (q.isEmpty || pool.isEmpty) return false;

    ScreenNode? exact;
    ScreenNode? partial;
    for (final n in pool) {
      if (!n.isEnabled) continue;
      final label = n.label.toLowerCase();
      if (label == q && (n.isClickable || n.isCheckable)) {
        exact ??= n;
      } else if (label == q) {
        exact ??= n;
      } else if (n.matches(q)) {
        partial ??= n;
      }
    }
    final target = exact ?? partial;
    if (target == null) return false;
    return clickNode(target);
  }

  Future<bool> swipe({
    required int startX,
    required int startY,
    required int endX,
    required int endY,
    int durationMs = 350,
  }) async =>
      await _channel.invokeMethod<bool>('swipe', {
            'startX': startX,
            'startY': startY,
            'endX': endX,
            'endY': endY,
            'durationMs': durationMs,
          }) ??
      false;

  Future<bool> scroll(String direction) async =>
      await _channel.invokeMethod<bool>('scroll', {'direction': direction}) ??
      false;

  Future<bool> typeText(String text) async =>
      await _channel.invokeMethod<bool>('typeText', {'text': text}) ?? false;

  Future<bool> pressKey(String key) async =>
      await _channel.invokeMethod<bool>('pressKey', {'key': key}) ?? false;

  Future<bool> pressBack() => pressKey('back');
  Future<bool> pressHome() => pressKey('home');
  Future<bool> pressEnter() => pressKey('enter');
  Future<bool> pressLock() => pressKey('lock');

  // ------------------------------------------------------------------
  // LLM-oriented formatting
  // ------------------------------------------------------------------

  static const int _maxLabelLength = 60;
  static const int _maxNodesInDump = 150;

  static String _truncate(String value, [int max = _maxLabelLength]) {
    final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= max) return clean;
    return '${clean.substring(0, max - 1)}…';
  }

  /// Compacts a raw node list into a text dump for the LLM.
  ///
  /// Line format:
  /// `#3 "Sign in" [Button] @(540,1210) clickable`
  ///
  /// Nodes without any label are kept only when they are interactive
  /// (so the model can still target them by coordinates).
  String formatNodes(List<ScreenNode> nodes, {int maxNodes = _maxNodesInDump}) {
    final kept = nodes
        .where((n) => n.hasLabel || n.isInteractive)
        .take(maxNodes)
        .toList();
    if (kept.isEmpty) return '(screen is empty or not readable)';

    final buffer = StringBuffer();
    for (final n in kept) {
      buffer.write('#${n.index} ');
      if (n.hasLabel) buffer.write('"${_truncate(n.label)}" ');
      buffer.write('[${n.shortClass}] ');
      buffer.write('@(${n.centerX},${n.centerY})');
      final flags = <String>[
        if (n.isClickable) 'clickable',
        if (n.isEditable) 'editable',
        if (n.isScrollable) 'scrollable',
        if (n.isCheckable) 'checkable',
        if (!n.isEnabled) 'disabled',
      ];
      if (flags.isNotEmpty) buffer.write(' ${flags.join(' ')}');
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }

  /// Focused variant of [formatNodes]: scores each node by how relevant its
  /// label is to the user's [goal] and keeps the most relevant ones plus all
  /// editable/scrollable nodes, dramatically reducing token usage on busy
  /// screens. Falls back to the plain dump when nothing matches.
  String getCompressedScreenDescription(
    List<ScreenNode> nodes,
    String goal, {
    int maxNodes = 60,
  }) {
    if (nodes.length <= maxNodes) return formatNodes(nodes, maxNodes: maxNodes);

    final goalTokens = _tokenizeGoal(goal);

    int score(ScreenNode n) {
      var s = 0;
      final label = n.label.toLowerCase();
      for (final t in goalTokens) {
        if (t.isEmpty) continue;
        if (label == t) {
          s += 8;
        } else if (label.contains(t)) {
          s += 3;
        }
      }
      if (n.isEditable) s += 4;
      if (n.isScrollable) s += 2;
      if (n.isClickable) s += 1;
      return s;
    }

    final ranked = nodes.where((n) => n.hasLabel || n.isInteractive).toList()
      ..sort((a, b) => score(b).compareTo(score(a)));

    final top = ranked.take(maxNodes).toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return formatNodes(top, maxNodes: maxNodes);
  }

  /// Cheap tokenizer shared with the relevance scorer above.
  static Set<String> _tokenizeGoal(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.length > 2)
      .toSet();
}

/// Simple 2D size holder to avoid importing dart:ui into services.
class Size {
  final int width;
  final int height;
  const Size(this.width, this.height);

  @override
  String toString() => '${width}x$height';
}
