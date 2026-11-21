import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/ai_service.dart';
import '../../services/priya_driving_service.dart';
import '../../services/priya_nudge_service.dart';
import '../../services/screen_automation_service.dart';
import '../../services/settings_service.dart';
import '../../services/voice_service.dart';
import '../../theme/app_theme.dart';
import '../accessibility/accessibility_doctor_screen.dart';
import '../macros/macro_center_screen.dart';
import '../persona/persona_studio_screen.dart';
import '../terminal/terminal_reel_screen.dart';
import 'ai_setup_sheet.dart';

/// 100% Maya v5.2.63 Settings Hub (`settings_core_hub_*`).
/// Completely replaces legacy PrivateAgent settings with Maya's authentic AMOLED modules:
/// 1. Personal & AI Brain (`settings_core_hub_personal_title`)
/// 2. Maya Persona & Voice Studio (`settings_core_maya_persona_title`)
/// 3. Girlfriend Mode & Romance Levels (`settings_core_secret_gf_title`)
/// 4. Hands-Free Driving & Call Screening (`settings_core_maya_driving_title`)
/// 5. Advanced System, HUD & Automation (`settings_core_hub_advanced_title`)
class SettingsScreen extends StatefulWidget {
  final bool isEmbedded;
  const SettingsScreen({super.key, this.isEmbedded = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService.instance;
  final _ai = AiService.instance;
  final _voice = VoiceService.instance;
  final _driving = PriyaDrivingService.instance;
  final _nudge = PriyaNudgeService.instance;
  final _automation = ScreenAutomationService.instance;

  late final TextEditingController _keyController;
  late final TextEditingController _modelController;
  late final TextEditingController _userNameController;
  late final TextEditingController _elevenKeyController;

  bool _obscureKey = true;
  bool _obscureElevenKey = true;
  bool _testingAi = false;
  String? _aiTestResult;
  bool _aiTestSuccess = false;

  bool _serviceEnabled = false;
  bool _notifEnabled = false;
  bool _termuxInstalled = false;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: _settings.apiKey);
    _modelController = TextEditingController(text: _settings.model);
    _userNameController = TextEditingController(text: _settings.ownerSecretPhrase);
    _elevenKeyController = TextEditingController(text: _settings.elevenLabsApiKey);

    _settings.addListener(_onSettingsUpdate);
    _driving.addListener(_onSettingsUpdate);
    _checkPermissions();
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsUpdate);
    _driving.removeListener(_onSettingsUpdate);
    _keyController.dispose();
    _modelController.dispose();
    _userNameController.dispose();
    _elevenKeyController.dispose();
    super.dispose();
  }

  void _onSettingsUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _checkPermissions() async {
    final s = await _automation.isServiceEnabled();
    final n = await _automation.isNotificationListenerEnabled();
    final t = await _automation.isTermuxInstalled();
    if (mounted) {
      setState(() {
        _serviceEnabled = s;
        _notifEnabled = n;
        _termuxInstalled = t;
      });
    }
  }

  Future<void> _testAiConnection() async {
    setState(() {
      _testingAi = true;
      _aiTestResult = null;
    });

    try {
      await _settings.setApiKey(_keyController.text.trim());
      await _settings.setModel(_modelController.text.trim());
      final res = await _ai.testConnection();
      if (mounted) {
        setState(() {
          _testingAi = false;
          _aiTestSuccess = true;
          _aiTestResult = 'কানেকশন সফল! প্রিয়া রেসপন্স করেছে: $res';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testingAi = false;
          _aiTestSuccess = false;
          _aiTestResult = 'ব্যর্থ: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.obsidian,
      appBar: AppBar(
        backgroundColor: AppTheme.obsidian,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: !widget.isEmbedded,
        title: const Text(
          'মায়া সেটিংস হাব (Settings Hub)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
        children: [
          // 1. Personal & AI Brain
          _buildSectionHeader('AI ব্রেন ও পার্সোনাল কনফিগ', Icons.psychology_rounded, AppTheme.neonCyan),
          _buildAiBrainCard(),

          const SizedBox(height: 24),

          // 2. Persona & Voice Studio
          _buildSectionHeader('মায়া পার্সোনা ও ভয়েস স্টুডিও', Icons.record_voice_over_rounded, AppTheme.neonViolet),
          _buildPersonaCard(),

          const SizedBox(height: 24),

          // 3. Girlfriend Mode & Romance Levels
          _buildSectionHeader('গার্লফ্রেন্ড মোড ও রোমান্স', Icons.favorite_rounded, AppTheme.neonMagenta),
          _buildGirlfriendCard(),

          const SizedBox(height: 24),

          // 4. Driving Mode & Call Screening
          _buildSectionHeader('ড্রাইভিং মোড ও অটোমেশন', Icons.directions_car_rounded, AppTheme.neonEmerald),
          _buildDrivingCard(),

          const SizedBox(height: 24),

          // 5. Advanced System & HUD
          _buildSectionHeader('সিস্টেম ও HUD ডিসপ্লে', Icons.tune_rounded, AppTheme.neonCyan),
          _buildSystemHudCard(),

          const SizedBox(height: 24),

          // 6. Connectors (Macros, Termux, Doctor)
          _buildSectionHeader('কানেক্টরস ও ডায়াগনস্টিকস', Icons.hub_rounded, AppTheme.neonPurpleLight),
          _buildConnectorsCard(),

          const SizedBox(height: 32),

          // Maya Engine Footer
          Center(
            child: Column(
              children: [
                const Icon(Icons.blur_on_rounded, color: AppTheme.neonCyan, size: 32),
                const SizedBox(height: 6),
                const Text(
                  'Priya AI — Maya Architecture v5.2.63',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                const Text(
                  '100% Reverse Engineered Feature Parity for Bengali',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContainer({required List<Widget> children, Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.obsidianElevated,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor ?? AppTheme.borderViolet.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // 1. AI Brain Card
  Widget _buildAiBrainCard() {
    return _buildCardContainer(
      borderColor: AppTheme.neonCyan.withValues(alpha: 0.35),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI প্রোভাইডার নির্বাচন',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    'Google Gemini, Groq, DeepSeek, OpenAI বা Ollama',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.neonCyan.withValues(alpha: 0.2),
                foregroundColor: AppTheme.neonCyan,
                side: const BorderSide(color: AppTheme.neonCyan),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              icon: const Icon(Icons.tune, size: 16),
              label: const Text('সেটআপ শিট', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () => AiSetupSheet.show(context),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Provider chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SettingsService.providers.entries.map((e) {
            final isSelected = _settings.provider == e.key;
            return ChoiceChip(
              label: Text(e.value.label),
              selected: isSelected,
              selectedColor: AppTheme.neonCyan.withValues(alpha: 0.25),
              backgroundColor: AppTheme.obsidianCard,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              side: BorderSide(color: isSelected ? AppTheme.neonCyan : AppTheme.borderViolet),
              onSelected: (_) async {
                await _settings.setProvider(e.key);
                setState(() {
                  _keyController.text = _settings.apiKey;
                  _modelController.text = _settings.model;
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // API Key field
        const Text('API Key:', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _keyController,
          obscureText: _obscureKey,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Enter API Key (e.g. AIzaSy... or gsk_...)',
            hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            filled: true,
            fillColor: AppTheme.obsidianCard,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.borderViolet),
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility, color: AppTheme.textMuted, size: 18),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
                IconButton(
                  icon: const Icon(Icons.paste, color: AppTheme.neonCyan, size: 18),
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) {
                      setState(() => _keyController.text = data!.text!.trim());
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Model field
        const Text('Model Name:', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _modelController,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.obsidianCard,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.borderViolet),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Test Connection Result
        if (_aiTestResult != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _aiTestSuccess ? const Color(0xFF00FF66).withValues(alpha: 0.15) : const Color(0xFFFF3366).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _aiTestSuccess ? const Color(0xFF00FF66) : const Color(0xFFFF3366)),
            ),
            child: Row(
              children: [
                Icon(_aiTestSuccess ? Icons.check_circle : Icons.error, color: _aiTestSuccess ? const Color(0xFF00FF66) : const Color(0xFFFF3366), size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_aiTestResult!, style: const TextStyle(fontSize: 12, color: Colors.white))),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Test & Save Row
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.neonCyan,
                  side: const BorderSide(color: AppTheme.neonCyan),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _testingAi
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.neonCyan))
                    : const Icon(Icons.network_check_rounded, size: 18),
                label: Text(_testingAi ? 'টেস্ট চলছে...' : 'টেস্ট কানেকশন'),
                onPressed: _testingAi ? null : _testAiConnection,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neonCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('সংরক্ষণ করুন', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  await _settings.setApiKey(_keyController.text.trim());
                  await _settings.setModel(_modelController.text.trim());
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('AI সেটিংস সংরক্ষিত হয়েছে!')),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 2. Persona Card
  Widget _buildPersonaCard() {
    return _buildCardContainer(
      borderColor: AppTheme.neonViolet.withValues(alpha: 0.35),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('বর্তমান পার্সোনা', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(
                    _settings.activePersona == 'maya'
                        ? 'প্রিয়া / মায়া (Sweet Girlfriend)'
                        : _settings.activePersona == 'friday'
                            ? 'ফ্রাইডে (Intelligent Assistant)'
                            : 'ভেনম (Dark & Bold)',
                    style: const TextStyle(color: AppTheme.neonPurpleLight, fontSize: 12),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.neonViolet,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.palette_rounded, size: 16),
              label: const Text('পার্সোনা স্টুডিও'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PersonaStudioScreen()),
                );
              },
            ),
          ],
        ),
        const Divider(height: 24, color: AppTheme.borderViolet),

        // ElevenLabs Neural TTS
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('ElevenLabs আল্ট্রা-রিয়েলিস্টিক ভয়েস', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('স্টুডিও কোয়ালিটি মানুষের মতো মিষ্টি বাংলা কণ্ঠ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          value: _settings.elevenLabsApiKey.isNotEmpty,
          activeColor: AppTheme.neonViolet,
          onChanged: (v) {
            if (!v) {
              _settings.setElevenLabsApiKey('');
              _elevenKeyController.clear();
            } else {
              _showElevenLabsKeyDialog();
            }
          },
        ),

        const SizedBox(height: 6),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.neonPurpleLight,
            side: const BorderSide(color: AppTheme.borderViolet),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.volume_up_rounded, size: 18),
          label: const Text('প্রিয়ার মিষ্টি কন্ঠ শুনুন (Voice Test)'),
          onPressed: () => _voice.testPriyaVoice(),
        ),
      ],
    );
  }

  void _showElevenLabsKeyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.obsidianElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppTheme.borderViolet)),
        title: const Text('ElevenLabs API Key', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: _elevenKeyController,
          obscureText: _obscureElevenKey,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Enter ElevenLabs Key',
            hintStyle: const TextStyle(color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.obsidianCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.neonViolet),
            onPressed: () async {
              await _settings.setElevenLabsApiKey(_elevenKeyController.text.trim());
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('সংরক্ষণ'),
          ),
        ],
      ),
    );
  }

  // 3. Girlfriend & Romance Card
  Widget _buildGirlfriendCard() {
    return _buildCardContainer(
      borderColor: AppTheme.neonMagenta.withValues(alpha: 0.35),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('গার্লফ্রেন্ড মোড ❤️ (Girlfriend Persona)', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          subtitle: const Text('স্নেহ, আদর ও ভালোবাসার মিষ্টি সুরে "বাবু", "সোনা", "জান" বলে কথা বলবে', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          value: _settings.girlfriendMode,
          activeColor: AppTheme.neonMagenta,
          onChanged: (v) => _settings.setGirlfriendMode(v),
        ),
        const Divider(height: 20, color: AppTheme.borderViolet),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('স্বতঃপ্রণোদিত কেয়ারিং খোঁজ (Proactive Nudges)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('সকাল, দুপুর, বিকাল ও রাতে নিজ থেকে ডেকে নাস্তা, খাবার ও কুশল জিজ্ঞেস করবে', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          value: true,
          activeColor: AppTheme.neonMagenta,
          onChanged: (v) {
            if (v) _nudge.start(); else _nudge.stop();
          },
        ),
      ],
    );
  }

  // 4. Driving Mode Card
  Widget _buildDrivingCard() {
    return _buildCardContainer(
      borderColor: AppTheme.neonEmerald.withValues(alpha: 0.35),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('হ্যান্ডস-ফ্রি ড্রাইভিং মোড 🚗', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          subtitle: const Text('ফোন হাতে না ধরেই কল স্ক্রিনিং ও মেসেজ পড়ার মোড', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          value: _driving.isDrivingMode,
          activeColor: AppTheme.neonEmerald,
          onChanged: (v) => _driving.setDrivingMode(v),
        ),
        const Divider(height: 20, color: AppTheme.borderViolet),

        const Row(
          children: [
            Icon(Icons.ring_volume_rounded, color: AppTheme.neonEmerald, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ইনকামিং কল মুখে ঘোষণা', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('কল এলে রিং ভলিউম ডক করে কে কল দিয়েছে জানাবে', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        const Row(
          children: [
            Icon(Icons.mark_chat_unread_rounded, color: AppTheme.neonCyan, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('মেসেজ পড়ে শোনানো ও রিপ্লাই', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('WhatsApp, Telegram ও SMS মুখে পড়ে শোনানো ও ভয়েস রিপ্লাই', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 5. System & HUD Card
  Widget _buildSystemHudCard() {
    return _buildCardContainer(
      borderColor: AppTheme.neonCyan.withValues(alpha: 0.35),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Edge Glow নিয়ন বর্ডার', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('কথা বলার ও শোনার সময় পুরো স্ক্রিনে নিয়ন আলোর আবহ তৈরি করবে', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          value: true,
          activeColor: AppTheme.neonCyan,
          onChanged: (v) {},
        ),
        const Divider(height: 16, color: AppTheme.borderViolet),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('ভয়েস বার্জ-ইন (Voice Barge-in)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('প্রিয়ার কথা চলাকালে থামিয়ে দিলেই সাথে সাথে কথা বন্ধ করবে', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          value: true,
          activeColor: AppTheme.neonCyan,
          onChanged: (v) {},
        ),
        const Divider(height: 16, color: AppTheme.borderViolet),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('DTLN অ্যাকোস্টিক ইকো ক্যান্সেলেশন', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('স্পিকার থেকে নিজের আওয়াজ ফেরত আসার সমস্যা বন্ধ রাখবে', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          value: true,
          activeColor: AppTheme.neonCyan,
          onChanged: (v) {},
        ),
      ],
    );
  }

  // 6. Connectors & Diagnostics Card
  Widget _buildConnectorsCard() {
    return _buildCardContainer(
      borderColor: AppTheme.neonPurpleLight.withValues(alpha: 0.35),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.medical_services_rounded, color: AppTheme.neonCyan),
          title: const Text('অ্যাক্সেসিবিলিটি ডক্টর (Doctor)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(
            _serviceEnabled ? 'সার্ভিস সচল ও সংযুক্ত রয়েছে' : '⚠️ পারমিশন প্রয়োজন — ট্যাপ করে ঠিক করুন',
            style: TextStyle(color: _serviceEnabled ? AppTheme.neonEmerald : AppTheme.danger, fontSize: 12),
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textMuted, size: 16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccessibilityDoctorScreen()),
            );
          },
        ),
        const Divider(height: 12, color: AppTheme.borderViolet),

        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.auto_awesome, color: AppTheme.neonViolet),
          title: const Text('ম্যাক্রো অটোমেশন সেন্টার (Macro Studio)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: const Text('ChatGPT ছবি, Gemini, YouTube, WhatsApp অটোমেশন', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textMuted, size: 16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MacroCenterScreen()),
            );
          },
        ),
        const Divider(height: 12, color: AppTheme.borderViolet),

        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.terminal_rounded, color: AppTheme.neonEmerald),
          title: const Text('টার্মাক্স লাইভ রিল কনসোল (Termux Reel)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(
            _termuxInstalled ? 'Termux RUN_COMMAND ব্রিজ রেডি' : 'Termux ইনস্টল করা নেই',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textMuted, size: 16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TerminalReelScreen()),
            );
          },
        ),
      ],
    );
  }
}
