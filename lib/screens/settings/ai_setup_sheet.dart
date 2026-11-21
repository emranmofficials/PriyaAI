import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/ai_service.dart';
import '../../services/settings_service.dart';
import '../../services/voice_service.dart';
import '../../theme/app_theme.dart';

/// Maya-style Interactive AI Brain & API Key Setup BottomSheet.
/// Allows instant configuration of Gemini, Groq, DeepSeek, OpenAI, or Ollama.
class AiSetupSheet extends StatefulWidget {
  const AiSetupSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AiSetupSheet(),
    );
  }

  @override
  State<AiSetupSheet> createState() => _AiSetupSheetState();
}

class _AiSetupSheetState extends State<AiSetupSheet> {
  final _settings = SettingsService.instance;
  final _ai = AiService.instance;
  final _voice = VoiceService.instance;

  late String _selectedProvider;
  late final TextEditingController _keyController;
  late final TextEditingController _modelController;

  bool _obscureKey = true;
  bool _testing = false;
  String? _testResult;
  bool _testSuccess = false;

  final Map<String, ({String name, String badge, String keyUrl, String defaultModel, String hint, IconData icon})> _providerMeta = {
    'gemini': (
      name: 'Google Gemini',
      badge: 'ফ্রি ও দ্রুততম (Recommended)',
      keyUrl: 'https://aistudio.google.com/apikey',
      defaultModel: 'gemini-3.8-flash',
      hint: 'AIzaSy... দিয়ে শুরু হওয়া কী দিন',
      icon: Icons.auto_awesome,
    ),
    'groq': (
      name: 'Groq',
      badge: 'আল্ট্রা-ফাস্ট (Free Llama 3.3)',
      keyUrl: 'https://console.groq.com/keys',
      defaultModel: 'llama-3.3-70b-versatile',
      hint: 'gsk_... দিয়ে শুরু হওয়া কী দিন',
      icon: Icons.bolt,
    ),
    'deepseek': (
      name: 'DeepSeek',
      badge: 'স্মার্ট ও সস্তা',
      keyUrl: 'https://platform.deepseek.com/api_keys',
      defaultModel: 'deepseek-chat',
      hint: 'sk-... দিয়ে শুরু হওয়া কী দিন',
      icon: Icons.psychology,
    ),
    'openai': (
      name: 'OpenAI',
      badge: 'GPT-4o / GPT-4o-mini',
      keyUrl: 'https://platform.openai.com/api-keys',
      defaultModel: 'gpt-4o-mini',
      hint: 'sk-... দিয়ে শুরু হওয়া কী দিন',
      icon: Icons.bubble_chart,
    ),
    'ollama': (
      name: 'Ollama (Termux)',
      badge: '১০০% অফলাইন (নো কী)',
      keyUrl: '',
      defaultModel: 'qwen2.5:0.5b',
      hint: 'টার্মাক্সে "ollama serve" চললে অটো কানেক্ট',
      icon: Icons.terminal_rounded,
    ),
  };

