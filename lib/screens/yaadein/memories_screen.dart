import 'package:flutter/material.dart';
import '../../services/hermes_memory_service.dart';
import '../../services/settings_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/edge_glow.dart';

/// Maya Memories & Facts Screen (Route: `yaadein` — 100% Maya parity).
///
/// Features:
/// - Categorized & date-grouped list of user facts, preferences, and memories
/// - User profile summary banner (Owner Name, Persona, Voice style)
/// - Add new persistent memory
/// - Delete or edit remembered facts
class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  final _memory = HermesMemoryService.instance;
  final _settings = SettingsService.instance;
  String _selectedTag = 'all';

  @override
  void initState() {
    super.initState();
    _memory.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _memory.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  void _showAddMemoryDialog() {
    final textController = TextEditingController();
    String tag = 'general';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF151824),
          shape: RoundedRectangle.circular(16),
          title: const Row(
            children: [
              Icon(Icons.psychology_rounded, color: AppTheme.neonCyan),
              SizedBox(width: 10),
              Text('নতুন স্মৃতি যোগ করুন', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'প্রিয়া আপনার ব্যাপারে কী মনে রাখবে তা এখানে লিখুন:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'যেমন: আমি প্রতিদিন সকালে চা খাই / আমার প্রিয় গান...',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF1B2032),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                value: tag,
                dropdownColor: const Color(0xFF1B2032),
                style: const TextStyle(color: AppTheme.neonCyan, fontSize: 13),
                items: const [
                  DropdownMenuItem(value: 'general', child: Text('সাধারণ তথ্য')),
                  DropdownMenuItem(value: 'preference', child: Text('পছন্দ-অপছন্দ')),
                  DropdownMenuItem(value: 'routine', child: Text('কাজের অভ্যাস')),
                  DropdownMenuItem(value: 'reminder', child: Text('বিশেষ রিমাইন্ডার')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => tag = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('বাতিল', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = textController.text.trim();
                if (text.isNotEmpty) {
                  await _memory.addMemory(text, tag: tag);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.neonCyan,
                foregroundColor: Colors.black,
              ),
              child: const Text('মনে রাখো'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteMemory(String id) {
    _memory.deleteMemory(id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('স্মৃতিটি মুছে ফেলা হয়েছে'),
        backgroundColor: AppTheme.danger,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allMemories = _memory.memories;
    final filteredMemories = _selectedTag == 'all'
        ? allMemories
        : allMemories.where((m) => m.tag == _selectedTag).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0F18),
        title: const Text('মায়ার স্মৃতি (Yaadein)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppTheme.neonCyan),
            onPressed: _showAddMemoryDialog,
            tooltip: 'নতুন তথ্য যোগ করুন',
          ),
        ],
      ),
      body: Stack(
        children: [
          const EdgeGlow(intensity: 0.35),
          Column(
            children: [
              // User Profile Banner
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF121626),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.neonCyan.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.neonCyan.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_pin_rounded, color: AppTheme.neonCyan, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'মালিক: ${_settings.ownerName} ❤️',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'পার্সোনা: ${_settings.selectedPersona} • মোট স্মৃতি: ${allMemories.length}টি',
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildFilterChip('all', 'সবগুলো (${allMemories.length})'),
                    const SizedBox(width: 8),
                    _buildFilterChip('preference', 'পছন্দ-অপছন্দ'),
                    const SizedBox(width: 8),
                    _buildFilterChip('routine', 'কাজের অভ্যাস'),
                    const SizedBox(width: 8),
                    _buildFilterChip('general', 'সাধারণ নোট'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Memories List
              Expanded(
                child: filteredMemories.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        itemCount: filteredMemories.length,
                        itemBuilder: (context, index) {
                          final item = filteredMemories[index];
                          return _buildMemoryCard(item);
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.neonCyan,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.psychology_rounded),
        label: const Text('নতুন স্মৃতি', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showAddMemoryDialog,
      ),
    );
  }

  Widget _buildFilterChip(String tag, String label) {
    final isSelected = _selectedTag == tag;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedTag = tag),
      selectedColor: AppTheme.neonCyan.withValues(alpha: 0.25),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.neonCyan : Colors.white60,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.neonCyan : Colors.white12,
      ),
      backgroundColor: const Color(0xFF101320),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_rounded, color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          const Text('এই বিভাগে এখনও কোনো স্মৃতি নেই', style: TextStyle(color: Colors.white60, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('প্রিয়া আপনার সাথে কথা বলতে বলতে নিজে থেকেই স্মৃতি জমা করবে।', style: TextStyle(color: Colors.white30, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMemoryCard(HermesMemoryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111422),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.bookmark_rounded, color: AppTheme.neonMagenta, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.content,
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.neonCyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.tag,
                        style: const TextStyle(color: AppTheme.neonCyan, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white30, size: 18),
            onPressed: () => _deleteMemory(item.id),
            tooltip: 'মুছে ফেলুন',
          ),
        ],
      ),
    );
  }
}
