import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/screen_automation_service.dart';
import '../../theme/app_theme.dart';

/// Accessibility Service Doctor & Diagnostics Screen.
/// 100% mirrors Maya's `a11y_menu`, `a11y_group_one_tap`, and payment toggles.
class AccessibilityDoctorScreen extends StatefulWidget {
  const AccessibilityDoctorScreen({super.key});

  @override
  State<AccessibilityDoctorScreen> createState() => _AccessibilityDoctorScreenState();
}

class _AccessibilityDoctorScreenState extends State<AccessibilityDoctorScreen> {
  final _automation = ScreenAutomationService.instance;
  bool _checking = false;
  bool _serviceConnected = false;
  bool _notifListenerConnected = false;
  bool _termuxInstalled = false;
  int _nodeCount = 0;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _checking = true);
    final enabled = await _automation.isServiceEnabled();
    final notifEnabled = await _automation.isNotificationListenerEnabled();
    final termuxOk = await _automation.isTermuxInstalled();
    int count = 0;
    if (enabled) {
      try {
        final nodes = await _automation.dumpScreen();
        count = nodes.length;
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _serviceConnected = enabled;
        _notifListenerConnected = notifEnabled;
        _termuxInstalled = termuxOk;
        _nodeCount = count;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.obsidian,
      appBar: AppBar(
        title: const Text('Accessibility Doctor'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _checkStatus,
        color: AppTheme.neonCyan,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Status Card
            _buildStatusCard(),
            const SizedBox(height: 14),

            // Notification Listener Card
            _buildNotificationListenerCard(),
            const SizedBox(height: 14),

            // Termux Bridge Card
            _buildTermuxStatusCard(),
            const SizedBox(height: 20),

            // One-Tap Fix Section
            _buildSectionHeader('One-Tap Fix (Advanced)', Icons.bolt),
            const SizedBox(height: 10),
            _buildOneTapCard(),
            const SizedBox(height: 24),

            // Payment App Pause Section
            _buildSectionHeader('Payment & Banking Apps', Icons.account_balance),
            const SizedBox(height: 10),
            _buildPaymentCard(),
            const SizedBox(height: 24),

            // Background & Battery Stability
            _buildSectionHeader('Background Keep-Alive', Icons.battery_charging_full),
            const SizedBox(height: 10),
            _buildBatteryGuideCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.neonCyan),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    final active = _serviceConnected;
    final color = active ? AppTheme.neonEmerald : AppTheme.danger;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.obsidianCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(color: color, blurRadius: 8, spreadRadius: 2),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  active ? 'অ্যাক্সেসিবিলিটি চালু আছে' : 'অ্যাক্সেসিবিলিটি বন্ধ আছে',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_checking)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.neonCyan),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            active
                ? 'প্রিয়া ফোনের স্ক্রিন পড়তে ও অ্যাপস নিয়ন্ত্রণ করতে প্রস্তুত — WhatsApp, YouTube, Instagram সব। ($_nodeCount টি ভিজিবল এলিমেন্ট শনাক্ত)'
                : 'সার্ভিস বন্ধ রয়েছে — প্রিয়া স্ক্রিনে ট্যাপ বা টাইপ করতে পারছে না। ঠিক করার জন্য সার্ভিসটি চালু করুন।',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _automation.openAccessibilitySettings(),
                  icon: const Icon(Icons.settings, size: 18),
                  label: Text(active ? 'সেটিংস খুলুন' : 'এখনই চালু করুন'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: active ? AppTheme.obsidianElevated : AppTheme.neonViolet,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationListenerCard() {
    final active = _notifListenerConnected;
    final color = active ? AppTheme.neonEmerald : AppTheme.warning;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.obsidianCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  active ? 'নোটিফিকেশন রিডার সক্রিয়' : 'নোটিফিকেশন অ্যাক্সেস প্রয়োজন',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            active
                ? 'হোয়াটসঅ্যাপ, টেলিগ্রাম ও এসএমএস মেসেজ পড়া ও মুখে বলে সরাসরি উত্তর দেওয়ার সক্ষমতা তৈরি হয়েছে।'
                : 'ইনকামিং মেসেজ পড়ে শোনানো এবং ডিরেক্ট রিপ্লাই দেওয়ার জন্য নোটিফিকেশন অ্যাক্সেস পারমিশন দিন।',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _automation.openNotificationListenerSettings(),
            icon: const Icon(Icons.notifications_active, size: 16, color: AppTheme.neonCyan),
            label: Text(active ? 'অনুমতি সেটিংস' : 'অনুমতি প্রদান করুন', style: const TextStyle(color: AppTheme.neonCyan)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.neonCyan),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermuxStatusCard() {
    final active = _termuxInstalled;
    final color = active ? AppTheme.neonEmerald : AppTheme.danger;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.obsidianCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  active ? 'Termux শেল ব্রিজ সংযুক্ত' : 'Termux ইনস্টল করা নেই',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            active
                ? 'কমান্ড লাইন স্ক্রিপ্টিং, পাইথন, অটোমেশন এবং সিস্টেম ম্যানেজমেন্ট ব্যাকগ্রাউন্ডে রেডি।'
                : 'টার্মিনাল এক্সিকিউশন এবং ব্যাকগ্রাউন্ড স্ক্রিপ্টিংয়ের জন্য F-Droid থেকে Termux ইনস্টল করুন।',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildOneTapCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.obsidianCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderViolet),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Auto Re-arm via Shizuku / ADB',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'অ্যান্ড্রয়েডের ব্যাকগ্রাউন্ড ক্লিনার সার্ভিসটি বন্ধ করে দিলে, পারমিশন থাকলে প্রিয়া নিজেই পুনরায় এটি চালু করে নিতে পারে।',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(const ClipboardData(
                text: 'pm grant com.privateagent.private_agent android.permission.WRITE_SECURE_SETTINGS',
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ADB কমান্ড কপি হয়েছে!')),
              );
            },
            icon: const Icon(Icons.copy, size: 16, color: AppTheme.neonCyan),
            label: const Text('ADB কমান্ড কপি করুন', style: TextStyle(color: AppTheme.neonCyan)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.neonCyan),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.obsidianCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderViolet),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'পেমেন্ট ও ব্যাংকিং অ্যাপস সামঞ্জস্যতা',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'bKash, Nagad, Rocket, Upay কিংবা ব্যাংকিং অ্যাপস সিকিউরিটির কারণে অ্যাক্সেসিবিলিটি অন থাকলে খোলে না। এখান থেকে সাময়িকভাবে বন্ধ করে পেমেন্ট সেরে পুনরায় অন করুন।',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _automation.openAccessibilitySettings(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger.withValues(alpha: 0.2),
              foregroundColor: AppTheme.danger,
              side: const BorderSide(color: AppTheme.danger),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('পেমেন্টের জন্য সাময়িক বন্ধ করুন'),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryGuideCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.obsidianCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderViolet),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ব্যাটারি অপ্টিমাইজেশন মুক্ত রাখুন',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Xiaomi, Vivo, Oppo, Realme ফোনে ব্যাকগ্রাউন্ডে সবসময় সক্রিয় রাখতে Autostart অন রাখুন এবং Battery Optimization থেকে "No restrictions" নির্বাচন করুন।',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}
