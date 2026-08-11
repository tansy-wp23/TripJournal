import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_controller.dart';
import 'settings_preferences.dart';

class SharedPreferencesSettingsStore implements SettingsStore {
  static const _themeKey = 'settings.themeMode';
  static const _reminderEnabledKey = 'settings.journalReminderEnabled';
  static const _reminderHourKey = 'settings.journalReminderHour';
  static const _reminderMinuteKey = 'settings.journalReminderMinute';

  @override
  Future<SettingsPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString(_themeKey);
    final theme = ThemeMode.values.where((mode) => mode.name == themeName).firstOrNull ?? ThemeMode.system;
    final hour = prefs.getInt(_reminderHourKey) ?? 20;
    final minute = prefs.getInt(_reminderMinuteKey) ?? 0;
    final validTime = hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
    return SettingsPreferences(
      themeMode: theme,
      journalReminderEnabled: prefs.getBool(_reminderEnabledKey) ?? false,
      journalReminderTime: validTime ? TimeOfDay(hour: hour, minute: minute) : const TimeOfDay(hour: 20, minute: 0),
    );
  }

  @override
  Future<void> save(SettingsPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_themeKey, preferences.themeMode.name),
      prefs.setBool(_reminderEnabledKey, preferences.journalReminderEnabled),
      prefs.setInt(_reminderHourKey, preferences.journalReminderTime.hour),
      prefs.setInt(_reminderMinuteKey, preferences.journalReminderTime.minute),
    ]);
  }
}
