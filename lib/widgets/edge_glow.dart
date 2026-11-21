import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Animated edge glow frame surrounding the display when the assistant is active.
/// Directly mirrors Maya's `settings_core_adv_edge_glow`.
class EdgeGlow extends StatefulWidget {
  final Widget? child;
  final bool active;
  final bool isSpeaking;
  final bool isListening;
  final double intensity;

  const EdgeGlow({
    super.key,
    this.child,
    this.active = false,
    this.isSpeaking = false,
    this.isListening = false,
    this.intensity = 0.5,
  });

  @override
  State<EdgeGlow> createState() => _EdgeGlowState();
}

class _EdgeGlowState extends State<EdgeGlow> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glowWidget = Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final glowColor = widget.isSpeaking
                ? AppTheme.neonMagenta
                : widget.isListening
                    ? AppTheme.neonCyan
                    : AppTheme.neonViolet;

            final pulse = (math.sin(_controller.value * 2 * math.pi) * 0.25) + 0.75;
            final alpha = (widget.intensity * pulse).clamp(0.0, 1.0);

            return Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: glowColor.withValues(alpha: 0.5 * alpha),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.25 * alpha),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.1 * alpha),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    if (widget.child == null) {
      return glowWidget;
    }

    return Stack(
      children: [
        widget.child!,
        glowWidget,
      ],
    );
  }
}
