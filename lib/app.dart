import 'package:flutter/material.dart';

import 'screens/home/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

/// Root application widget with theme + onboarding routing.
class PriyaApp extends StatefulWidget {
  const PriyaApp({super.key});

  @override
  State<PriyaApp> createState() => _PriyaAppState();
}

class _PriyaAppState extends State<PriyaApp> {
  final _settings = SettingsService.instance;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Priya AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _settings.themeMode,
      home: _settings.onboardingComplete
          ? const HomeScreen()
          : OnboardingScreen(onFinished: () => setState(() {})),
    );
  }
}
