import 'package:flutter/material.dart';

import '../../services/settings_service.dart';
import '../../services/telegram_service.dart';

/// Settings: AI provider, agent loop, Telegram remote control, appearance.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService.instance;
  final _telegram = TelegramService.instance;

  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late final TextEditingController _tokenController;
  late final TextEditingController _chatsController;
  late final TextEditingController _ownerPhraseController;

  bool _obscureKey = true;
  bool _obscureToken = true;

  /// Provider seen during the last settings notification. The Base URL /
  /// Model fields are only re-synced when this actually changes (i.e. the
  /// user tapped a different provider chip) — never on unrelated updates,
  /// which would wipe unsaved edits.
  String _lastSyncedProvider = '';
  List<String> _ollamaModels = const [];
  bool _loadingOllamaModels = false;

  Future<void> _checkOllamaModels() async {
    if (!mounted) return;
    setState(() => _loadingOllamaModels = true);
    final models = await _settings.fetchOllamaModels(
      customBaseUrl: _baseUrlController.text,
    );
    if (!mounted) return;
    setState(() {
      _ollamaModels = models;
      _loadingOllamaModels = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(text: _settings.baseUrl);
    _apiKeyController = TextEditingController(text: _settings.apiKey);
    _modelController = TextEditingController(text: _settings.model);
    _tokenController = TextEditingController(text: _settings.telegramToken);
    _chatsController =
        TextEditingController(text: _settings.telegramAllowedChats.join(', '));
    _ownerPhraseController =
        TextEditingController(text: _settings.ownerSecretPhrase);
    _lastSyncedProvider = _settings.provider;
    // Rebuild so the Save button's enabled state tracks unsaved edits.
    for (final c in [
      _baseUrlController,
      _apiKeyController,
      _modelController,
    ]) {
      c.addListener(_onAiFieldChanged);
    }
    _settings.addListener(_onSettingsChanged);
    _telegram.addListener(_onTelegramChanged);

    if (_settings.provider.contains('ollama') || _settings.baseUrl.contains('11434')) {
      _checkOllamaModels();
    }
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _telegram.removeListener(_onTelegramChanged);
    for (final c in [
      _baseUrlController,
      _apiKeyController,
      _modelController,
    ]) {
      c.removeListener(_onAiFieldChanged);
    }
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _tokenController.dispose();
    _chatsController.dispose();
    _ownerPhraseController.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    // Only overwrite the text fields when the provider chip changed (its
    // preset rewrites Base URL + Model). Unrelated updates (sliders,
    // switches, saving, …) must never clobber unsaved edits.
    if (_settings.provider != _lastSyncedProvider) {
      _lastSyncedProvider = _settings.provider;
      _baseUrlController.text = _settings.baseUrl;
      _modelController.text = _settings.model;
      if (_settings.provider.contains('ollama')) {
        _checkOllamaModels();
      }
    }
    setState(() {});
  }

  void _onTelegramChanged() {
    if (mounted) setState(() {});
  }

  /// Rebuilds when the AI text fields are edited (Save button state).
  void _onAiFieldChanged() {
    if (mounted) setState(() {});
  }

  /// True when Base URL / API key / Model differ from the stored values.
  bool get _aiDirty =>
      _baseUrlController.text.trim() != _settings.baseUrl ||
      _apiKeyController.text.trim() != _settings.apiKey ||
      _modelController.text.trim() != _settings.model;

  Future<void> _saveAiSettings() async {
    await _settings.setBaseUrl(_baseUrlController.text);
    await _settings.setApiKey(_apiKeyController.text);
    await _settings.setModel(_modelController.text);
    if (!mounted) return;
    setState(() {}); // refresh the button's enabled state
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('AI provider settings saved'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _sectionTitle('AI Provider'),
          _aiProviderCard(),
          const SizedBox(height: 20),
          _sectionTitle('Agent'),
          _agentCard(),
          const SizedBox(height: 20),
          _sectionTitle('Telegram Remote Control'),
          _telegramCard(),
          const SizedBox(height: 20),
          _sectionTitle('Appearance'),
          _appearanceCard(),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );

  Widget _aiProviderCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in SettingsService.providers.entries)
                  ChoiceChip(
                    label: Text(entry.value.label),
                    selected: _settings.provider == entry.key,
                    onSelected: (_) => _settings.setProvider(entry.key),
                  ),
              ],
            ),
            if (_settings.provider.contains('ollama') || _baseUrlController.text.contains('11434')) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bolt, size: 20, color: Colors.amber),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Local Ollama (Termux / 100% Offline)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        if (_loadingOllamaModels)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 18),
                            tooltip: 'Detect Installed Models',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _checkOllamaModels,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'No API key required! Runs offline on your phone via Termux ("ollama serve").',
                      style: TextStyle(fontSize: 12),
                    ),
                    if (_ollamaModels.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Detected Models (Tap to use):',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final m in _ollamaModels)
                            ActionChip(
                              avatar: Icon(
                                _modelController.text == m
                                    ? Icons.check_circle
                                    : Icons.smart_toy_outlined,
                                size: 16,
                              ),
                              label: Text(m, style: const TextStyle(fontSize: 12)),
                              onPressed: () {
                                _modelController.text = m;
                                setState(() {});
                              },
                            ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 6),
                      TextButton.icon(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        icon: const Icon(Icons.search, size: 16),
                        label: const Text('Detect models on 127.0.0.1:11434', style: TextStyle(fontSize: 12)),
                        onPressed: _checkOllamaModels,
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _baseUrlController,
              enabled: true, // preset values are just defaults — always editable
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'https://api.example.com/v1',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureKey,
              decoration: InputDecoration(
                labelText: (_settings.provider.contains('ollama') || _baseUrlController.text.contains('11434'))
                    ? 'API key (Not needed for Ollama)'
                    : 'API key',
                hintText: (_settings.provider.contains('ollama') || _baseUrlController.text.contains('11434'))
                    ? 'Leave empty for local Ollama'
                    : null,
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_obscureKey
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureKey = !_obscureKey),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelController,
              decoration: InputDecoration(
                labelText: 'Model',
                hintText: _settings.provider.contains('ollama') ? 'qwen2.5:0.5b' : 'deepseek-chat',
                prefixIcon: const Icon(Icons.psychology_outlined),
              ),
            ),
            const SizedBox(height: 12),
            // Explicit save: provider fields are only persisted on tap.
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _aiDirty ? _saveAiSettings : null,
                icon: const Icon(Icons.save_outlined),
                label: Text(_aiDirty ? 'Save changes' : 'Saved'),
              ),
            ),
            if (_aiDirty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Unsaved changes — press Save to apply.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Send system prompt',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Recommended — teaches the model the action JSON format',
                  style: TextStyle(fontSize: 12)),
              value: _settings.useSystemPrompt,
              onChanged: (v) => _settings.setUseSystemPrompt(v),
            ),
            const Divider(),
            _sliderRow(
              label: 'Temperature',
              value: _settings.temperature,
              min: 0,
              max: 2,
              divisions: 20,
              format: (v) => v.toStringAsFixed(1),
              onChanged: (v) => _settings.setTemperature(v),
            ),
            _sliderRow(
              label: 'Max tokens',
              value: _settings.maxTokens.toDouble(),
              min: 256,
              max: 4096,
              divisions: 15,
              format: (v) => v.round().toString(),
              onChanged: (v) => _settings.setMaxTokens(v.round()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) format,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: format(value),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(format(value),
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
  Widget _agentCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _sliderRow(
              label: 'Max steps',
              value: _settings.maxSteps.toDouble(),
              min: 3,
              max: 40,
              divisions: 37,
              format: (v) => v.round().toString(),
              onChanged: (v) => _settings.setMaxSteps(v.round()),
            ),
            _sliderRow(
              label: 'Step delay',
              value: _settings.stepDelayMs.toDouble(),
              min: 200,
              max: 5000,
              divisions: 24,
              format: (v) => '${(v / 1000).toStringAsFixed(1)}s',
              onChanged: (v) => _settings.setStepDelayMs(v.round()),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Skill memory (macro replay)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Replay previously successful tasks without AI calls',
                  style: TextStyle(fontSize: 12)),
              value: _settings.skillsEnabled,
              onChanged: (v) => _settings.setSkillsEnabled(v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hermes persistent memory',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Learn user preferences, device facts & recovery patterns',
                  style: TextStyle(fontSize: 12)),
              value: _settings.hermesMemoryEnabled,
              onChanged: (v) => _settings.setHermesMemoryEnabled(v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Voice feedback',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text('Speak task results aloud',
                  style: TextStyle(fontSize: 12)),
              value: _settings.voiceFeedback,
              onChanged: (v) => _settings.setVoiceFeedback(v),
            ),
            const Divider(height: 16),
            Row(
              children: [
                const Text('Voice language / ভাষা',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'bn-BD', label: Text('বাংলা')),
                    ButtonSegment(value: 'en-US', label: Text('English')),
                  ],
                  selected: {_settings.voiceLanguage},
                  onSelectionChanged: (set) =>
                      _settings.setVoiceLanguage(set.first),
                ),
              ],
            ),
            const Divider(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('গার্লফ্রেন্ড মোড ❤️ (Girlfriend Persona)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'স্নেহ, ভালোবাসা ও কেয়ারিং সুরে মিষ্টি বাংলায় কথা বলবে',
                  style: TextStyle(fontSize: 12)),
              value: _settings.girlfriendMode,
              onChanged: (v) => _settings.setGirlfriendMode(v),
            ),
            const Divider(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Anti-Theft Security Guardian',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Locks phone, warns intruder in Bengali & alerts Telegram',
                  style: TextStyle(fontSize: 12)),
              value: _settings.securityGuardianEnabled,
              onChanged: (v) => _settings.setSecurityGuardianEnabled(v),
            ),
            if (_settings.securityGuardianEnabled) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _ownerPhraseController,
                decoration: const InputDecoration(
                  labelText: 'Owner Voice Passphrase / Keyword',
                  hintText: 'যেমন: ইমরান, mysecretcode',
                  helperText: 'Commands without this phrase will lock the phone',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => _settings.setOwnerSecretPhrase(v),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _telegramCard() {
    final running = _telegram.isRunning;
    final owner = _settings.telegramOwnerChatId;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Telegram control',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(
                  running ? 'Bot is polling for commands' : 'Bot is stopped',
                  style: const TextStyle(fontSize: 12)),
              value: _settings.telegramEnabled,
              onChanged: (v) async {
                await _settings.setTelegramEnabled(v);
                if (v) {
                  await _telegram.start();
                } else {
                  _telegram.stop();
                }
              },
            ),
            TextField(
              controller: _tokenController,
              obscureText: _obscureToken,
              onChanged: (v) async {
                await _settings.setTelegramToken(v);
                if (_settings.telegramEnabled) await _telegram.restart();
              },
              decoration: InputDecoration(
                labelText: 'Bot token (from @BotFather)',
                prefixIcon: const Icon(Icons.send_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_obscureToken
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureToken = !_obscureToken),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _chatsController,
              onChanged: (v) => _settings.setTelegramAllowedChats(
                v.split(RegExp(r'[,\s]+')).where((s) => s.isNotEmpty).toList(),
              ),
              decoration: const InputDecoration(
                labelText: 'Allowed chat IDs (comma separated)',
                hintText: 'Leave empty to pair with the first chat',
                prefixIcon: Icon(Icons.group_outlined),
              ),
            ),
            if (owner.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.link,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Paired owner chat: $owner',
                        style: const TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () => _settings.setTelegramOwnerChatId(''),
                    child: const Text('Unpair'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  Widget _appearanceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Theme',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.brightness_auto)),
                ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_outlined)),
                ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_outlined)),
              ],
              selected: {_settings.themeMode},
              onSelectionChanged: (s) => _settings.setThemeMode(s.first),
            ),
          ],
        ),
      ),
    );
  }
}
