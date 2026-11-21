import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The signature Maya Glowing HUD Orb.
///
/// Features a multi-layered procedural particle and ray canvas:
/// - [orbHudCore]: Central energy sphere with Gaussian radial glow
/// - [orbHudRing]: Gyroscopic 3D HUD orbital rings with tick marks
/// - [orbHudRaysPct]: Reactive sound rays that flare out with audio amplitude
/// - Smooth state-based breathing, listening, thinking, and speaking animations
class MayaOrb extends StatefulWidget {
  final bool isListening;
  final bool isThinking;
  final bool isSpeaking;
  final double size;
  final VoidCallback? onTap;

  const MayaOrb({
    super.key,
    this.isListening = false,
    this.isThinking = false,
    this.isSpeaking = false,
    this.size = 230,
    this.onTap,
  });

  @override
  State<MayaOrb> createState() => _MayaOrbState();
}

class _MayaOrbState extends State<MayaOrb> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _rayController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _rayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _rayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _rotationController,
          _pulseController,
          _rayController,
        ]),
        builder: (context, child) {
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _MayaOrbPainter(
              rotation: _rotationController.value,
              pulse: _pulseController.value,
              rayProgress: _rayController.value,
              isListening: widget.isListening,
              isThinking: widget.isThinking,
              isSpeaking: widget.isSpeaking,
            ),
          );
        },
      ),
    );
  }
}

class _MayaOrbPainter extends CustomPainter {
  final double rotation;
  final double pulse;
  final double rayProgress;
  final bool isListening;
  final bool isThinking;
  final bool isSpeaking;

  _MayaOrbPainter({
    required this.rotation,
    required this.pulse,
    required this.rayProgress,
    required this.isListening,
    required this.isThinking,
    required this.isSpeaking,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.28;

    // Pulse scale based on state
    final pulseScale = isListening
        ? 1.0 + (math.sin(rayProgress * 4 * math.pi) * 0.12).abs()
        : isSpeaking
            ? 1.0 + (math.sin(rayProgress * 3 * math.pi) * 0.16).abs()
            : isThinking
                ? 0.98 + (math.sin(rotation * 6 * math.pi) * 0.06).abs()
                : 0.96 + (pulse * 0.08); // Breathing

    final currentRadius = baseRadius * pulseScale;

    // 1. Draw outer ambient corona glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          isListening
              ? AppTheme.neonCyan.withValues(alpha: 0.45)
              : isSpeaking
                  ? AppTheme.neonMagenta.withValues(alpha: 0.45)
                  : isThinking
                      ? AppTheme.neonEmerald.withValues(alpha: 0.40)
                      : AppTheme.neonViolet.withValues(alpha: 0.35),
          isListening
              ? AppTheme.neonViolet.withValues(alpha: 0.15)
              : isSpeaking
                  ? AppTheme.neonViolet.withValues(alpha: 0.15)
                  : AppTheme.neonCyan.withValues(alpha: 0.10),
          Colors.transparent,
        ],
        stops: const [0.2, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: currentRadius * 2.2));

    canvas.drawCircle(center, currentRadius * 2.2, glowPaint);

    // 2. Draw HUD Rays (Acoustic audio flare spikes)
    final numRays = isListening || isSpeaking ? 36 : 24;
    final rayPaint = Paint()
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < numRays; i++) {
      final angle = (i / numRays) * 2 * math.pi + (rotation * 0.4 * math.pi);
      final rayNoise = math.sin(angle * 4 + rayProgress * 2 * math.pi);
      final rayLength = isListening || isSpeaking
          ? currentRadius * 0.35 + (rayNoise * currentRadius * 0.25).abs()
          : currentRadius * 0.15 + (rayNoise * currentRadius * 0.08).abs();

      final rayStart = currentRadius + 8;
      final rayEnd = rayStart + rayLength;

      final p1 = Offset(
        center.dx + math.cos(angle) * rayStart,
        center.dy + math.sin(angle) * rayStart,
      );
      final p2 = Offset(
        center.dx + math.cos(angle) * rayEnd,
        center.dy + math.sin(angle) * rayEnd,
      );

      final rayColor = isListening
          ? Color.lerp(AppTheme.neonCyan, AppTheme.neonViolet, i / numRays)!
          : isSpeaking
              ? Color.lerp(AppTheme.neonMagenta, AppTheme.neonViolet, i / numRays)!
              : Color.lerp(AppTheme.neonViolet, AppTheme.neonCyan, i / numRays)!;

      rayPaint.color = rayColor.withValues(alpha: isListening || isSpeaking ? 0.75 : 0.35);
      canvas.drawLine(p1, p2, rayPaint);
    }

    // 3. Draw Rotating HUD Rings (orbHudRing)
    _drawHudRing(canvas, center, currentRadius * 1.35, rotation * 2 * math.pi, 0.45);
    _drawHudRing(canvas, center, currentRadius * 1.55, -rotation * 1.4 * math.pi, 0.30);

    // 4. Draw Core (orbHudCore)
    final coreGradient = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          math.cos(rotation * 2 * math.pi) * 0.25,
          math.sin(rotation * 2 * math.pi) * 0.25,
        ),
        radius: 0.85,
        colors: isListening
            ? [
                Colors.white,
                AppTheme.neonCyanLight,
                AppTheme.neonCyan,
                AppTheme.neonViolet,
                const Color(0xFF0F0826),
              ]
            : isSpeaking
                ? [
                    Colors.white,
                    const Color(0xFFFF85B3),
                    AppTheme.neonMagenta,
                    AppTheme.neonViolet,
                    const Color(0xFF1A0518),
                  ]
                : isThinking
                    ? [
                        Colors.white,
                        const Color(0xFF70FFE9),
                        AppTheme.neonEmerald,
                        AppTheme.neonCyan,
                        const Color(0xFF04181A),
                      ]
                    : [
                        Colors.white,
                        AppTheme.neonPurpleLight,
                        AppTheme.neonViolet,
                        const Color(0xFF4C1D95),
                        const Color(0xFF0E0720),
                      ],
        stops: const [0.0, 0.25, 0.55, 0.82, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: currentRadius));

    canvas.drawCircle(center, currentRadius, coreGradient);

    // 5. Draw Core Specular Glass Rim
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = SweepGradient(
        colors: [
          Colors.white.withValues(alpha: 0.8),
          AppTheme.neonCyan.withValues(alpha: 0.6),
          Colors.transparent,
          AppTheme.neonViolet.withValues(alpha: 0.5),
          Colors.white.withValues(alpha: 0.8),
        ],
        transform: GradientRotation(rotation * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: currentRadius));

    canvas.drawCircle(center, currentRadius, rimPaint);
  }

  void _drawHudRing(
    Canvas canvas,
    Offset center,
    double radius,
    double angleOffset,
    double opacity,
  ) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppTheme.neonCyan.withValues(alpha: opacity * 0.5);

    // Outer faint track
    canvas.drawCircle(center, radius, ringPaint);

    // Segmented dashed arcs
    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = isSpeaking
          ? AppTheme.neonMagenta.withValues(alpha: opacity)
          : isListening
              ? AppTheme.neonCyan.withValues(alpha: opacity)
              : AppTheme.neonViolet.withValues(alpha: opacity);

    const segments = 4;
    const arcLength = (2 * math.pi / segments) * 0.45;

    for (int i = 0; i < segments; i++) {
      final startAngle = (i * 2 * math.pi / segments) + angleOffset;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        arcLength,
        false,
        dashPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MayaOrbPainter oldDelegate) => true;
}
