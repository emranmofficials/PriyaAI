import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import '../../services/screen_automation_service.dart';
import '../../services/security_guardian_service.dart';
import '../../services/settings_service.dart';
import '../../services/task_executor.dart';
import '../../services/voice_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/voice_waveform.dart';
import '../history/task_history_screen.dart';
import '../settings/settings_screen.dart';

/// Main screen: unified Priya AI voice hub, live conversation, logs and settings.
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
  final _scrollController = ScrollController();

  bool _serviceEnabled = false;
  bool _overlayActive = false;
  bool _listening = false;
  AppMode _mode = AppMode.chat;
  int _selectedTab = 0;

  bool get _busy => _executor.isBusy || _executor.isChatBusy;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _executor.addListener(_onExecutorUpdate);
    _mode = SettingsService.instance.appMode;
    _refreshStates();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _executor.removeListener(_onExecutorUpdate);
    _inputController.dispose();
    _scrollController.dispose();
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
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _submit(String text, {bool spoke = false}) {
    final goal = text.trim();
    if (goal.isEmpty || _busy) return;
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

    if (_mode == AppMode.genie) {
      _executor.executeTask(goal);
    } else {
      _executor.sendChatMessage(goal, spoke: spoke);
    }
  }

  Future<void> _toggleListening() async {
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
          content: Text(
            'Speech recognition unavailable — check microphone permission.',
          ),
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
          overlayTitle: 'Priya AI',
          overlayContent: 'Agent bubble active',
          enableDrag: true,
          positionGravity: PositionGravity.auto,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Overlay error: $e')));
      }
    }
    await _refreshStates();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: _buildAppBar(theme),
      body: IndexedStack(
        index: _selectedTab,
        children: [
          _priyaMainView(theme),
          const TaskHistoryScreen(isEmbedded: true),
          const SettingsScreen(isEmbedded: true),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(theme),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/priya_icon.png',
              width: 28,
              height: 28,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Image.asset('assets/icon/genie_logo.png', width: 28, height: 28),
            ),
          ),
          const SizedBox(width: 10),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppTheme.textPrimary, AppTheme.purpleLight],
            ).createShader(bounds),
            child: const Text(
              'Priya AI (প্রিয়া)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
          const SizedBox(width: 8),
          ServiceStatusDot(enabled: _serviceEnabled),
        ],
      ),
      actions: [
        if (_selectedTab == 0 && _executor.logs.isNotEmpty)
          IconButton(
            tooltip: 'Clear transcript',
            icon: const Icon(Icons.delete_sweep_outlined, size: 22),
            onPressed: () {
              _executor.clearTranscript();
              setState(() {});
            },
          ),
        IconButton(
          tooltip: _overlayActive
              ? 'Hide floating bubble'
              : 'Show floating bubble',
          onPressed: _toggleOverlay,
          icon: Icon(
            _overlayActive ? Icons.bubble_chart : Icons.bubble_chart_outlined,
            color: _overlayActive ? AppTheme.magentaAccent : null,
          ),
        ),
      ],
    );
  }

  Widget _priyaMainView(ThemeData theme) {
    return Column(
      children: [
        // 1. Unified Dynamic Voice Waveform Hub
        _buildVoiceHub(theme),

        // 2. Service warning if needed
        if (!_serviceEnabled && _mode == AppMode.genie)
          _serviceWarning(theme),

        // 3. Active automation task bar
        if (_executor.isBusy)
          _activeTaskBar(theme),

        // 4. Live conversation / agent transcript
        Expanded(child: _transcript(theme)),

        // 5. Quick action prompt chips (Direct helpers without page jumping)
        _buildQuickChips(theme),

        // 6. Mode Switcher (Genie / Chat)
        _modeSwitcher(theme),

        // 7. Input bar with glowing mic & send
        _inputBar(theme),
      ],
    );
  }

  Widget _buildVoiceHub(ThemeData theme) {
    final isBusy = _executor.isBusy || _executor.isChatBusy;
    final isBengali = SettingsService.instance.voiceLanguage.startsWith('bn');
    final isGf = SettingsService.instance.girlfriendMode;

    final String statusText;
    if (_listening) {
      statusText = isBengali
          ? (isGf ? 'বাবু, আমি শুনছি... বলো সোনা! 💖' : 'শুনছি... বলুন!')
          : 'Listening... speak now';
    } else if (isBusy) {
      statusText = isBengali
          ? (isGf ? 'প্রিয়া ভাবছে ও উত্তর দিচ্ছে... 🥰' : 'প্রিয়া প্রসেস করছে...')
          : 'Priya is thinking...';
    } else {
      statusText = isBengali
          ? (isGf ? 'বাবু, আমি তোমার সাথে আছি! কিছু বলো? ✨' : 'কীভাবে সাহায্য করতে পারি?')
          : 'How can I help you today?';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.obsidianCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (_listening || isBusy)
              ? AppTheme.magentaAccent.withValues(alpha: 0.6)
              : AppTheme.borderViolet.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VoiceWaveform(
            isListening: _listening,
            isSpeaking: isBusy,
            height: 40,
          ),
          const SizedBox(height: 4),
          Text(
            statusText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: (_listening || isBusy)
                  ? AppTheme.magentaAccent
                  : AppTheme.purpleLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChips(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          ActionChip(
            avatar: const Icon(Icons.favorite_rounded, size: 15, color: AppTheme.magentaAccent),
            label: const Text('💖 গল্প করো', style: TextStyle(fontSize: 11.5)),
            backgroundColor: AppTheme.obsidianCard,
            side: BorderSide(color: AppTheme.borderViolet.withValues(alpha: 0.6)),
            onPressed: () {
              setState(() => _mode = AppMode.chat);
              SettingsService.instance.setAppMode(AppMode.chat);
              _submit('বাবু, তুমি কেমন আছো?');
            },
          ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.bolt_rounded, size: 15, color: AppTheme.purpleLight),
            label: const Text('⚡ অ্যাপ অটোমেশন', style: TextStyle(fontSize: 11.5)),
            backgroundColor: AppTheme.obsidianCard,
            side: BorderSide(color: AppTheme.borderViolet.withValues(alpha: 0.6)),
            onPressed: () {
              setState(() => _mode = AppMode.genie);
              SettingsService.instance.setAppMode(AppMode.genie);
              _inputController.text = 'YouTube ওপেন করো';
            },
          ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.terminal_rounded, size: 15, color: AppTheme.cyanAccent),
            label: const Text('💻 কোড !cmd', style: TextStyle(fontSize: 11.5)),
            backgroundColor: AppTheme.obsidianCard,
            side: BorderSide(color: AppTheme.borderViolet.withValues(alpha: 0.6)),
            onPressed: () {
              _inputController.text = '! ';
            },
          ),
          if (_executor.logs.isNotEmpty) ...[
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.cleaning_services_rounded, size: 15, color: AppTheme.textSecondary),
              label: const Text('🧹 ক্লিয়ার', style: TextStyle(fontSize: 11.5)),
              backgroundColor: AppTheme.obsidianCard,
              side: BorderSide(color: AppTheme.borderViolet.withValues(alpha: 0.6)),
              onPressed: () {
                _executor.clearTranscript();
                setState(() {});
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomNav(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.obsidianSurface,
        border: Border(
          top: BorderSide(
            color: AppTheme.borderViolet.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (i) => setState(() => _selectedTab = i),
        backgroundColor: Colors.transparent,
        indicatorColor: AppTheme.purplePrimary.withValues(alpha: 0.25),
        elevation: 0,
        height: 62,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(Icons.favorite_rounded, color: AppTheme.purpleLight),
            label: 'প্রিয়া',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded, color: AppTheme.purpleLight),
            label: 'লগস',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded, color: AppTheme.purpleLight),
            label: 'সেটিংস',
          ),
        ],
      ),
    );
  }

  Widget _serviceWarning(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.warning_amber_rounded, color: AppTheme.warning),
        title: const Text(
          'Accessibility service is off',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: const Text(
          'অটোমেশনের জন্য সার্ভিসটি অন করতে ট্যাপ করুন',
          style: TextStyle(fontSize: 11.5),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => _automation.openAccessibilitySettings(),
      ),
    );
  }

  Widget _activeTaskBar(ThemeData theme) {
    final maxSteps = SettingsService.instance.maxSteps;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppTheme.purplePrimary.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderViolet.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 2.5,
                  value: maxSteps == 0 ? null : _executor.step / maxSteps,
                ),
                Text(
                  '${_executor.step}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _executor.isPaused ? 'Paused' : 'Running task',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  _executor.currentGoal ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: _executor.isPaused ? 'Resume' : 'Pause',
            icon: Icon(
              _executor.isPaused
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded,
            ),
            onPressed: () =>
                _executor.isPaused ? _executor.resume() : _executor.pause(),
          ),
          IconButton(
            tooltip: 'Cancel task',
            icon: const Icon(Icons.stop_rounded, color: AppTheme.danger),
            onPressed: _executor.cancel,
          ),
        ],
      ),
    );
  }

  Widget _transcript(ThemeData theme) {
    if (_executor.logs.isEmpty) {
      final isGenie = _mode == AppMode.genie;
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isGenie ? Icons.auto_awesome : Icons.favorite_rounded,
                size: 50,
                color: AppTheme.purpleLight.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 12),
              Text(
                isGenie
                    ? 'ফোনে কী কাজ করতে চাও সোনা?'
                    : 'প্রিয়া AI এর সাথে কথা বলো',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isGenie
                    ? 'যেমন: “YouTube ওপেন করে গান চালাও”\n'
                          '“WhatsApp-এ মেসেজ পাঠাও”\n'
                          '“Bluetooth অন করো”'
                    : 'আমাকে যা খুশি প্রশ্ন করতে পারো সোনা,\n'
                          'কোডিং, রোমান্টিক গল্প, অনুবাদ অথবা\n'
                          'ফোনের যেকোনো টাস্ক অটোমেশন!',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _executor.logs.length,
      itemBuilder: (_, i) => ChatBubble(message: _executor.logs[i]),
    );
  }

  Widget _inputBar(ThemeData theme) {
    final isGenie = _mode == AppMode.genie;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Row(
          children: [
            // Text Input
            Expanded(
              child: TextField(
                controller: _inputController,
                enabled: !_busy,
                textInputAction: TextInputAction.send,
                onSubmitted: (t) => _submit(t),
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: _busy
                      ? 'অপেক্ষা করো সোনা…'
                      : (isGenie ? 'কাজের বিবরণ দাও…' : 'মেসেজ লেখো…'),
                  prefixIcon: Icon(
                    isGenie ? Icons.bolt_rounded : Icons.chat_bubble_outline_rounded,
                    size: 20,
                    color: AppTheme.purpleLight,
                  ),
                  filled: true,
                  fillColor: AppTheme.obsidianCard,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: AppTheme.borderViolet.withValues(alpha: 0.6)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: AppTheme.borderViolet.withValues(alpha: 0.6)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppTheme.purplePrimary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Glowing Mic Button
            GestureDetector(
              onTap: _busy ? null : _toggleListening,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _listening
                        ? [AppTheme.danger, const Color(0xFFF43F5E)]
                        : [AppTheme.magentaAccent, AppTheme.purplePrimary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_listening ? AppTheme.danger : AppTheme.purplePrimary)
                          .withValues(alpha: 0.5),
                      blurRadius: _listening ? 14 : 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  _listening ? Icons.mic : Icons.mic_none_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),

            const SizedBox(width: 6),

            // Send Button
            IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.purplePrimary,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(10),
              ),
              tooltip: isGenie ? 'Run task' : 'Send',
              onPressed: _busy ? null : () => _submit(_inputController.text),
              icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  /// Genie (agent) / Chat mode switcher shown above the input bar.
  Widget _modeSwitcher(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      child: SegmentedButton<AppMode>(
        showSelectedIcon: false,
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppTheme.purplePrimary.withValues(alpha: 0.25);
            }
            return AppTheme.obsidianCard;
          }),
        ),
        segments: const [
          ButtonSegment(
            value: AppMode.chat,
            icon: Icon(Icons.chat_bubble_outline, size: 16),
            label: Text('💬 প্রিয়া চ্যাট', style: TextStyle(fontSize: 12)),
          ),
          ButtonSegment(
            value: AppMode.genie,
            icon: Icon(Icons.bolt_rounded, size: 16),
            label: Text('⚡ ফোন অটোমেশন', style: TextStyle(fontSize: 12)),
          ),
        ],
        selected: {_mode},
        onSelectionChanged: _busy
            ? null
            : (selection) {
                final mode = selection.first;
                setState(() => _mode = mode);
                SettingsService.instance.setAppMode(mode);
              },
      ),
    );
  }
}
