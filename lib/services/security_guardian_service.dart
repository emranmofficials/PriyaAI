import 'dart:async';
import 'package:flutter/foundation.dart';

import 'screen_automation_service.dart';
import 'settings_service.dart';
import 'telegram_service.dart';
import 'voice_service.dart';

/// Security Guardian Service: Protects the device and personal accounts from
/// unauthorized use, intruders, or theft.
///
/// Features:
/// - Screen Lock: Instantly locks the Android display via Accessibility Service.
/// - Bengali Voice Siren / Warning: Speeches an audible security warning to intruder.
/// - Telegram Intruder Alert: Sends immediate screenshot and alert to owner's Telegram.
/// - App Shield: Blocks unauthorized access to sensitive apps (WhatsApp, Facebook, Banking).
class SecurityGuardianService extends ChangeNotifier {
  SecurityGuardianService._();
  static final SecurityGuardianService instance = SecurityGuardianService._();

  bool _isDefending = false;
  bool get isDefending => _isDefending;

  /// Default list of sensitive packages or app names to guard
  final Set<String> _protectedAppKeywords = {
    'whatsapp',
    'facebook',
    'messenger',
    'instagram',
    'gallery',
    'photos',
    'bkash',
    'nagad',
    'upay',
    'settings',
    'gmail',
    'messages',
  };

  /// Validates if an incoming voice command comes from the authorized owner.
  /// If an owner secret passphrase is set, the input must match or unlock first.
  bool verifyVoiceAuthorization(String spokenText) {
    final settings = SettingsService.instance;
    if (!settings.securityGuardianEnabled) return true;

    final phrase = settings.ownerSecretPhrase.toLowerCase().trim();
    if (phrase.isEmpty) return true; // No passphrase enforced yet

    final input = spokenText.toLowerCase();
    return input.contains(phrase);
  }

  /// Triggers full anti-theft defense:
  /// 1. Speaks a firm Bengali voice warning.
  /// 2. Instantly locks the device screen.
  /// 3. Captures a screenshot and transmits it to the owner's Telegram.
  Future<void> triggerIntruderDefense({
    String reason = 'অননুমোদিত ব্যবহারকারী সনাক্ত হয়েছে!',
  }) async {
    if (_isDefending) return;
    _isDefending = true;
    notifyListeners();

    try {
      // 1. Spoken Bengali Voice Warning
      final isGf = SettingsService.instance.girlfriendMode;
      final warningMessage = isGf
          ? 'খবরদার! এটা আমার বাবুর ফোন! এতে হাত দেওয়ার অধিকার শুধু ওর। ফোনটি এখনই লক করে দেওয়া হচ্ছে!'
          : 'সতর্কতা! এই ফোনটি ব্যবহারের অনুমতি আপনার নেই। ফোনটি লক করা হচ্ছে।';
      await VoiceService.instance.speak(warningMessage);

      // 2. Capture screenshot for Telegram alert before locking
      final screenshot =
          await ScreenAutomationService.instance.takeScreenshotBase64();

      // 3. Immediately lock the device display
      await ScreenAutomationService.instance.pressLock();

      // 4. Alert owner via Telegram if configured
      final settings = SettingsService.instance;
      final ownerChat = settings.telegramOwnerChatId.isNotEmpty
          ? settings.telegramOwnerChatId
          : (settings.telegramAllowedChats.isNotEmpty
              ? settings.telegramAllowedChats.first
              : null);

      if (ownerChat != null && settings.telegramEnabled) {
        final alertText =
            '🚨 *সিকিউরিটি অ্যালার্ট! (Security Alert)*\n\n'
            'কেহ একজন আপনার ফোন ব্যবহার করার চেষ্টা করেছে।\n'
            'কারণ: $reason\n'
            'সময়: ${DateTime.now().toLocal().toString().split('.')[0]}\n'
            '🔒 ফোনটি সাথে সাথে লক করা হয়েছে।';

        await TelegramService.instance.sendMessage(ownerChat, alertText);
        if (screenshot != null) {
          await TelegramService.instance.sendScreenshot(ownerChat, screenshot);
        }
      }
    } catch (e) {
      debugPrint('Security Guardian error: $e');
    } finally {
      _isDefending = false;
      notifyListeners();
    }
  }

  /// Checks if the requested app is sensitive and should require authorization.
  bool isProtectedApp(String appQuery) {
    final q = appQuery.toLowerCase().trim();
    return _protectedAppKeywords.any((keyword) => q.contains(keyword));
  }
}
