import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

/// Queries installed apps and launches them by fuzzy name / package match.
class AppLauncherService {
  AppLauncherService._();
  static final AppLauncherService instance = AppLauncherService._();

  List<AppInfo>? _cache;

  /// All launchable, non-system apps (cached for the process lifetime).
  Future<List<AppInfo>> installedApps({bool forceRefresh = false}) async {
    if (_cache != null && !forceRefresh) return _cache!;
    try {
      _cache = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
        excludeNonLaunchableApps: true,
        withIcon: false,
      );
    } catch (_) {
      _cache = const [];
    }
    return _cache!;
  }

  /// Best-matching app for a free-text [query]: exact package id, exact
  /// name, "starts with", "contains", then word-overlap scoring.
  Future<AppInfo?> findApp(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;
    final apps = await installedApps();
    if (apps.isEmpty) return null;

    for (final app in apps) {
      if (app.packageName.toLowerCase() == q) return app;
    }
    for (final app in apps) {
      if (app.name.toLowerCase() == q) return app;
    }
    for (final app in apps) {
      if (app.name.toLowerCase().startsWith(q)) return app;
    }
    for (final app in apps) {
      if (app.name.toLowerCase().contains(q) ||
          app.packageName.toLowerCase().contains(q)) {
        return app;
      }
    }

    // Token overlap fallback (handles "google maps" vs "Maps").
    final tokens =
        q.split(RegExp(r'[^a-z0-9]+')).where((t) => t.length > 2).toSet();
    if (tokens.isEmpty) return null;
    AppInfo? best;
    var bestScore = 0;
    for (final app in apps) {
      final name = app.name.toLowerCase();
      var score = 0;
      for (final t in tokens) {
        if (name.contains(t)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        best = app;
      }
    }
    return best;
  }

  /// Launches [query] (name or package). Returns a human-readable outcome
  /// message: the app name on success, null on failure.
  Future<String?> launch(String query) async {
    final app = await findApp(query);
    if (app == null) return null;
    try {
      final ok = await InstalledApps.startApp(app.packageName) ?? false;
      return ok ? app.name : null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> launchAppByName(String name) => launch(name);
}
