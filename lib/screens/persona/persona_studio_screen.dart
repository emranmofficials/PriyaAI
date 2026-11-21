import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../../services/voice_service.dart';
import '../../theme/app_theme.dart';

/// Persona Voice Selection & Studio.
/// 100% mirrors Maya's `maya_*`, `friday_*`, and `venom_*` persona engines.
class PersonaStudioScreen extends StatefulWidget {
  const PersonaStudioScreen({super.key});

  @override
  State<PersonaStudioScreen> createState() => _PersonaStudioScreenState();
}

class _PersonaStudioScreenState extends State<PersonaStudioScreen> {
  String _selectedPersona = 'maya';

  @override
  void initState() {
    super.initState();
    _selectedPersona = SettingsService.instance.activePersona;
  }

  final List<Map<String, dynamic>> _personas = const [
    {
      'id': 'maya',
      'name': 'Priya / Maya',
      'tagline': 'Soft, caring, expressive & affectionate AI companion',
      'color': AppTheme.neonViolet,
      'icon': Icons.favorite_border,
      'pitch': 1.15,
      'speed': 1.0,
      'sample': 'হাই বাবু! [giggles] আমি সবসময় তোমার পাশে আছি। বলো আজ কি করতে হবে?',
    },
    {
      'id': 'friday',
      'name': 'Friday (F.R.I.D.A.Y.)',
      'tagline': 'High-tech, precise, ultra-fast automation assistant',
      'color': AppTheme.neonCyan,
      'icon': Icons.bolt,
      'pitch': 1.0,
      'speed': 1.1,
      'sample': 'Systems online. All protocols operational, boss.',
    },
    {
      'id': 'venom',
      'name': 'Venom / Shadow',
      'tagline': 'Deep, intense, bold and raw personality',
      'color': AppTheme.neonMagenta,
      'icon': Icons.flash_on,
      'pitch': 0.75,
      'speed': 0.95,
      'sample': 'We are ready to conquer the phone. Let’s do it.',
    },
  ];

  void _previewVoice(Map<String, dynamic> p) {
    VoiceService.instance.speak(p['sample']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.obsidian,
      appBar: AppBar(
        title: const Text('Voice Persona Studio'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Choose Active AI Voice Persona',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          ..._personas.map((p) {
            final isSelected = _selectedPersona == p['id'];
            final color = p['color'] as Color;

            return GestureDetector(
              onTap: () {
                setState(() => _selectedPersona = p['id']);
                SettingsService.instance.setActivePersona(p['id']);
                _previewVoice(p);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.obsidianElevated : AppTheme.obsidianCard,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSelected ? color : AppTheme.borderViolet,
                    width: isSelected ? 2.0 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.25),
                            blurRadius: 16,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: color.withValues(alpha: 0.5)),
                          ),
                          child: Icon(p['icon'], color: color, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p['name'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                p['tagline'],
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                            ),
                            child: const Icon(Icons.check, size: 14, color: Colors.black),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _previewVoice(p),
                          icon: Icon(Icons.volume_up, size: 16, color: color),
                          label: Text(
                            'Play Voice Preview',
                            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
