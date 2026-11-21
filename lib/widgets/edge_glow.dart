import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Animated edge glow frame surrounding the display when the assistant is active.
/// Directly mirrors Maya's `settings_core_adv_edge_glow`.
class EdgeGlow extends StatefulWidget {
  final Widget child;
  final bool active;
  final bool isSpeaking;
  final bool isListening;

  const EdgeGlow({
    super.key,
    required this.child,
    this.active = false,
    this.isSpeaking = false,
    this.isListening = false,
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
    if (widget.active || widget.isListening || widget.isSpeaking) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant EdgeGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isLive = widget.active || widget.isListening || widget.isSpeaking;
    final wasLive = oldWidget.active || oldWidget.isListening || oldWidget.isSpeaking;
    if (isLive && !wasLive) {
      _controller.repeat();
    } else if (!isLive && wasLive) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLive = widget.active || widget.isListening || widget.isSpeaking;

    return Stack(
      children: [
        widget.child,
        if (isLive)
          Positioned.fill(
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

                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: glowColor.withValues(alpha: 0.5 * pulse),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.28 * pulse),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.12 * pulse),
                          blurRadius: 36,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
