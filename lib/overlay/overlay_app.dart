import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../theme/app_theme.dart';

/// Root widget of the overlay engine (runs in its own isolate, see
/// `overlayMain()` in main.dart).
///
/// Collapsed: a small draggable bubble.
/// Expanded: a glassmorphism panel with the live transcript, task controls
/// and a command input. State and commands travel over
/// [FlutterOverlayWindow.shareData] / [FlutterOverlayWindow.overlayListener].
class OverlayApp extends StatefulWidget {
  const OverlayApp({super.key});

  @override
  State<OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<OverlayApp> {
  static const _bubbleSize = 110;
  static const _panelWidth = 340;
  static const _panelHeight = 520;

  final _inputController = TextEditingController();
  final _speech = SpeechToText();

  StreamSubscription<dynamic>? _subscription;

  bool _expanded = false;
  bool _listening = false;
  String _goal = '';
  String _state = 'idle';
  int _step = 0;
  int _maxSteps = 15;
  List<Map<String, dynamic>> _messages = [];

  bool get _busy => _state == 'running' || _state == 'paused';

  @override
  void initState() {
    super.initState();
    _subscription =
        FlutterOverlayWindow.overlayListener.listen(_onMainAppEvent);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _inputController.dispose();
    super.dispose();
  }

  void _onMainAppEvent(dynamic event) {
    if (event is! String) return;
    try {
      final decoded = jsonDecode(event);
      if (decoded is! Map) return;
      if (decoded['type'] == 'state') {
        setState(() {
          _goal = decoded['goal']?.toString() ?? _goal;
          _state = decoded['state']?.toString() ?? _state;
          _step = decoded['step'] is int ? decoded['step'] as int : _step;
          _maxSteps = decoded['maxSteps'] is int
              ? decoded['maxSteps'] as int
              : _maxSteps;
          final msgs = decoded['messages'];
          if (msgs is List) {
            _messages = msgs.whereType<Map>().map((m) {
              return m.map((k, v) => MapEntry('$k', v));
            }).toList();
          }
        });
      }
    } catch (_) {}
  }

  void _sendCommand(Map<String, dynamic> payload) {
    FlutterOverlayWindow.shareData(jsonEncode({
      'type': 'command',
      ...payload,
    }));
  }

  Future<void> _expand() async {
    setState(() => _expanded = true);
    await FlutterOverlayWindow.resizeOverlay(
        _panelWidth, _panelHeight, false);
    // focusPointer lets the text field open the keyboard.
    await FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);
  }

  Future<void> _collapse() async {
    setState(() => _expanded = false);
    await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
    await FlutterOverlayWindow.resizeOverlay(_bubbleSize, _bubbleSize, true);
  }

  Future<void> _toggleVoice() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    try {
      final ready = await _speech.initialize();
      if (!ready) return;
      setState(() => _listening = true);
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          if (!mounted) return;
          setState(() {
            _inputController.text = result.recognizedWords;
            if (result.finalResult) _listening = false;
          });
        },
      );
    } catch (_) {
      if (mounted) setState(() => _listening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: Material(
        type: MaterialType.transparency,
        child: _expanded ? _buildPanel() : _buildBubble(),
      ),
    );
  }

  Widget _buildBubble() {
    final running = _busy;
    return Center(
      child: GestureDetector(
        onTap: _expand,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.magentaAccent, AppTheme.purplePrimary],
            ),
            border: Border.all(color: Colors.white24, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.purplePrimary.withValues(alpha: 0.5),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.favorite_rounded, color: Colors.white, size: 28),
              if (running)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanel() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.obsidianSurface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.borderViolet.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                _panelHeader(),
                const Divider(height: 1, color: Colors.white12),
                Expanded(child: _panelTranscript()),
                const Divider(height: 1, color: Colors.white12),
                _panelInput(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _panelHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
      child: Row(
        children: [
          const Icon(Icons.favorite_rounded, size: 18, color: AppTheme.magentaAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Priya AI',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                Text(
                  _busy
                      ? '${_state == 'paused' ? 'Paused' : 'Running'} — '
                          'step $_step/$_maxSteps'
                      : 'Idle — ask me anything',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
          if (_busy) ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: _state == 'paused' ? 'Resume' : 'Pause',
              icon: Icon(
                _state == 'paused'
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                color: Colors.white70,
                size: 20,
              ),
              onPressed: () => _sendCommand({
                'command': _state == 'paused' ? 'resume' : 'pause',
              }),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Cancel',
              icon: const Icon(Icons.stop_rounded,
                  color: Colors.redAccent, size: 20),
              onPressed: () => _sendCommand({'command': 'cancel'}),
            ),
          ],
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Collapse',
            icon: const Icon(Icons.close_fullscreen,
                color: Colors.white70, size: 18),
            onPressed: _collapse,
          ),
        ],
      ),
    );
  }
  Widget _panelTranscript() {
    if (_messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'No active task.\nType a command below or tap the mic.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final m = _messages[i];
        final role = '${m['role']}';
        final text = '${m['text']}';
        final isUser = role == 'user';
        final isError = role == 'error';
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            constraints: const BoxConstraints(maxWidth: 260),
            decoration: BoxDecoration(
              color: isUser
                  ? AppTheme.indigo
                  : isError
                      ? AppTheme.danger.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (m['step'] != null)
                  Text('step ${m['step']}',
                      style: const TextStyle(
                          color: AppTheme.indigoLight,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                Text(
                  text,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11.5, height: 1.35),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _panelInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              enabled: !_busy,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
              textInputAction: TextInputAction.send,
              onSubmitted: _submit,
              decoration: InputDecoration(
                isDense: true,
                hintText: _busy ? 'Agent is working…' : 'Command…',
                hintStyle:
                    const TextStyle(color: Colors.white38, fontSize: 12.5),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Voice',
            onPressed: _busy ? null : _toggleVoice,
            icon: Icon(
              _listening ? Icons.mic : Icons.mic_none,
              color: _listening ? Colors.redAccent : Colors.white70,
              size: 19,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Run',
            onPressed:
                _busy ? null : () => _submit(_inputController.text),
            icon: const Icon(Icons.send_rounded,
                color: AppTheme.indigoLight, size: 19),
          ),
        ],
      ),
    );
  }

  void _submit(String text) {
    final goal = text.trim();
    if (goal.isEmpty || _busy) return;
    _inputController.clear();
    _sendCommand({'command': 'start', 'goal': goal});
  }
}