  @override
  void initState() {
    super.initState();
    _selectedProvider = _settings.provider;
    if (!_providerMeta.containsKey(_selectedProvider)) {
      _selectedProvider = 'gemini';
    }
    _keyController = TextEditingController(text: _settings.apiKey);
    _modelController = TextEditingController(text: _settings.model);

    if (_modelController.text.trim().isEmpty) {
      _modelController.text = _providerMeta[_selectedProvider]?.defaultModel ?? 'gemini-3.8-flash';
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _onSelectProvider(String key) {
    setState(() {
      _selectedProvider = key;
      final meta = _providerMeta[key];
      if (meta != null) {
        _modelController.text = meta.defaultModel;
      }
      _testResult = null;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      setState(() {
        _keyController.text = text;
        // Auto-detect provider
        if (text.startsWith('AIzaSy')) {
          _selectedProvider = 'gemini';
          _modelController.text = 'gemini-3.8-flash';
        } else if (text.startsWith('gsk_')) {
          _selectedProvider = 'groq';
          _modelController.text = 'llama-3.3-70b-versatile';
        }
      });
    }
  }

  Future<void> _openKeyUrl() async {
    final meta = _providerMeta[_selectedProvider];
    if (meta == null || meta.keyUrl.isEmpty) return;
    final uri = Uri.parse(meta.keyUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _runTest() async {
    final key = _keyController.text.trim();
    if (_selectedProvider != 'ollama' && key.isEmpty) {
      setState(() {
        _testResult = 'অনুগ্রহ করে প্রথমে আপনার এপিআই কী পেস্ট করুন।';
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _testing = true;
      _testResult = null;
    });

    try {
      // Temporarily apply to test
      await _settings.setProvider(_selectedProvider);
      await _settings.setApiKey(key);
      await _settings.setModel(_modelController.text.trim());

      final reply = await _ai.testConnection();
      setState(() {
        _testing = false;
        _testSuccess = true;
        _testResult = 'সংযোগ সফল! প্রিয়া রেসপন্স করেছে: $reply';
      });
    } catch (e) {
      setState(() {
        _testing = false;
        _testSuccess = false;
        _testResult = 'কানেকশন ব্যর্থ: $e';
      });
    }
  }

  Future<void> _saveAndClose() async {
    final key = _keyController.text.trim();
    await _settings.setProvider(_selectedProvider);
    await _settings.setApiKey(key);
    await _settings.setModel(_modelController.text.trim());

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI ব্রেন হিসেবে ${_providerMeta[_selectedProvider]?.name} সফলভাবে সেট হয়েছে!'),
          backgroundColor: AppTheme.neonCyan.withValues(alpha: 0.8),
        ),
      );
    }

    await _voice.speak('[happy] ধন্যবাদ বাবু! আমি এখন তোমার সাথে কথা বলতে সম্পূর্ণ প্রস্তুত সোনা!');
  }

  @override
  Widget build(BuildContext context) {
    final meta = _providerMeta[_selectedProvider] ?? _providerMeta['gemini']!;
    final isOllama = _selectedProvider == 'ollama';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.obsidianElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppTheme.borderViolet.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.neonViolet.withValues(alpha: 0.25),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.neonCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.psychology_alt_rounded, color: AppTheme.neonCyan, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI ব্রেন ও API Key সেটআপ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        'মায়ার মতো প্রিয়ার বুদ্ধি সচল করতে কী সেট করুন',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Provider Selector
            const Text(
              'পছন্দের AI প্রোভাইডার বেছে নিন:',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _providerMeta.entries.map((entry) {
                  final isSelected = _selectedProvider == entry.key;
                  return GestureDetector(
                    onTap: () => _onSelectProvider(entry.key),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.neonCyan.withValues(alpha: 0.2)
                            : AppTheme.obsidianCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppTheme.neonCyan : AppTheme.borderViolet,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(entry.value.icon, color: isSelected ? AppTheme.neonCyan : AppTheme.textSecondary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            entry.value.name,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppTheme.textSecondary,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Provider Badge / Description Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.obsidianCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderViolet),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.neonPurpleLight, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${meta.name}: ${meta.badge}',
                      style: const TextStyle(color: AppTheme.neonPurpleLight, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (meta.keyUrl.isNotEmpty)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(Icons.open_in_new, size: 14, color: AppTheme.neonCyan),
                      label: const Text('কী নিন', style: TextStyle(color: AppTheme.neonCyan, fontSize: 12)),
                      onPressed: _openKeyUrl,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // API Key Input Field (Hidden for Ollama)
            if (!isOllama) ...[
              const Text(
                'API Key:',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _keyController,
                obscureText: _obscureKey,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: meta.hint,
                  hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: AppTheme.obsidianCard,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.borderViolet),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.neonCyan, width: 1.5),
                  ),
                  prefixIcon: const Icon(Icons.key, color: AppTheme.neonCyan, size: 20),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _obscureKey ? Icons.visibility_off : Icons.visibility,
                          color: AppTheme.textMuted,
                          size: 18,
                        ),
                        onPressed: () => setState(() => _obscureKey = !_obscureKey),
                      ),
                      IconButton(
                        icon: const Icon(Icons.content_paste, color: AppTheme.neonCyan, size: 18),
                        tooltip: 'Paste from clipboard',
                        onPressed: _pasteFromClipboard,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Model Selection
            const Text(
              'Model Name:',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _modelController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.obsidianCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.borderViolet),
                ),
                prefixIcon: const Icon(Icons.memory, color: AppTheme.neonViolet, size: 20),
              ),
            ),
            const SizedBox(height: 16),

            // Live Test Result Box
            if (_testResult != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _testSuccess
                      ? const Color(0xFF00FF66).withValues(alpha: 0.12)
                      : const Color(0xFFFF3366).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _testSuccess ? const Color(0xFF00FF66) : const Color(0xFFFF3366),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _testSuccess ? Icons.check_circle : Icons.error_outline,
                      color: _testSuccess ? const Color(0xFF00FF66) : const Color(0xFFFF3366),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          color: _testSuccess ? const Color(0xFF00FF66) : const Color(0xFFFF3366),
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Action Buttons (Test & Save)
            Row(
              children: [
                // Test Connection Button
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.neonCyan,
                      side: const BorderSide(color: AppTheme.neonCyan),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.neonCyan),
                          )
                        : const Icon(Icons.speed, size: 18),
                    label: Text(_testing ? 'টেস্ট চলছে...' : 'টেস্ট কানেকশন'),
                    onPressed: _testing ? null : _runTest,
                  ),
                ),
                const SizedBox(width: 12),

                // Save & Connect Button
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.neonViolet,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: const Text(
                      'সেভ ও কানেক্ট',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: _saveAndClose,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
