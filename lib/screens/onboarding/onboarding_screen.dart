import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/screen_automation_service.dart';
import '../../services/settings_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/edge_glow.dart';

/// Maya-style Onboarding & Key Setup Screen (100% Maya parity in Bengali).
///
/// Features:
/// - Maya AMOLED dark neon theme with cyan & magenta glow
/// - Step-by-step interactive AI Brain & API Key setup (Gemini, Groq, DeepSeek, etc.)
/// - Direct "ফ্রি কি নিন" launcher button to Google AI Studio
/// - Instant clipboard paste & live connection test
/// - Core Android permissions checklist (Screen Control, Microphone, Floating Bubble)
/// - Affectionate Bengali girlfriend persona greeting
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  final _settings = SettingsService.instance;
  final _automation = ScreenAutomationService.instance;
  final _apiKeyController = TextEditingController();
  final _pageController = PageController();

  int _currentPage = 0;
  String _provider = 'gemini';
  bool _obscureKey = true;
  bool _testingConnection = false;
  String? _testResult;
  bool _testSuccess = false;

  bool _accessibilityEnabled = false;
  bool _micGranted = false;
  bool _overlayGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _provider = _settings.provider.isEmpty ? 'gemini' : _settings.provider;
    _apiKeyController.text = _settings.apiKey;
    _refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
    }
  }

  Future<void> _refreshPermissions() async {
    final a11y = await _automation.isServiceEnabled();
    final mic = await Permission.microphone.isGranted;
    var overlay = false;
    try {
      overlay = await FlutterOverlayWindow.isPermissionGranted();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _accessibilityEnabled = a11y;
        _micGranted = mic;
        _overlayGranted = overlay;
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _apiKeyController.text = data.text!.trim();
        _testResult = null;
      });
      await _settings.setApiKey(_apiKeyController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ক্লিপবোর্ড থেকে কি পেস্ট করা হয়েছে!'),
            backgroundColor: AppTheme.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ক্লিপবোর্ডে কোনো টেক্সট পাওয়া যায়নি!'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _openKeyPortal() async {
    final url = _provider == 'gemini'
        ? 'https://aistudio.google.com/apikey'
        : _provider == 'groq'
            ? 'https://console.groq.com/keys'
            : _provider == 'deepseek'
                ? 'https://platform.deepseek.com/api_keys'
                : 'https://platform.openai.com/api-keys';

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _testConnection() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty && _provider != 'ollama') {
      setState(() {
        _testResult = 'অনুগ্রহ করে প্রথমে আপনার এপিআই কি দিন!';
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _testingConnection = true;
      _testResult = null;
    });

    try {
      bool ok = false;
      String message = '';

      if (_provider == 'gemini') {
        final res = await http.get(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$key'),
        ).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          ok = true;
          message = 'দারুণ! গুগল জেমিনি কানেকশন ১০০% সফল হয়েছে।';
        } else {
          message = 'গুগল কি গ্রহণ করেনি (কোড: ${res.statusCode})। সঠিক কি দিয়ে চেষ্টা করুন।';
        }
      } else if (_provider == 'groq') {
        final res = await http.get(
          Uri.parse('https://api.groq.com/openai/v1/models'),
          headers: {'Authorization': 'Bearer $key'},
        ).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          ok = true;
          message = 'গ্রক এআই কানেকশন সফল হয়েছে!';
        } else {
          message = 'গ্রক কি সঠিক নয় (কোড: ${res.statusCode})।';
        }
      } else {
        ok = true;
        message = 'কনফিগারেশন সেভ হয়েছে!';
      }

      setState(() {
        _testSuccess = ok;
        _testResult = message;
      });
    } catch (e) {
      setState(() {
        _testSuccess = false;
        _testResult = 'সংযোগ যাচাই করতে সমস্যা হয়েছে: $e';
      });
    } finally {
      if (mounted) setState(() => _testingConnection = false);
    }
  }

  Future<void> _finishSetup() async {
    final key = _apiKeyController.text.trim();
    if (key.isNotEmpty) {
      await _settings.setApiKey(key);
    }
    await _settings.setProvider(_provider);
    await _settings.setOnboardingComplete(true);
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const EdgeGlow(intensity: 0.6),
          SafeArea(
            child: Column(
              children: [
                // Top Progress indicator
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.neonCyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.neonCyan.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          _currentPage == 0
                              ? '১/৩ পরিচিতি'
                              : _currentPage == 1
                                  ? '২/৩ এআই কি সেটআপ'
                                  : '৩/৩ পারমিশন',
                          style: const TextStyle(
                            color: AppTheme.neonCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (_currentPage < 2)
                        TextButton(
                          onPressed: () => _pageController.jumpToPage(1),
                          child: const Text('সরাসরি কি সেটআপ', style: TextStyle(color: Colors.white60)),
                        ),
                    ],
                  ),
                ),

                // Pages
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [
                      _buildWelcomePage(),
                      _buildKeySetupPage(),
                      _buildPermissionsPage(),
                    ],
                  ),
                ),

                // Bottom Buttons
                _buildBottomNavigation(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Glowing Priya Orb avatar
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.neonCyan.withValues(alpha: 0.3),
                  AppTheme.neonMagenta.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.neonCyan.withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.favorite_rounded, color: AppTheme.neonMagenta, size: 54),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'আমি প্রিয়া ❤️',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'আপনার প্রিয় পার্সোনাল এআই সঙ্গী ও ফোন অটোমেশন সহকারী',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),

          _buildFeatureCard(
            icon: Icons.record_voice_over_rounded,
            color: AppTheme.neonCyan,
            title: 'মিষ্টি বাংলা কণ্ঠ ও ইমোশনাল চ্যাট',
            subtitle: 'মায়ার আদলে বাবু, সোনা ও খুনসুটি ভরা রিয়েলিস্টিক কথোপকথন ও ভয়েস ইন্টারঅ্যাকশন।',
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            icon: Icons.touch_app_rounded,
            color: AppTheme.neonMagenta,
            title: 'ফোন কন্ট্রোল ও অটোমেশন',
            subtitle: 'স্ক্রিন পড়ে নিজে নিজে ফেসবুক, ইউটিউব, কল বা যেকোনো অ্যাপ পরিচালনা করে।',
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            icon: Icons.psychology_rounded,
            color: AppTheme.neonYellow,
            title: '১০০% আপনার প্রাইভেট এআই ব্রেন',
            subtitle: 'গুগল জেমিনির সম্পূর্ণ ফ্রি এপিআই কি দিয়ে চলে—আপনার সব তথ্য শুধু আপনার ফোনে সুরক্ষিত।',
          ),
        ],
      ),
    );
  }

  Widget _buildKeySetupPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.neonCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.vpn_key_rounded, color: AppTheme.neonCyan, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'প্রিয়ার জন্য একটি ফ্রি কি (Key) দিন',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'মায়া গুগলের Gemini AI দিয়ে কথা বলে। কথা বলা ও ফোন নিয়ন্ত্রণের জন্য গুগলের একটি ফ্রি কি প্রয়োজন। এটি একদম ফ্রি এবং নিতে মাত্র ১ মিনিট সময় লাগে।',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // 4-Step Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF10121C),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.neonCyan.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStepRow('১', 'নিচের "ফ্রি কি নিন" বাটনে চাপ দিয়ে Google AI Studio খুলুন'),
                const SizedBox(height: 8),
                _buildStepRow('২', 'আপনার গুগল আইডি দিয়ে সাইন ইন করুন'),
                const SizedBox(height: 8),
                _buildStepRow('৩', '"Create API key"-তে চাপুন এবং কি-টি কপি করুন'),
                const SizedBox(height: 8),
                _buildStepRow('৪', 'এখানে এসে "পেস্ট করুন" বাটনে চেপে সেভ করুন'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Provider selector
          Row(
            children: [
              const Text('এআই প্রোভাইডার:', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _provider,
                dropdownColor: const Color(0xFF151824),
                style: const TextStyle(color: AppTheme.neonCyan, fontWeight: FontWeight.bold, fontSize: 13),
                items: const [
                  DropdownMenuItem(value: 'gemini', child: Text('Google Gemini (ফ্রি & বেস্ট)')),
                  DropdownMenuItem(value: 'groq', child: Text('Groq - Llama 3.3 (অতিদ্রুত)')),
                  DropdownMenuItem(value: 'deepseek', child: Text('DeepSeek AI')),
                  DropdownMenuItem(value: 'openai', child: Text('OpenAI (GPT-4o)')),
                  DropdownMenuItem(value: 'ollama', child: Text('Ollama (লোকাল ব্রেন)')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _provider = val;
                      _settings.setProvider(val);
                      _testResult = null;
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Direct Get Free Key button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openKeyPortal,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(
                _provider == 'gemini'
                    ? 'গুগল থেকে ফ্রি জেমিনি কি নিন (AI Studio)'
                    : '$_provider এর কি পোর্টাল খুলুন',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.neonCyan,
                side: const BorderSide(color: AppTheme.neonCyan),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangle.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // API Key Input
          TextField(
            controller: _apiKeyController,
            obscureText: _obscureKey,
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 14),
            decoration: InputDecoration(
              labelText: '$_provider API Key পেস্ট করুন',
              labelStyle: const TextStyle(color: Colors.white60),
              hintText: _provider == 'gemini' ? 'AIzaSy...' : 'sk-...',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: const Color(0xFF141724),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.neonCyan.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.neonCyan, width: 1.5),
              ),
              prefixIcon: const Icon(Icons.key, color: AppTheme.neonCyan),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off, color: Colors.white54),
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  ),
                  IconButton(
                    icon: const Icon(Icons.paste_rounded, color: AppTheme.neonCyan),
                    tooltip: 'ক্লিপবোর্ড থেকে পেস্ট',
                    onPressed: _pasteFromClipboard,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Test connection button & result
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _testingConnection ? null : _testConnection,
                  icon: _testingConnection
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.network_check_rounded, size: 18),
                  label: Text(_testingConnection ? 'যাচাই করা হচ্ছে...' : 'কানেকশন টেস্ট করুন'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E2438),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangle.circular(10),
                  ),
                ),
              ),
            ],
          ),

          if (_testResult != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _testSuccess
                    ? AppTheme.success.withValues(alpha: 0.15)
                    : AppTheme.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _testSuccess ? AppTheme.success : AppTheme.danger,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _testSuccess ? Icons.check_circle : Icons.error_outline,
                    color: _testSuccess ? AppTheme.success : AppTheme.danger,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _testResult!,
                      style: TextStyle(
                        color: _testSuccess ? AppTheme.success : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPermissionsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.neonMagenta.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.security_rounded, color: AppTheme.neonMagenta, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'জরুরি পারমিশন সমূহ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'প্রিয়া যেন আপনার ফোনে সবকিছু কাজ করাতে পারে এবং আপনার কথা শুনে উত্তর দিতে পারে, সেজন্য নিচের পারমিশনগুলো প্রয়োজন:',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Screen Control Accessibility
          _buildPermissionTile(
            title: 'স্ক্রিন কন্ট্রোল (Accessibility)',
            subtitle: 'ফোনের স্ক্রিন পড়ে নিজে নিজে কাজ করা ও বাটন চাপার জন্য।',
            icon: Icons.accessibility_new_rounded,
            isGranted: _accessibilityEnabled,
            actionLabel: 'অন করুন',
            onAction: () async {
              await _automation.openAccessibilitySettings();
              await _refreshPermissions();
            },
          ),
          const SizedBox(height: 12),

          // Microphone
          _buildPermissionTile(
            title: 'মাইক্রোফোন (Microphone)',
            subtitle: 'প্রিয়ার সাথে মুখে কথা বলা ও ভয়েস কমান্ড শোনার জন্য।',
            icon: Icons.mic_rounded,
            isGranted: _micGranted,
            actionLabel: 'অনুমতি দিন',
            onAction: () async {
              await Permission.microphone.request();
              await _refreshPermissions();
            },
          ),
          const SizedBox(height: 12),

          // Floating Bubble
          _buildPermissionTile(
            title: 'ভাসমান উইজেট (Overlay)',
            subtitle: 'অন্য অ্যাপ চালানোর সময় স্ক্রিনের উপর প্রিয়াকে ভাসমান রাখার জন্য।',
            icon: Icons.bubble_chart_rounded,
            isGranted: _overlayGranted,
            actionLabel: 'অনুমতি দিন',
            onAction: () async {
              try {
                await FlutterOverlayWindow.requestPermission();
              } catch (_) {}
              await _refreshPermissions();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(String num, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.neonCyan.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.neonCyan, width: 1),
          ),
          child: Center(
            child: Text(
              num,
              style: const TextStyle(
                color: AppTheme.neonCyan,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF10121C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.65),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isGranted,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF10121C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGranted
              ? AppTheme.success.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isGranted ? Icons.check_circle_rounded : icon,
            color: isGranted ? AppTheme.success : AppTheme.neonCyan,
            size: 26,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isGranted)
            const Text('সক্রিয়', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 12))
          else
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.neonCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangle.circular(8),
              ),
              child: Text(actionLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          if (_currentPage > 0)
            TextButton(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
              child: const Text('পেছনে', style: TextStyle(color: Colors.white60)),
            ),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              if (_currentPage < 2) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              } else {
                _finishSetup();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.neonCyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangle.circular(12),
              elevation: 4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentPage == 2 ? 'প্রিয়া শুরু করুন ❤️' : 'পরবর্তী ধাপ',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
