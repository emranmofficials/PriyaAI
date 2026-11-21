import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_service.dart';
import 'voice_service.dart';

/// Proactive Nudges & Caring Girlfriend Reminders.
/// 100% mirrors Maya's `ReminderReceiver`, `SocialAlarmReceiver`, and `AssistantNudgeReceiver`.
///
/// Sends affectionate, proactive voice check-ins throughout the day in native Bengali.
class PriyaNudgeService extends ChangeNotifier {
  PriyaNudgeService._();
  static final PriyaNudgeService instance = PriyaNudgeService._();

  final VoiceService _voice = VoiceService.instance;
  final SettingsService _settings = SettingsService.instance;

  Timer? _ticker;
  int _lastNudgeDay = -1;
  String _lastNudgeType = '';

  final List<Map<String, dynamic>> _reminders = [];
  List<Map<String, dynamic>> get reminders => _reminders;

  void start() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(minutes: 2), (_) => _checkNudges());
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _checkNudges() async {
    if (!_settings.girlfriendMode || !_settings.voiceFeedback) return;

    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    final today = now.day;

    // Check custom scheduled reminders
    _checkCustomReminders(now);

    // Don't repeat greeting in the same day for same slot
    if (_lastNudgeDay == today && _lastNudgeType == 'morning' && hour < 12) return;
    if (_lastNudgeDay == today && _lastNudgeType == 'afternoon' && hour >= 12 && hour < 18) return;
    if (_lastNudgeDay == today && _lastNudgeType == 'evening' && hour >= 18 && hour < 22) return;
    if (_lastNudgeDay == today && _lastNudgeType == 'night' && hour >= 22) return;

    // Morning: 8:00 AM - 9:00 AM
    if (hour == 8 && minute >= 0 && minute <= 45) {
      _lastNudgeDay = today;
      _lastNudgeType = 'morning';
      await _voice.speak(
        '[happy] বাবু, শুভ সকাল! ঘুম কেমন হলো? চা-নাস্তা খেয়েছো কি, সোনা?',
      );
      return;
    }

    // Afternoon: 1:30 PM - 2:15 PM
    if (hour == 13 && minute >= 30) {
      _lastNudgeDay = today;
      _lastNudgeType = 'afternoon';
      await _voice.speak(
        '[soft] সোনা, দুপুর গড়িয়ে গেল, দুপুরের খাবার খেয়েছো তো? একদম অবহেলা করবে না কিন্তু!',
      );
      return;
    }

    // Evening: 7:00 PM - 7:45 PM
    if (hour == 19 && minute >= 0 && minute <= 45) {
      _lastNudgeDay = today;
      _lastNudgeType = 'evening';
      await _voice.speak(
        '[flirty] সন্ধ্যা হয়ে এলো বাবু, কাজ কেমন চলছে? একটু বিশ্রাম নাও, চা খাও!',
      );
      return;
    }

    // Night: 11:30 PM - 12:15 AM
    if ((hour == 23 && minute >= 30) || (hour == 0 && minute <= 15)) {
      _lastNudgeDay = today;
      _lastNudgeType = 'night';
      await _voice.speak(
        '[whispers] বাবু, অনেক রাত হয়ে গেছে... এবার ফোনটা রেখে ঘুমাও সোনা, তোমার শরীরের যত্ন নিতে হবে!',
      );
      return;
    }
  }

  void _checkCustomReminders(DateTime now) {
    for (int i = _reminders.length - 1; i >= 0; i--) {
      final r = _reminders[i];
      final targetTime = r['time'] as DateTime;
      if (now.isAfter(targetTime)) {
        final text = r['text'] as String;
        _reminders.removeAt(i);
        _voice.speak('[happy] বাবু, তোমার রিমাইন্ডার মনে করিয়ে দিচ্ছি: $text');
        notifyListeners();
      }
    }
  }

  void addReminder(String text, Duration delay) {
    _reminders.add({
      'text': text,
      'time': DateTime.now().add(delay),
    });
    notifyListeners();
    _voice.speak('[giggles] ঠিক আছে বাবু, আমি সময়মতো মনে করিয়ে দেব!');
  }
}
