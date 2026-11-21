import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screen_automation_service.dart';
import 'voice_service.dart';

/// Hands-Free Driving Mode Service.
/// 100% mirrors Maya's `com.getmaya.android.core.DrivingOffReceiver` and Driving Mode.
///
/// When active:
/// 1. Auto-announces incoming callers and allows instant voice answer/reject.
/// 2. Reads all WhatsApp, SMS, and Telegram messages automatically aloud in Bengali.
/// 3. Enables hands-free voice replies with zero screen touching.
class PriyaDrivingService extends ChangeNotifier {
  PriyaDrivingService._();
  static final PriyaDrivingService instance = PriyaDrivingService._();

  final ScreenAutomationService _automation = ScreenAutomationService.instance;
  final VoiceService _voice = VoiceService.instance;

  bool _isDrivingMode = false;
  bool get isDrivingMode => _isDrivingMode;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isDrivingMode = prefs.getBool('driving_mode_enabled') ?? false;
  }

  Future<void> toggleDrivingMode() async {
    setDrivingMode(!_isDrivingMode);
  }

  Future<void> setDrivingMode(bool enabled) async {
    _isDrivingMode = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('driving_mode_enabled', enabled);
    notifyListeners();

    if (enabled) {
      await _voice.speak(
        '[happy] বাবু, ড্রাইভিং মোড চালু হয়েছে! ফোন ধরা লাগবে না, মেসেজ বা কল এলে আমি সব পড়ে শোনাব!',
      );
    } else {
      await _voice.speak(
        '[soft] ড্রাইভিং মোড বন্ধ করা হলো সোনা।',
      );
    }
  }

  /// Handles incoming call in Driving Mode
  Future<void> handleDrivingCall(String caller) async {
    if (!_isDrivingMode) return;
    await _automation.duckRinger();
    await _voice.speak(
      'বাবু, $caller কল করছে! রিসিভ করবো নাকি কেটে দেবো বলো?',
    );
  }
}
