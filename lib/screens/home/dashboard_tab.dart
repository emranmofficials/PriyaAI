import 'package:flutter/material.dart';
import '../../services/screen_automation_service.dart';
import '../../services/settings_service.dart';
import '../../services/task_executor.dart';
import '../../services/voice_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/voice_waveform.dart';

/// The luxury Dashboard Hub matching Priya AI's official branding banner.
class DashboardTab extends StatelessWidget {
  final bool isListening;
  final VoidCallback onToggleVoice;
  final VoidCallback onOpenKeyboard;
  final VoidCallback onOpenAutomation;
  final VoidCallback onOpenCoding;
  final VoidCallback onOpenVoiceChat;
  final VoidCallback onOpenTools;
  final VoidCallback onToggleOverlay;
  final bool overlayActive;
  final bool serviceEnabled;

  const DashboardTab({
    super.key,
    required this.isListening,
    required this.onToggleVoice,
    required this.onOpenKeyboard,
    required this.onOpenAutomation,
    required this.onOpenCoding,
    required this.onOpenVoiceChat,
    required this.onOpenTools,
    required this.onToggleOverlay,
    required this.overlayActive,
    required this.serviceEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = SettingsService.instance;
    final executor = TaskExecutor.instance;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Top status chip pill
          _buildStatusPill(context, settings, serviceEnabled),

          const SizedBox(height: 24),

          // 2. Animated Voice Waveform
          VoiceWaveform(
            isListening: isListening,
            isSpeaking: executor.isBusy || executor.isChatBusy,
            height: 64,
          ),

          const SizedBox(height: 14),

          // 3. Greeting message
          Text(
            settings.girlfriendMode
                ? 'বাবু, আমি তোমাকে কীভাবে সাহায্য করতে পারি?'
                : 'How can I help you today?',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            settings.provider == 'ollama'
                ? 'Offline Local AI • ${settings.model}'
                : '${settings.provider.toUpperCase()} • Ready',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.purpleLight.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 22),

          // 4. Center interactive voice & input buttons
          _buildCenterActionRow(context),

          const SizedBox(height: 28),

          // 5. 2x2 Quick Action Cards Grid
          _buildQuickActionGrid(context),

          const SizedBox(height: 24),

          // 6. Security & Capabilities Pill
          _buildFooterPill(context),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatusPill(
      BuildContext context, SettingsService settings, bool serviceEnabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.obsidianCard,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppTheme.borderViolet.withValues(alpha: 0.8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.purplePrimary.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: serviceEnabled ? AppTheme.success : AppTheme.warning,
              boxShadow: [
                BoxShadow(
                  color: (serviceEnabled ? AppTheme.success : AppTheme.warning)
                      .withValues(alpha: 0.8),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              children: [
                const TextSpan(
                  text: 'AI Status ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: '• Active  ',
                  style: TextStyle(
                    color: serviceEnabled ? AppTheme.success : AppTheme.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: '|  On-Device • Private • Secure',
                  style: TextStyle(
                    color: AppTheme.textMuted.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.shield_outlined,
            size: 15,
            color: AppTheme.purpleLight.withValues(alpha: 0.8),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterActionRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Keyboard Input Button
        _buildIconButton(
          icon: Icons.keyboard_alt_outlined,
          tooltip: 'Type command',
          onTap: onOpenKeyboard,
        ),

        const SizedBox(width: 24),

        // Large Glowing Microphone Button
        GestureDetector(
          onTap: onToggleVoice,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.magentaAccent,
                  AppTheme.purplePrimary,
                  Color(0xFF7C3AED),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: isListening
                      ? AppTheme.magentaAccent.withValues(alpha: 0.8)
                      : AppTheme.purplePrimary.withValues(alpha: 0.5),
                  blurRadius: isListening ? 26 : 18,
                  spreadRadius: isListening ? 4 : 2,
                ),
              ],
            ),
            child: Icon(
              isListening ? Icons.mic : Icons.mic_none_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ),

        const SizedBox(width: 24),

        // Floating Overlay Bubble Toggle
        _buildIconButton(
          icon: overlayActive
              ? Icons.bubble_chart
              : Icons.bubble_chart_outlined,
          tooltip: 'Toggle Overlay',
          color: overlayActive ? AppTheme.magentaAccent : null,
          onTap: onToggleOverlay,
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.obsidianCard,
            border: Border.all(
              color: AppTheme.borderViolet.withValues(alpha: 0.7),
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: color ?? AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.25,
      children: [
        _buildActionCard(
          context,
          icon: Icons.bolt_rounded,
          iconColor: AppTheme.purpleLight,
          title: 'Smart\nAutomation',
          subtitle: 'Screen & App Control',
          badgeText: 'Live',
          badgeColor: AppTheme.purplePrimary,
          onTap: onOpenAutomation,
        ),
        _buildActionCard(
          context,
          icon: Icons.code_rounded,
          iconColor: AppTheme.cyanAccent,
          title: 'Code\nAssistant',
          subtitle: 'Run ! cmd & Hermes',
          badgeText: '70+ Tools',
          badgeColor: AppTheme.cyanAccent,
          onTap: onOpenCoding,
        ),
        _buildActionCard(
          context,
          icon: Icons.favorite_rounded,
          iconColor: AppTheme.magentaAccent,
          title: 'Girlfriend\nVoice Chat',
          subtitle: 'Bangla sweet companion',
          badgeText: 'Priya',
          badgeColor: AppTheme.magentaAccent,
          onTap: onOpenVoiceChat,
        ),
        _buildActionCard(
          context,
          icon: Icons.grid_view_rounded,
          iconColor: const Color(0xFFA78BFA),
          title: 'More\nTools',
          subtitle: 'Ollama & Guardian',
          badgeText: 'Offline AI',
          badgeColor: const Color(0xFFA78BFA),
          onTap: onOpenTools,
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.obsidianCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppTheme.borderViolet.withValues(alpha: 0.7),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: iconColor.withValues(alpha: 0.04),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: badgeColor.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: badgeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterPill(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.obsidianSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.borderViolet.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.all_inclusive, size: 16, color: AppTheme.purpleLight),
          SizedBox(width: 8),
          Text(
            'Smarter  •  Private  •  Limitless',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
