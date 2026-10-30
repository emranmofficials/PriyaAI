import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/screen_automation_service.dart';
import '../../services/settings_service.dart';
import '../../theme/app_theme.dart';

/// Multi-page first-run guide: welcome, accessibility setup, AI provider
/// setup and runtime permissions.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  final _pageController = PageController();
  final _automation = ScreenAutomationService.instance;
  final _settings = SettingsService.instance;
  final _apiKeyController = TextEditingController();

  int _page = 0;
  bool _serviceEnabled = false;
  String _provider = 'deepseek';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _provider = _settings.provider;
    _apiKeyController.text = _settings.apiKey;
    _refreshServiceState();
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
    if (state == AppLifecycleState.resumed) _refreshServiceState();
  }

  Future<void> _refreshServiceState() async {
    final enabled = await _automation.isServiceEnabled();
    if (mounted) setState(() => _serviceEnabled = enabled);
  }

  void _next() {
    if (_page < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await _settings.setOnboardingComplete(true);
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  ...List.generate(
                    4,
                    (i) => Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i <= _page
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline
                                  .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _welcomePage(theme),
                  _accessibilityPage(theme),
                  _aiPage(theme),
                  _permissionsPage(theme),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_page > 0)
                    TextButton(
                      onPressed: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      ),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    child: Text(_page == 3 ? 'Get Started' : 'Continue'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _pageShell(ThemeData theme,
      {required IconData icon,
      required String title,
      required String subtitle,
      required List<Widget> children}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 32, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 20),
          Text(title,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant, height: 1.5)),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _welcomePage(ThemeData theme) {
    return _pageShell(
      theme,
      icon: Icons.smart_toy_outlined,
      title: 'Meet Priya AI',
      subtitle: 'An on-device automation agent that turns natural language '
          'into real actions on your phone — powered by your own LLM API key. '
          'Nothing is shared except what goes to the provider you choose.',
      children: [
        _featureRow(theme, Icons.touch_app_outlined, 'Sees your screen',
            'Reads the accessibility tree of any app to understand what is on screen.'),
        _featureRow(theme, Icons.psychology_outlined, 'Thinks with an LLM',
            'DeepSeek, OpenRouter, NVIDIA NIM or a local Ollama decide the next tap, swipe or input.'),
        _featureRow(theme, Icons.bolt_outlined, 'Learns your routines',
            'Successful tasks are memorized and replayed instantly, without API calls.'),
        _featureRow(theme, Icons.send_outlined, 'Remote control',
            'Optionally drive your phone from a Telegram chat, with screenshots.'),
      ],
    );
  }

  Widget _featureRow(
      ThemeData theme, IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accessibilityPage(ThemeData theme) {
    return _pageShell(
      theme,
      icon: Icons.accessibility_new_outlined,
      title: 'Enable screen control',
      subtitle: 'Priya AI works through an Android accessibility service. '
          'This is what lets it read the screen and tap buttons for you.',
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  _serviceEnabled
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color:
                      _serviceEnabled ? AppTheme.success : AppTheme.danger,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _serviceEnabled
                        ? 'Priya AI Screen Control is enabled'
                        : 'Priya AI Screen Control is OFF',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Re-check',
                  onPressed: _refreshServiceState,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _automation.openAccessibilitySettings(),
          icon: const Icon(Icons.settings_accessibility),
          label: const Text('Open Accessibility Settings'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _automation.openAppInfoSettings(),
          icon: const Icon(Icons.info_outline),
          label: const Text('Open App Info (Android 13+ restricted settings)'),
        ),
        const SizedBox(height: 16),
        Text(
          'On Android 13 and newer you may need to open App Info → ⋮ menu → '
          '"Allow restricted settings" first, then enable "Priya AI '
          'Screen Control" under Accessibility → Downloaded apps.',
          style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant, height: 1.5),
        ),
      ],
    );
  }
  Widget _aiPage(ThemeData theme) {
    return _pageShell(
      theme,
      icon: Icons.key_outlined,
      title: 'Connect an AI brain',
      subtitle: 'Pick an OpenAI-compatible provider and paste your API key. '
          'You can change this any time in Settings.',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in SettingsService.providers.entries)
              ChoiceChip(
                label: Text(entry.value.label),
                selected: _provider == entry.key,
                onSelected: (_) {
                  setState(() => _provider = entry.key);
                  _settings.setProvider(entry.key);
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_provider == 'ollama')
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Ollama runs fully on your machine — no API key needed. '
              'Start it with OLLAMA_HOST=0.0.0.0 ollama serve, then use '
              'adb reverse tcp:11434 tcp:11434 so the phone can reach it.',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant, height: 1.5),
            ),
          ),
        TextField(
          controller: _apiKeyController,
          obscureText: true,
          onChanged: (v) => _settings.setApiKey(v),
          decoration: const InputDecoration(
            labelText: 'API key',
            hintText: 'sk-…',
            prefixIcon: Icon(Icons.vpn_key_outlined),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'The key is stored only on this device. The model can be changed '
          'later (default: ${_settings.model}).',
          style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant, height: 1.5),
        ),
      ],
    );
  }

  Widget _permissionsPage(ThemeData theme) {
    return _pageShell(
      theme,
      icon: Icons.verified_user_outlined,
      title: 'Optional permissions',
      subtitle: 'These unlock voice commands, the floating bubble, '
          'notifications and contact search. Skip anything you don\'t need.',
      children: [
        _permissionTile(
          theme,
          icon: Icons.mic_none,
          title: 'Microphone',
          subtitle: 'Speak tasks instead of typing them',
          onTap: () async {
          await Permission.microphone.request();
        },
        ),
        _permissionTile(
          theme,
          icon: Icons.notifications_none,
          title: 'Notifications',
          subtitle: 'Task progress and completion alerts',
          onTap: () async {
            await Permission.notification.request();
          },
        ),
        _permissionTile(
          theme,
          icon: Icons.contacts_outlined,
          title: 'Contacts',
          subtitle: '“Call Mom”-style commands',
          onTap: () async {
            await Permission.contacts.request();
          },
        ),
        _permissionTile(
          theme,
          icon: Icons.bubble_chart_outlined,
          title: 'Floating bubble',
          subtitle: 'Control the agent while using other apps',
          onTap: () async {
            await FlutterOverlayWindow.requestPermission();
          },
        ),
      ],
    );
  }

  Widget _permissionTile(ThemeData theme,
      {required IconData icon,
      required String title,
      required String subtitle,
      required Future<void> Function() onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          try {
            await onTap();
          } catch (_) {}
        },
      ),
    );
  }
}
