import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import '../../models/task_history_entry.dart';
import '../../services/screen_automation_service.dart';
import '../../services/security_guardian_service.dart';
import '../../services/settings_service.dart';
import '../../services/task_executor.dart';
import '../../services/voice_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/status_chip.dart';
import '../history/task_history_screen.dart';
import '../sessions/session_detail_screen.dart';
import '../settings/settings_screen.dart';
import 'dashboard_tab.dart';

/// Main screen: live task transcript, task input with voice, overlay toggle.
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
  AppMode _mode = AppMode.genie;
  int _selectedTab = 0;

  /// True while either an agent task or a chat reply is in flight.
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

  void _submit(String text) {
    final goal = text.trim();
    if (goal.isEmpty || _busy) return;
    _inputController.clear();
    if (_selectedTab != 1) {
      setState(() => _selectedTab = 1);
    }

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
      _executor.sendChatMessage(goal);
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
          if (result.finalResult) _listening = false;
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
      drawer: _sessionsDrawer(theme),
      appBar: _buildAppBar(theme),
      body: IndexedStack(
        index: _selectedTab,
        children: [
          DashboardTab(
            isListening: _listening,
            serviceEnabled: _serviceEnabled,
            overlayActive: _overlayActive,
            onToggleVoice: _toggleVoice,
            onOpenKeyboard: () {
              setState(() => _selectedTab = 1);
            },
            onOpenAutomation: () {
              setState(() {
                _mode = AppMode.genie;
                _selectedTab = 1;
              });
            },
            onOpenCoding: () {
              setState(() {
                _selectedTab = 1;
                _inputController.text = '! ';
              });
            },
            onOpenVoiceChat: () {
              setState(() {
                _mode = AppMode.chat;
                _selectedTab = 1;
              });
              _toggleVoice();
            },
            onOpenTools: () {
              setState(() => _selectedTab = 3);
            },
            onToggleOverlay: _toggleOverlay,
          ),
          _chatAndAutomationView(theme),
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
              width: 30,
              height: 30,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Image.asset('assets/icon/genie_logo.png', width: 30, height: 30),
            ),
          ),
          const SizedBox(width: 10),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppTheme.textPrimary, AppTheme.purpleLight],
            ).createShader(bounds),
            child: const Text(
              'Priya AI',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.2),
            ),
          ),
          const SizedBox(width: 8),
          ServiceStatusDot(enabled: _serviceEnabled),
        ],
      ),
      actions: [
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

  Widget _chatAndAutomationView(ThemeData theme) {
    return Column(
      children: [
        if (!_serviceEnabled && _mode == AppMode.genie)
          _serviceWarning(theme),
        if (_executor.isBusy) _activeTaskBar(theme),
        Expanded(child: _transcript(theme)),
        _modeSwitcher(theme),
        _inputBar(theme),
      ],
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
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppTheme.purpleLight),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded, color: AppTheme.purpleLight),
            label: 'Chat & Auto',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded, color: AppTheme.purpleLight),
            label: 'Logs',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded, color: AppTheme.purpleLight),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Sessions sidebar (navigation drawer)
  // ------------------------------------------------------------------

  Widget _sessionsDrawer(ThemeData theme) {
    final entries = _executor.historyEntries;
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/priya_banner.png',
                      height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          'assets/images/priya_icon.png',
                          width: 26,
                          height: 26,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/icon/genie_logo.png',
                            width: 26,
                            height: 26,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Priya AI',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chat sessions',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (_executor.isBusy)
              ListTile(
                dense: true,
                leading: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                title: Text(
                  _executor.currentGoal ?? 'Running task…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Live session in progress',
                  style: TextStyle(fontSize: 11),
                ),
                onTap: () => Navigator.of(context).pop(),
              ),
            ListTile(
              leading: const Icon(Icons.add_comment_outlined),
              title: const Text(
                'New chat',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Clear the live transcript',
                style: TextStyle(fontSize: 11),
              ),
              enabled: !_executor.isBusy,
              onTap: () {
                Navigator.of(context).pop();
                _executor.clearTranscript();
              },
            ),
            const Divider(indent: 12, endIndent: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Text(
                'RECENT SESSIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Text(
                  'No saved sessions yet.\nRun a task and it will appear here.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
            for (final entry in entries) _sessionTile(theme, entry),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _sessionTile(ThemeData theme, TaskHistoryEntry entry) {
    final (icon, color) = switch (entry.status) {
      TaskStatus.success => (Icons.check_circle_outline, Colors.green),
      TaskStatus.failed => (Icons.error_outline, AppTheme.danger),
      TaskStatus.cancelled => (
        Icons.stop_circle_outlined,
        theme.colorScheme.onSurfaceVariant,
      ),
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        entry.goal,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        DateFormat.MMMd().add_Hm().format(entry.startedAt),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: IconButton(
        tooltip: 'Delete session',
        icon: const Icon(Icons.delete_outline, size: 18),
        onPressed: () => _executor.deleteHistoryEntry(entry.id),
      ),
      onTap: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SessionDetailScreen(entryId: entry.id),
          ),
        );
      },
    );
  }

  Widget _serviceWarning(ThemeData theme) {
    return Material(
      color: AppTheme.danger.withValues(alpha: 0.12),
      child: ListTile(
        dense: true,
        leading: const Icon(
          Icons.warning_amber_rounded,
          color: AppTheme.danger,
        ),
        title: const Text(
          'Accessibility service is off',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: const Text(
          'Tap to open settings and enable it',
          style: TextStyle(fontSize: 12),
        ),
        onTap: () => _automation.openAccessibilitySettings(),
      ),
    );
  }

  Widget _activeTaskBar(ThemeData theme) {
    final maxSteps = SettingsService.instance.maxSteps;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 3,
                  value: maxSteps == 0 ? null : _executor.step / maxSteps,
                ),
                Text(
                  '${_executor.step}',
                  style: const TextStyle(
                    fontSize: 11,
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
                    fontSize: 13,
                  ),
                ),
                Text(
                  _executor.currentGoal ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isGenie ? Icons.smart_toy_outlined : Icons.chat_outlined,
                size: 56,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                isGenie
                    ? 'What should I do on your phone?'
                    : 'Chat with Priya AI',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isGenie
                    ? 'Try: “Open WhatsApp and send a message to Mom”\n'
                          '“Open YouTube and play lofi music”\n'
                          '“Open Settings and turn on Bluetooth”'
                    : 'Ask me anything — questions, ideas, writing,\n'
                          'translations…\n'
                          'Switch to Genie mode to control your phone.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: _executor.logs.length,
      itemBuilder: (_, i) => ChatBubble(message: _executor.logs[i]),
    );
  }

  Widget _inputBar(ThemeData theme) {
    final isGenie = _mode == AppMode.genie;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                enabled: !_busy,
                textInputAction: TextInputAction.send,
                onSubmitted: _submit,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: _busy
                      ? (isGenie ? 'Genie is working…' : 'Thinking…')
                      : (isGenie ? 'Describe a task…' : 'Message…'),
                  prefixIcon: const Icon(Icons.chat_bubble_outline, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Voice input',
              onPressed: _busy ? null : _toggleListening,
              icon: Icon(_listening ? Icons.mic : Icons.mic_none),
              color: _listening ? AppTheme.danger : null,
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              tooltip: isGenie ? 'Run task' : 'Send',
              onPressed: _busy ? null : () => _submit(_inputController.text),
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }

  /// Genie (agent) / Chat mode switcher shown above the input bar.
  Widget _modeSwitcher(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: SegmentedButton<AppMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: AppMode.genie,
            icon: Icon(Icons.auto_awesome, size: 18),
            label: Text('Genie'),
            tooltip: 'Agent mode — controls your phone',
          ),
          ButtonSegment(
            value: AppMode.chat,
            icon: Icon(Icons.chat_bubble_outline, size: 18),
            label: Text('Chat'),
            tooltip: 'Chat mode — plain conversation',
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
