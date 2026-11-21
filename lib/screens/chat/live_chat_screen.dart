import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../services/task_executor.dart';
import '../../services/voice_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/edge_glow.dart';

/// Maya Live Chat Screen (Route: `chat` — 100% Maya parity).
///
/// Features:
/// - Real-time conversational messaging with Priya / Maya GF persona
/// - Live indicator dot & sound status
/// - Audio replay button on messages (speaks with Maya's neural voice)
/// - Affectionate Bengali emotion tags rendering ([happy], [giggles], [whispers], etc.)
/// - Quick suggestion action chips
/// - Message clear & history management
class LiveChatScreen extends StatefulWidget {
  const LiveChatScreen({super.key});

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  final _executor = TaskExecutor.instance;
  final _voice = VoiceService.instance;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  final List<String> _quickSuggestions = [
    'কেমন আছো বাবু? ❤️',
    'ইউটিউব চালিয়ে দাও 🎬',
    'স্ক্রিনশট নাও 📸',
    'ফেসবুক ওপেন করো 🌐',
    'আজকের আবহাওয়া কেমন? ☀️',
    'আমায় একটা মিষ্টি গান শোনাও 🎶',
    'আমার নোটিফিকেশন পড়ে শোনাও 🔔',
  ];

  @override
  void initState() {
    super.initState();
    _executor.addListener(_onUpdate);
    _voice.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _executor.removeListener(_onUpdate);
    _voice.removeListener(_onUpdate);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) {
      setState(() {});
      _scrollToBottom();
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

  void _sendMessage(String text) {
    final query = text.trim();
    if (query.isEmpty) return;
    _textController.clear();
    _executor.executeTask(query);
    _scrollToBottom();
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151824),
        title: const Text('চ্যাট মুছে ফেলতে চান?', style: TextStyle(color: Colors.white)),
        content: const Text('আপনার বর্তমান কথোপকথনের বার্তাগুলো ক্লিয়ার করা হবে।', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('না', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _executor.chatMessages.clear();
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('মুছে ফেলুন', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = _executor.chatMessages;
    final isBusy = _executor.isChatBusy || _executor.isBusy;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0F18),
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isBusy ? AppTheme.neonMagenta : AppTheme.success,
                boxShadow: [
                  BoxShadow(
                    color: (isBusy ? AppTheme.neonMagenta : AppTheme.success).withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'মায়া লাইভ চ্যাট',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  isBusy
                      ? 'ভাবছি...'
                      : _voice.isSpeaking
                          ? 'কথা বলছি...'
                          : 'অনলাইন • আপনার প্রিয়া',
                  style: TextStyle(
                    fontSize: 11,
                    color: isBusy ? AppTheme.neonMagenta : AppTheme.neonCyan,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'চ্যাট ক্লিয়ার করুন',
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white70),
            onPressed: messages.isNotEmpty ? _clearChat : null,
          ),
        ],
      ),
      body: Stack(
        children: [
          const EdgeGlow(intensity: 0.4),
          Column(
            children: [
              // Message list
              Expanded(
                child: messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          return _buildMessageBubble(msg);
                        },
                      ),
              ),

              // Quick action suggestions
              Container(
                height: 40,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: _quickSuggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    return ActionChip(
                      label: Text(
                        _quickSuggestions[i],
                        style: const TextStyle(fontSize: 12, color: AppTheme.neonCyan),
                      ),
                      backgroundColor: const Color(0xFF141828),
                      side: BorderSide(color: AppTheme.neonCyan.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onPressed: () => _sendMessage(_quickSuggestions[i]),
                    );
                  },
                ),
              ),

              // Bottom input composer
              _buildInputComposer(isBusy),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.neonCyan.withValues(alpha: 0.1),
              border: Border.all(color: AppTheme.neonCyan.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.neonCyan, size: 48),
          ),
          const SizedBox(height: 16),
          const Text(
            'আমি আপনার পাশে আছি বাবু ❤️',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'যেকোনো কথা বলুন বা ফোনের যেকোনো কাজ করতে বলুন!',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    final cleanContent = msg.content
        .replaceAll(RegExp(r'\[happy\]|\[whispers\]|\[crying\]|\[blush\]|\[giggles\]'), '')
        .trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.neonMagenta.withValues(alpha: 0.2),
                border: Border.all(color: AppTheme.neonMagenta, width: 1.5),
              ),
              child: const Center(
                child: Icon(Icons.favorite_rounded, color: AppTheme.neonMagenta, size: 16),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF1E284A) : const Color(0xFF151928),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser
                      ? AppTheme.neonCyan.withValues(alpha: 0.3)
                      : AppTheme.neonMagenta.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    cleanContent,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  if (!isUser) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => _voice.speak(msg.content),
                          child: Row(
                            children: const [
                              Icon(Icons.volume_up_rounded, color: AppTheme.neonCyan, size: 16),
                              SizedBox(width: 4),
                              Text('শুনুন', style: TextStyle(color: AppTheme.neonCyan, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildInputComposer(bool isBusy) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F18),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF171B2B),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.neonCyan.withValues(alpha: 0.25)),
                ),
                child: TextField(
                  controller: _textController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _sendMessage,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'প্রিয়াকে কিছু বলুন বা লিখতে দিন...',
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.neonCyan,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.neonCyan.withValues(alpha: 0.4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
                onPressed: isBusy ? null : () => _sendMessage(_textController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
