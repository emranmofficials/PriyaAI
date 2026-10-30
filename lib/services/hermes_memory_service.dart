import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/task_step.dart';

/// Represents a single persistent knowledge unit in Hermes Agent memory.
class HermesMemoryItem {
  final String id;
  final String content;
  final String tag;
  final DateTime createdAt;
  DateTime updatedAt;

  HermesMemoryItem({
    String? id,
    required this.content,
    this.tag = 'general',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'tag': tag,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory HermesMemoryItem.fromJson(Map<String, dynamic> json) =>
      HermesMemoryItem(
        id: json['id']?.toString(),
        content: json['content']?.toString() ?? '',
        tag: json['tag']?.toString() ?? 'general',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      );
}

/// Hermes Agent Persistent Memory & Self-Improving Learning Loop.
///
/// Inspired by Nous Research's Hermes Agent architecture:
/// - Maintains persistent memories across sessions (USER.md / MEMORY.md equivalent).
/// - Learns from completed tasks and failure patterns so the agent improves over time.
/// - Injects concise, goal-relevant memory context into the LLM prompt.
class HermesMemoryService extends ChangeNotifier {
  HermesMemoryService._();
  static final HermesMemoryService instance = HermesMemoryService._();

  static const _memoryStorageKey = 'hermes_memory_items_v1';
  static const _userProfileStorageKey = 'hermes_user_profile_v1';

  final List<HermesMemoryItem> _memories = [];
  final Map<String, String> _userProfile = {};
  bool _isLoaded = false;

  List<HermesMemoryItem> get memories => List.unmodifiable(_memories);
  Map<String, String> get userProfile => Map.unmodifiable(_userProfile);

  Future<void> init() async {
    if (_isLoaded) return;
    final prefs = await SharedPreferences.getInstance();

    // Load memories
    final rawMemories = prefs.getString(_memoryStorageKey);
    if (rawMemories != null && rawMemories.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawMemories);
        if (decoded is List) {
          _memories.clear();
          for (final item in decoded) {
            if (item is Map) {
              _memories.add(
                HermesMemoryItem.fromJson(
                  item.map((k, v) => MapEntry('$k', v)),
                ),
              );
            }
          }
        }
      } catch (_) {}
    }

    // Load user profile
    final rawProfile = prefs.getString(_userProfileStorageKey);
    if (rawProfile != null && rawProfile.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawProfile);
        if (decoded is Map) {
          _userProfile.clear();
          decoded.forEach((k, v) {
            _userProfile['$k'] = '$v';
          });
        }
      } catch (_) {}
    }

    // Add sensible starter defaults if empty
    if (_memories.isEmpty) {
      _memories.addAll([
        HermesMemoryItem(
          content: 'Input fields usually require press_enter after typing to submit.',
          tag: 'input',
        ),
        HermesMemoryItem(
          content: 'If an expected button is not visible on screen, scroll down before giving up.',
          tag: 'navigation',
        ),
      ]);
      await _persistMemories();
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _persistMemories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _memoryStorageKey,
      jsonEncode(_memories.map((m) => m.toJson()).toList()),
    );
  }

  Future<void> _persistProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userProfileStorageKey, jsonEncode(_userProfile));
  }

  /// Adds a new learned memory or updates an existing one.
  Future<void> addMemory(String content, {String tag = 'general'}) async {
    await init();
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    // Check if an identical memory exists to prevent duplicates
    final existingIndex = _memories.indexWhere(
      (m) => m.content.toLowerCase() == trimmed.toLowerCase(),
    );

    if (existingIndex >= 0) {
      _memories[existingIndex].updatedAt = DateTime.now();
    } else {
      _memories.insert(0, HermesMemoryItem(content: trimmed, tag: tag));
      if (_memories.length > 100) {
        _memories.removeRange(100, _memories.length);
      }
    }
    await _persistMemories();
    notifyListeners();
  }

  Future<void> deleteMemory(String id) async {
    await init();
    _memories.removeWhere((m) => m.id == id);
    await _persistMemories();
    notifyListeners();
  }

  Future<void> clearAll() async {
    await init();
    _memories.clear();
    _userProfile.clear();
    await _persistMemories();
    await _persistProfile();
    notifyListeners();
  }

  /// Updates or sets a user profile attribute (e.g., 'preferred_language', 'default_music_app').
  Future<void> setProfileField(String key, String value) async {
    await init();
    _userProfile[key] = value.trim();
    await _persistProfile();
    notifyListeners();
  }

  /// Formats relevant memory context for the agent's LLM prompt based on the current goal.
  String getRelevantMemoryContext(String goal) {
    if (!_isLoaded || _memories.isEmpty) return '';

    final tokens = goal
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 2)
        .toSet();

    final relevant = <String>[];

    // Check profile
    if (_userProfile.isNotEmpty) {
      final profileSnippets = _userProfile.entries
          .map((e) => '${e.key}: ${e.value}')
          .take(3)
          .join(', ');
      relevant.add('User Preferences: $profileSnippets');
    }

    // Match memories by keyword overlap or general tags
    for (final memory in _memories) {
      final memLower = memory.content.toLowerCase();
      final tagLower = memory.tag.toLowerCase();

      final matches = tokens.any((t) => memLower.contains(t) || tagLower.contains(t));
      if (matches || memory.tag == 'general') {
        relevant.add('- ${memory.content}');
      }
      if (relevant.length >= 6) break;
    }

    if (relevant.isEmpty) return '';

    return '\n### HERMES PERSISTENT MEMORY & LEARNED FACTS:\n${relevant.join('\n')}\n';
  }

  /// Automatically records experience from a completed or failed task.
  Future<void> recordExperience({
    required String goal,
    required bool success,
    List<TaskStep> steps = const [],
    String? failureReason,
  }) async {
    await init();

    if (success && steps.isNotEmpty) {
      // Find what app was opened if any
      final openAppStep = steps.firstWhere(
        (s) => s.action == TaskStep.actionOpenApp,
        orElse: () => const TaskStep(action: ''),
      );
      final appName = openAppStep.stringParam('app');
      if (appName != null && appName.isNotEmpty) {
        await addMemory(
          'For goal "$goal", app "$appName" was successfully used in ${steps.length} steps.',
          tag: appName.toLowerCase(),
        );
      }
    } else if (!success && failureReason != null && failureReason.isNotEmpty) {
      // Record failure pattern to avoid repeating
      await addMemory(
        'Goal "$goal" previously faced difficulty: $failureReason. Consider alternative steps.',
        tag: 'recovery',
      );
    }
  }
}
