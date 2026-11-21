import 'package:flutter/material.dart';
import '../../services/task_executor.dart';
import '../../theme/app_theme.dart';

/// Pre-compiled Macro Automation Center.
/// 100% mirrors Maya's `builtin_macros.json` and autonomous app driving system.
class MacroCenterScreen extends StatelessWidget {
  const MacroCenterScreen({super.key});

  final List<Map<String, dynamic>> _builtinMacros = const [
    {
      'id': 'chatgpt_image',
      'title': 'ChatGPT Image Maker',
      'intent': 'ChatGPT অ্যাপে ছবি বানিয়ে গ্যালারিতে সেভ করো',
      'app': 'ChatGPT',
      'icon': Icons.image_outlined,
      'color': Color(0xFF10A37F),
      'param': 'ছবির প্রম্পট / image prompt',
    },
    {
      'id': 'gemini_image',
      'title': 'Gemini Image Creator',
      'intent': 'Gemini অ্যাপের ইমেজ টুল দিয়ে ছবি বানিয়ে গ্যালারিতে সেভ করো',
      'app': 'Google Gemini',
      'icon': Icons.auto_awesome,
      'color': Color(0xFF38BDF8),
      'param': 'ছবির প্রম্পট / image prompt',
    },
    {
      'id': 'gemini_video',
      'title': 'Gemini Video Generator',
      'intent': 'Gemini অ্যাপে ভিডিও বানিয়ে সেভ করো',
      'app': 'Google Gemini',
      'icon': Icons.videocam_outlined,
      'color': Color(0xFF818CF8),
      'param': 'ভিডিও প্রম্পট / video prompt',
    },
    {
      'id': 'chatgpt_qa',
      'title': 'ChatGPT Se Poochho',
      'intent': 'ChatGPT অ্যাপে প্রশ্ন করে উত্তর পড়ে শোনাও',
      'app': 'ChatGPT',
      'icon': Icons.chat_bubble_outline,
      'color': Color(0xFF10A37F),
      'param': 'প্রশ্ন / question',
    },
    {
      'id': 'gemini_qa',
      'title': 'Gemini Se Poochho',
      'intent': 'Gemini অ্যাপে প্রশ্ন করে উত্তর পড়ে শোনাও',
      'app': 'Google Gemini',
      'icon': Icons.help_outline,
      'color': Color(0xFF38BDF8),
      'param': 'প্রশ্ন / question',
    },
  ];

  void _triggerMacro(BuildContext context, Map<String, dynamic> macro) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.obsidianElevated,
        title: Text(
          macro['title'],
          style: const TextStyle(color: Colors.white, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Intent: "${macro['intent']}"',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter ${macro['param']}...',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.obsidianCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.borderViolet),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final arg = controller.text.trim();
              Navigator.pop(ctx);
              if (arg.isNotEmpty) {
                TaskExecutor.instance.executeTask('${macro['title']}: $arg');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Started macro: ${macro['title']}')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.neonViolet,
              foregroundColor: Colors.white,
            ),
            child: const Text('Run Macro'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.obsidian,
      appBar: AppBar(
        title: const Text('Macro Automation Center'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Built-in Macros (No Voice Training Needed)',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ..._builtinMacros.map((m) {
            final color = m['color'] as Color;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.obsidianCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderViolet),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Icon(m['icon'], color: color, size: 22),
                ),
                title: Text(
                  m['title'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  m['intent'],
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                trailing: ElevatedButton(
                  onPressed: () => _triggerMacro(context, m),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.obsidianElevated,
                    foregroundColor: AppTheme.neonCyan,
                    side: const BorderSide(color: AppTheme.neonCyan),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('Execute'),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
