import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/screen_automation_service.dart';
import '../../theme/app_theme.dart';

/// Live Terminal Console Reel.
/// 100% mirrors Maya's `TerminalReelActivity` and Termux output stream.
class TerminalReelScreen extends StatefulWidget {
  const TerminalReelScreen({super.key});

  @override
  State<TerminalReelScreen> createState() => _TerminalReelScreenState();
}

class _TerminalReelScreenState extends State<TerminalReelScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<String> _logs = [
    '[Maya Engine] Termux RUN_COMMAND Bridge connected.',
    '[Init] Workdir: /data/data/com.termux/files/home',
    '[Kernel] Standby listening on socket /tmp/maya_agent.sock',
    'Ready for shell automation tasks.'
  ];
  bool _running = false;

  Future<void> _runCommand(String cmd) async {
    final trimmed = cmd.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _logs.add('\$ $trimmed');
      _running = true;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      final res = await ScreenAutomationService.instance.executeTermuxCommand(trimmed);
      if (mounted) {
        setState(() {
          if (res['started'] == true) {
            _logs.add('[Termux Bridge] Dispatched execution #${res['execId']}');
          } else if (res['error'] != null) {
            _logs.add('[Error] ${res['error']}');
          } else {
            _logs.add('[Termux Bridge] Executed command via RunCommandService.');
          }
          _running = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _logs.add('[Error] $e');
          _running = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020204),
      appBar: AppBar(
        title: const Text('Terminal Reel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Clear Console',
            onPressed: () => setState(() => _logs.clear()),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Copy Logs',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _logs.join('\n')));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Console logs copied!')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Header status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.obsidianElevated,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _running ? AppTheme.warning : AppTheme.neonEmerald,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _running ? 'Executing command...' : 'Termux Ready (Session #1)',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),

          // Output logs
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final line = _logs[index];
                final isInput = line.startsWith('\$');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: SelectableText(
                    line,
                    style: TextStyle(
                      color: isInput ? AppTheme.neonCyan : const Color(0xFFE2E8F0),
                      fontSize: 12.5,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                );
              },
            ),
          ),

          // Terminal input bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: const BoxDecoration(
              color: AppTheme.obsidianSurface,
              border: Border(top: BorderSide(color: AppTheme.borderViolet)),
            ),
            child: Row(
              children: [
                const Text(
                  '> ',
                  style: TextStyle(
                    color: AppTheme.neonCyan,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontFamily: 'monospace',
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Enter bash command...',
                      hintStyle: TextStyle(color: AppTheme.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: _runCommand,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_upward, color: AppTheme.neonCyan, size: 20),
                  onPressed: () => _runCommand(_inputController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
