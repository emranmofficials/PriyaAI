import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'app.dart';
import 'overlay/overlay_app.dart';
import 'services/hermes_memory_service.dart';
import 'services/macro_runner_service.dart';
import 'services/notification_intelligence_service.dart';
import 'services/priya_driving_service.dart';
import 'services/priya_nudge_service.dart';
import 'services/screen_automation_service.dart';
import 'services/settings_service.dart';
import 'services/task_executor.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = SettingsService.instance;
  await settings.init();

  await HermesMemoryService.instance.init();
  await MacroRunnerService.instance.init();
  await PriyaDrivingService.instance.init();

  final executor = TaskExecutor.instance;
  await executor.init();

  NotificationIntelligenceService.instance.start();
  PriyaNudgeService.instance.start();

  _wireOverlayCommands(executor);

  runApp(const PriyaApp());
}

/// Commands coming from the floating overlay bubble/panel.
void _wireOverlayCommands(TaskExecutor executor) {
  FlutterOverlayWindow.overlayListener.listen((event) async {
    if (event is! String) return;
    Map<String, dynamic> decoded;
    try {
      final d = jsonDecode(event);
      if (d is! Map) return;
      decoded = d.map((k, v) => MapEntry('$k', v));
    } catch (_) {
      return;
    }
    if (decoded['type'] != 'command') return;
    switch (decoded['command']) {
      case 'start':
        final goal = decoded['goal']?.toString().trim() ?? '';
        if (goal.isNotEmpty && !executor.isBusy) {
          unawaited(executor.executeTask(goal));
        }
        break;
      case 'pause':
        executor.pause();
        break;
      case 'resume':
        executor.resume();
        break;
      case 'cancel':
        executor.cancel();
        break;
    }
  });
}

/// Entry point for the floating overlay window (separate Flutter engine
/// running in its own isolate). Must stay a top-level function annotated
/// with vm:entry-point.
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OverlayApp());
}
