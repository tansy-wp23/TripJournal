import 'package:flutter/material.dart';

import 'settings_preferences.dart';

abstract class SettingsStore {
  Future<SettingsPreferences> load();
  Future<void> save(SettingsPreferences preferences);
}

class SettingsController extends ChangeNotifier {
  SettingsController(this._store);

  final SettingsStore _store;
  SettingsPreferences _preferences = SettingsPreferences.defaults;
  Future<void>? _loadInProgress;
  bool _loaded = false;
  SettingsPreferences get preferences => _preferences;

  Future<void> load() async {
    if (_loaded) return;
    final existing = _loadInProgress;
    if (existing != null) return existing;
    final future = _loadOnce();
    _loadInProgress = future;
    await future;
    _loadInProgress = null;
  }

  Future<void> _loadOnce() async {
    try {
      _preferences = await _store.load();
    } catch (_) {
      _preferences = SettingsPreferences.defaults;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) => _update(_preferences.copyWith(themeMode: mode));
  Future<void> setReminderEnabled(bool enabled) =>
      _update(_preferences.copyWith(journalReminderEnabled: enabled));
  Future<void> setReminderTime(TimeOfDay time) =>
      _update(_preferences.copyWith(journalReminderTime: time));
  Future<void> setShowFoodPhotosInCarousel(bool show) =>
      _update(_preferences.copyWith(showFoodPhotosInCarousel: show));

  Future<void> _update(SettingsPreferences preferences) async {
    _preferences = preferences;
    notifyListeners();
    await _store.save(preferences);
  }
}
