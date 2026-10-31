import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Animated glowing voice waveform visualizer matching Priya AI's official branding.
class VoiceWaveform extends StatefulWidget {
  final bool isListening;
  final bool isSpeaking;
  final double height;

  const VoiceWaveform({
    super.key,
    this.isListening = false,
    this.isSpeaking = false,
    this.height = 70,
  });

  @override
  State<VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<VoiceWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          height: widget.height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(28, (index) {
              final active = widget.isListening || widget.isSpeaking;
              final t = _controller.value * 2 * math.pi;
              final offset = (index / 28) * 2 * math.pi;

              // Gaussian bell curve multiplier so edges are shorter, center is taller
              final centerDist = (index - 13.5).abs() / 14.0;
              final bell = math.exp(-centerDist * centerDist * 3);

              final wave = math.sin(t + offset) * 0.5 + 0.5;
              final heightMultiplier = active ? 0.35 + 0.65 * wave : 0.2 + 0.3 * wave;
              final barHeight = math.max(6.0, widget.height * bell * heightMultiplier);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.8),
                width: 3.5,
                height: barHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.magentaAccent,
                      AppTheme.purplePrimary,
                      AppTheme.cyanAccent,
                    ],
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: AppTheme.purplePrimary.withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
