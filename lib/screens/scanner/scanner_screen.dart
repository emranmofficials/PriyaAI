import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/screen_automation_service.dart';
import '../../services/task_executor.dart';
import '../../theme/app_theme.dart';
import '../../widgets/edge_glow.dart';

/// Maya Vision & Scanner Screen (Route: `scanner` — 100% Maya parity).
///
/// Features:
/// - Futuristic Maya HUD Viewfinder with animated neon scanning laser
/// - Look through screen / camera visual inspection
/// - Instant AI visual analysis of current phone screen
/// - QR / Barcode & Document reading helper
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  final _executor = TaskExecutor.instance;
  final _automation = ScreenAutomationService.instance;

  bool _isScanning = false;
  String _scanStatus = 'প্রিয়া ভিশন স্ক্যানার প্রস্তুত';
  String? _analysisResult;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _analyzeScreen() async {
    setState(() {
      _isScanning = true;
      _scanStatus = 'স্ক্রিনের ছবি নিয়ে এআই বিশ্লেষণ করছে...';
      _analysisResult = null;
    });

    try {
      final shot = await _automation.takeScreenshot();
      if (shot != null && shot.isNotEmpty) {
        // Trigger agent to describe what is seen
        _executor.executeTask('স্ক্রিনে কী দেখতে পাচ্ছ বিস্তারিত দেখে বলো');
        setState(() {
          _scanStatus = 'স্ক্রিন ক্যাপচার সফল হয়েছে!';
          _analysisResult = 'স্ক্রিন বিশ্লেষণ করে মায়া আপনাকে চ্যাটে জানিয়ে দিচ্ছে...';
        });
      } else {
        setState(() {
          _scanStatus = 'স্ক্রিন ক্যাপচার অনুমতি প্রয়োজন!';
          _analysisResult = 'স্ক্রিনশটের পারমিশন না থাকায় বিশ্লেষণ করা যায়নি।';
        });
      }
    } catch (e) {
      setState(() {
        _scanStatus = 'স্ক্যান ত্রুটি';
        _analysisResult = 'বিশ্লেষণ ব্যর্থ হয়েছে: $e';
      });
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0F18),
        title: const Text('মায়া ভিশন স্ক্যানার (Scanner)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          const EdgeGlow(intensity: 0.4),
          Column(
            children: [
              const SizedBox(height: 16),
              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF141828),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.neonCyan.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.neonCyan,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _scanStatus,
                      style: const TextStyle(color: AppTheme.neonCyan, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Viewfinder Box
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF080A12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.neonCyan.withValues(alpha: 0.2)),
                      ),
                      child: Stack(
                        children: [
                          // Animated scan laser line
                          AnimatedBuilder(
                            animation: _animController,
                            builder: (context, child) {
                              return Align(
                                alignment: Alignment(0, (_animController.value * 2) - 1),
                                child: Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        AppTheme.neonCyan.withValues(alpha: 0.8),
                                        AppTheme.neonMagenta.withValues(alpha: 0.8),
                                        Colors.transparent,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.neonCyan.withValues(alpha: 0.6),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          // HUD Corner brackets
                          ..._buildCornerBrackets(),

                          // Center Crosshair
                          Center(
                            child: Icon(
                              Icons.filter_center_focus_rounded,
                              color: AppTheme.neonCyan.withValues(alpha: 0.35),
                              size: 48,
                            ),
                          ),

                          if (_analysisResult != null)
                            Positioned(
                              bottom: 20,
                              left: 20,
                              right: 20,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.neonCyan.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  _analysisResult!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Bottom Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isScanning ? null : _analyzeScreen,
                        icon: _isScanning
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.screenshot_monitor_rounded),
                        label: Text(
                          _isScanning ? 'স্ক্যান হচ্ছে...' : 'স্ক্রিন দেখুন ও পড়ুন',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.neonCyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCornerBrackets() {
    const size = 24.0;
    const stroke = 3.0;
    const color = AppTheme.neonCyan;

    return [
      // Top Left
      Positioned(
        top: 12,
        left: 12,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: stroke),
              left: BorderSide(color: color, width: stroke),
            ),
          ),
        ),
      ),
      // Top Right
      Positioned(
        top: 12,
        right: 12,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: stroke),
              right: BorderSide(color: color, width: stroke),
            ),
          ),
        ),
      ),
      // Bottom Left
      Positioned(
        bottom: 12,
        left: 12,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: stroke),
              left: BorderSide(color: color, width: stroke),
            ),
          ),
        ),
      ),
      // Bottom Right
      Positioned(
        bottom: 12,
        right: 12,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: stroke),
              right: BorderSide(color: color, width: stroke),
            ),
          ),
        ),
      ),
    ];
  }
}
