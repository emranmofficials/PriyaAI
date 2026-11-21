import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import '../../models/chat_message.dart';
import '../../services/macro_runner_service.dart';
import '../../services/priya_driving_service.dart';
import '../../services/priya_wiki_service.dart';
import '../../services/screen_automation_service.dart';
import '../../services/security_guardian_service.dart';
import '../../services/settings_service.dart';
import '../../services/task_executor.dart';
import '../../services/voice_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/edge_glow.dart';
import '../../widgets/maya_orb.dart';
import '../accessibility/accessibility_doctor_screen.dart';
import '../macros/macro_center_screen.dart';
import '../persona/persona_studio_screen.dart';
import '../settings/ai_setup_sheet.dart';
import '../settings/settings_screen.dart';
import '../terminal/terminal_reel_screen.dart';

/// Maya-style Voice & Automation Hub — 100% identical to Maya's signature UI.
///
/// Features:
/// - Screen-wide dynamic [EdgeGlow] neon border
/// - Central procedural HUD [MayaOrb] (rotating gyro rings, acoustic rays, pulsing core)
/// - Floating real-time conversational subtitles & status pill
/// - Floating bottom dock with mic, keyboard drawer, and automation vision
/// - Complete Maya Drawer (Voice Hub, Macros, Termux Reel, A11y Doctor, Persona Studio)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _executor = TaskExecutor.instance;
  final _automation = ScreenAutomationService.instance;
  final _voice = VoiceService.instance;
  final _inputController = TextEditingController();

  bool _serviceEnabled = false;
  bool _overlayActive = false;
  bool _listening = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool get _isThinking => _executor.isChatBusy || _executor.isBusy;
  bool get _isSpeaking => _voice.isSpeaking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _executor.addListener(_onExecutorUpdate);
    _voice.addListener(_onVoiceUpdate);
    _automation.onWakeWordDetected = (wakeWord) async {
      if (!mounted) return;
      await _voice.speak('[happy] বলো বাবু, শুনছি...');
      if (!_listening) {
        _toggleListening();
      }
    };
    _refreshStates();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = SettingsService.instance;
      if (settings.apiKey.trim().isEmpty && settings.provider != 'ollama') {
        AiSetupSheet.show(context);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _automation.onWakeWordDetected = null;
    _executor.removeListener(_onExecutorUpdate);
    _voice.removeListener(_onVoiceUpdate);
    _inputController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshStates();
  }

  Future<void> _refreshStates() async {
    final enabled = await _automation.isServiceEnabled();
    var overlay = false;
    try {
      overlay = await FlutterOverlayWindow.isActive();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _serviceEnabled = enabled;
        _overlayActive = overlay;
      });
    }
  }

  void _onExecutorUpdate() {
    if (mounted) setState(() {});
  }

  void _onVoiceUpdate() {
    if (mounted) setState(() {});
  }

  void _submit(String text, {bool spoke = false}) {
    final goal = text.trim();
    if (goal.isEmpty || _isThinking) return;
    _inputController.clear();

    // Owner security verification check
    final settings = SettingsService.instance;
    if (settings.securityGuardianEnabled &&
        settings.ownerSecretPhrase.isNotEmpty &&
        !SecurityGuardianService.instance.verifyVoiceAuthorization(goal)) {
      SecurityGuardianService.instance.triggerIntruderDefense(
        reason: 'অননুমোদিত কমান্ড: "$goal"',
      );
      return;
    }

    if (goal.startsWith('!')) {
      final cmd = goal.substring(1).trim();
      _executor.executeCommand(cmd);
      return;
    }

    // Maya Unified Flow: Check macro fast path or conversational assistant
    final macro = MacroRunnerService.instance.findMatchingMacro(goal);
    if (macro != null) {
      _executor.executeTask(goal);
    } else {
      _executor.sendChatMessage(goal, spoke: spoke);
    }
  }

  Future<void> _toggleListening() async {
    final settings = SettingsService.instance;
    if (settings.apiKey.trim().isEmpty && settings.provider != 'ollama') {
      await _voice.speak('বাবু, কথা বলার জন্য প্রথমে একটি এআই এপিআই কী সেট করে নাও!');
      if (mounted) {
        AiSetupSheet.show(context);
      }
      return;
    }

    if (_voice.isSpeaking) {
      await _voice.stopSpeaking();
    }
    if (_listening) {
      await _voice.stopListening();
      setState(() => _listening = false);
      return;
    }

    final started = await _voice.startListening(
      onResult: (SpeechRecognitionResult result) {
        if (!mounted) return;
        setState(() {
          _inputController.text = result.recognizedWords;
          if (result.finalResult) {
            _listening = false;
            final spoken = result.recognizedWords.trim();
            if (spoken.isNotEmpty) {
              _submit(spoken, spoke: true);
            }
          }
        });
      },
    );

    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech recognition unavailable — check microphone permission.'),
        ),
      );
    }
    setState(() => _listening = started);
  }

  Future<void> _toggleOverlay() async {
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
      } else {
        final granted = await FlutterOverlayWindow.isPermissionGranted();
        if (!granted) {
          final ok = await FlutterOverlayWindow.requestPermission() ?? false;
          if (!ok) return;
        }
        await FlutterOverlayWindow.showOverlay(
          height: 120,
          width: 120,
          alignment: OverlayAlignment.centerRight,
          flag: OverlayFlag.defaultFlag,
          overlayTitle: 'Maya / Priya AI',
          overlayContent: 'Floating orb active',
          enableDrag: true,
          positionGravity: PositionGravity.auto,
        );
      }
      _refreshStates();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Overlay error: $e')),
        );
      }
    }
  }

  void _showTextInputSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.obsidianElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.chat_bubble_outline, color: AppTheme.neonCyan, size: 20),
                const SizedBox(width: 10),
                const Text(
                  'Command / Message',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _inputController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Type task or question (e.g. Open WhatsApp)...',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.obsidianCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.borderViolet),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send_rounded, color: AppTheme.neonCyan),
                  onPressed: () {
                    final txt = _inputController.text;
                    Navigator.pop(ctx);
                    _submit(txt);
                  },
                ),
              ),
              onSubmitted: (txt) {
                Navigator.pop(ctx);
                _submit(txt);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastMessage = _executor.chatMessages.isNotEmpty ? _executor.chatMessages.last : null;

    return EdgeGlow(
      active: _listening || _isThinking || _isSpeaking,
      isListening: _listening,
      isSpeaking: _isSpeaking,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppTheme.obsidian,
        drawer: _buildMayaDrawer(),
        body: SafeArea(
          child: Stack(
            children: [
              // 1. Main Interactive Voice Canvas
              Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 10),

                            // Glowing AI Setup Banner if no API key is present
                            if (SettingsService.instance.apiKey.trim().isEmpty &&
                                SettingsService.instance.provider != 'ollama') ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                child: GestureDetector(
                                  onTap: () => AiSetupSheet.show(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppTheme.neonMagenta.withValues(alpha: 0.25),
                                          AppTheme.neonViolet.withValues(alpha: 0.25),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppTheme.neonMagenta.withValues(alpha: 0.8),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.neonMagenta.withValues(alpha: 0.35),
                                          blurRadius: 16,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.vpn_key_rounded, color: AppTheme.neonMagenta, size: 24),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'AI ব্রেন সেটআপ করুন 🔑',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                'মায়ার মতো প্রিয়ার বুদ্ধি সচল করতে Gemini বা Groq কী দিন',
                                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppTheme.neonMagenta,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'সেটআপ',
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],

                            // The Signature Maya HUD Orb
                            MayaOrb(
                              size: 240,
                              isListening: _listening,
                              isThinking: _isThinking,
                              isSpeaking: _isSpeaking,
                              onTap: _toggleListening,
                            ),

                            const SizedBox(height: 24),

                            // State & Subtitle Card
                            _buildSubtitleCard(lastMessage),

                            const SizedBox(height: 120), // Bottom padding for dock
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // 2. Floating Bottom Dock (Maya Capsule)
              Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: _buildBottomDock(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          // Drawer Menu Button
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),

          const Spacer(),

          // Status Beacon Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.obsidianElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _listening
                    ? AppTheme.neonCyan
                    : _isSpeaking
                        ? AppTheme.neonMagenta
                        : _serviceEnabled
                            ? AppTheme.neonEmerald.withValues(alpha: 0.5)
                            : AppTheme.borderViolet,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _listening
                        ? AppTheme.neonCyan
                        : _isSpeaking
                            ? AppTheme.neonMagenta
                            : _isThinking
                                ? AppTheme.warning
                                : _serviceEnabled
                                    ? AppTheme.neonEmerald
                                    : AppTheme.danger,
                    boxShadow: [
                      BoxShadow(
                        color: (_listening ? AppTheme.neonCyan : AppTheme.neonEmerald).withValues(alpha: 0.7),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _listening
                      ? 'Listening...'
                      : _isThinking
                          ? 'Thinking...'
                          : _isSpeaking
                              ? 'Speaking...'
                              : 'Live Standby',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Floating Overlay Toggle
          IconButton(
            icon: Icon(
              _overlayActive ? Icons.picture_in_picture_alt : Icons.picture_in_picture_outlined,
              color: _overlayActive ? AppTheme.neonCyan : AppTheme.textSecondary,
              size: 22,
            ),
            tooltip: 'Toggle Floating Orb',
            onPressed: _toggleOverlay,
          ),

          // Quick AI Brain / Key Setup
          IconButton(
            icon: const Icon(Icons.vpn_key_outlined, color: AppTheme.neonCyan, size: 21),
            tooltip: 'AI Brain Setup',
            onPressed: () => AiSetupSheet.show(context),
          ),

          // Settings Gear
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.textSecondary, size: 22),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitleCard(ChatMessage? lastMsg) {
    String captionText = 'ওর্ব-এ ট্যাপ করুন অথবা বলুন "হাই প্রিয়া"';
    if (_listening) {
      captionText = _inputController.text.isNotEmpty ? _inputController.text : 'আমি শুনছি সোনা, বলো... [giggles]';
    } else if (_isThinking) {
      captionText = 'একটু অপেক্ষা করো জান, কাজ করছি...';
    } else if (lastMsg != null) {
      captionText = lastMsg.text;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.obsidianCard.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderViolet.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            captionText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _listening ? AppTheme.neonCyan : Colors.white.withValues(alpha: 0.95),
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          if (_executor.isBusy && _executor.lastGoal.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.neonViolet.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Task: ${_executor.lastGoal}',
                style: const TextStyle(color: AppTheme.neonPurpleLight, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomDock() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.obsidianElevated.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppTheme.borderViolet.withValues(alpha: 0.9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Keyboard Input Button
              IconButton(
                icon: const Icon(Icons.keyboard_outlined, color: AppTheme.textSecondary, size: 24),
                tooltip: 'Type message',
                onPressed: _showTextInputSheet,
              ),

              // Center Glowing Voice Orb Trigger
              GestureDetector(
                onTap: _toggleListening,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _listening
                          ? [AppTheme.neonCyan, AppTheme.neonViolet]
                          : [AppTheme.neonViolet, AppTheme.neonMagenta],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_listening ? AppTheme.neonCyan : AppTheme.neonViolet).withValues(alpha: 0.45),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _listening ? Icons.mic : Icons.mic_none_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),

              // Macro Automation Quick Action
              IconButton(
                icon: const Icon(Icons.auto_awesome_outlined, color: AppTheme.neonCyan, size: 24),
                tooltip: 'Run Macros',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MacroCenterScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMayaDrawer() {
    return Drawer(
      backgroundColor: AppTheme.obsidianSurface,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.borderViolet)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppTheme.neonCyan, AppTheme.neonViolet],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.neonViolet.withValues(alpha: 0.5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.blur_on_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Priya AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Maya Architecture v5.2',
                        style: TextStyle(
                          color: AppTheme.neonCyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 0. AI Brain & Key Setup
            _drawerItem(
              icon: Icons.vpn_key_rounded,
              title: 'AI ব্রেন ও API Key সেটআপ',
              subtitle: 'Google Gemini, Groq, DeepSeek বা OpenAI',
              color: AppTheme.neonMagenta,
              onTap: () {
                Navigator.pop(context);
                AiSetupSheet.show(context);
              },
            ),

            // 1. Voice Hub (Live Orb)
            _drawerItem(
              icon: Icons.graphic_eq_rounded,
              title: 'Voice Hub (Live Orb)',
              subtitle: 'Centerpiece AI Voice Screen',
              color: AppTheme.neonCyan,
              onTap: () => Navigator.pop(context),
            ),

            // 2. Macro Automation Center
            _drawerItem(
              icon: Icons.auto_awesome,
              title: 'Macro Center',
              subtitle: 'Pre-trained App Automations',
              color: AppTheme.neonViolet,
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MacroCenterScreen()),
                );
              },
            ),

            // 3. Termux Terminal Reel
            _drawerItem(
              icon: Icons.terminal,
              title: 'Terminal Reel',
              subtitle: 'Termux Live Shell Output',
              color: AppTheme.neonEmerald,
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TerminalReelScreen()),
                );
              },
            ),

            // 4. Accessibility Doctor
            _drawerItem(
              icon: Icons.healing_outlined,
              title: 'Accessibility Doctor',
              subtitle: 'One-Tap Fix & Service Monitor',
              color: AppTheme.neonMagenta,
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AccessibilityDoctorScreen()),
                );
              },
            ),

            // 5. Voice Persona Studio
            _drawerItem(
              icon: Icons.record_voice_over_outlined,
              title: 'Voice Persona Studio',
              subtitle: 'Maya, Friday & Venom Profiles',
              color: AppTheme.warning,
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PersonaStudioScreen()),
                );
              },
            ),

            // 6. Driving Mode (Hands-Free)
            _drawerItem(
              icon: Icons.directions_car_filled_outlined,
              title: PriyaDrivingService.instance.isDrivingMode
                  ? 'ড্রাইভিং মোড (চালু আছে)'
                  : 'ড্রাইভিং মোড (হ্যান্ডস-ফ্রি)',
              subtitle: 'হ্যান্ডস-ফ্রি অটো কল ও মেসেজ অ্যানাউন্সার',
              color: PriyaDrivingService.instance.isDrivingMode
                  ? AppTheme.neonEmerald
                  : AppTheme.textSecondary,
              onTap: () async {
                Navigator.pop(context);
                await PriyaDrivingService.instance.toggleDrivingMode();
                if (mounted) setState(() {});
              },
            ),

            const Divider(color: AppTheme.borderViolet, height: 28),

            // 7. Maya Settings Hub
            _drawerItem(
              icon: Icons.settings_suggest_rounded,
              title: 'মায়া সেটিংস হাব (Settings Hub)',
              subtitle: 'AI Brain, Voice, Romance & System',
              color: AppTheme.neonCyan,
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
    );
  }
}
