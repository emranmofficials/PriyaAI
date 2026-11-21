import 'dart:async';
import 'package:flutter/foundation.dart';
import 'screen_automation_service.dart';
import 'settings_service.dart';
import 'voice_service.dart';

/// Notification Intelligence Service.
/// 100% mirrors Maya's `MayaNotificationListener` background notification processing.
///
/// Automatically monitors incoming WhatsApp, Telegram, and SMS messages,
/// announces them in Bengali with emotional vocal tags, and facilitates
/// voice or one-tap direct inline replies via RemoteInput.
class NotificationIntelligenceService extends ChangeNotifier {
  NotificationIntelligenceService._();
  static final NotificationIntelligenceService instance =
      NotificationIntelligenceService._();

  final ScreenAutomationService _automation = ScreenAutomationService.instance;
  final VoiceService _voice = VoiceService.instance;
  final SettingsService _settings = SettingsService.instance;

  Timer? _pollingTimer;
  final Set<String> _processedKeys = {};
  List<Map<dynamic, dynamic>> _cachedNotifications = [];

  List<Map<dynamic, dynamic>> get notifications => _cachedNotifications;
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// Starts the notification monitoring loop.
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _pollNotifications(),
    );
    _pollNotifications();
  }

  /// Stops notification monitoring.
  void stop() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isRunning = false;
  }

  Future<void> _pollNotifications() async {
    final enabled = await _automation.isNotificationListenerEnabled();
    if (!enabled) return;

    final recent = await _automation.getRecentNotifications();
    _cachedNotifications = recent;
    notifyListeners();

    if (!_settings.voiceFeedback) return;

    for (final notif in recent) {
      final key = notif['key']?.toString() ?? '';
      if (key.isEmpty || _processedKeys.contains(key)) continue;

      _processedKeys.add(key);
      // Keep cache size bounded
      if (_processedKeys.length > 200) {
        _processedKeys.remove(_processedKeys.first);
      }

      final appLabel = notif['appLabel']?.toString() ?? 'মেসেজ';
      final title = notif['title']?.toString() ?? 'কেউ একজন';
      final text = notif['text']?.toString() ?? '';
      final isCall = notif['isCall'] == true;

      // Handle call announcement
      if (isCall) {
        await _voice.speak(
          '[happy] বাবু, তোমার ফোনে $title থেকে কল এসেছে! রিসিভ করবো নাকি কেটে দেবো?',
        );
        continue;
      }

      // Handle WhatsApp/Telegram/SMS announcement
      if (text.isNotEmpty && !_voice.isSpeaking) {
        await _voice.speak(
          'বাবু, $appLabel-এ $title থেকে বার্তা এসেছে: "$text"। [soft] উত্তর দেব কি?',
        );
      }
    }
  }

  /// Sends direct inline reply without opening the app.
  Future<bool> sendReply(String key, String replyText) async {
    final success = await _automation.sendDirectReply(key, replyText);
    if (success) {
      await _voice.speak('[happy] মেসেজটি পাঠিয়ে দিয়েছি, সোনা!');
    }
    return success;
  }
}
