import 'package:flutter/material.dart';

class SettingsPreferences {
  const SettingsPreferences({
    required this.themeMode,
    required this.journalReminderEnabled,
    required this.journalReminderTime,
  });

  static const defaults = SettingsPreferences(
    themeMode: ThemeMode.system,
    journalReminderEnabled: false,
    journalReminderTime: TimeOfDay(hour: 20, minute: 0),
  );

  final ThemeMode themeMode;
  final bool journalReminderEnabled;
  final TimeOfDay journalReminderTime;

  SettingsPreferences copyWith({
    ThemeMode? themeMode,
    bool? journalReminderEnabled,
    TimeOfDay? journalReminderTime,
  }) {
    return SettingsPreferences(
      themeMode: themeMode ?? this.themeMode,
      journalReminderEnabled: journalReminderEnabled ?? this.journalReminderEnabled,
      journalReminderTime: journalReminderTime ?? this.journalReminderTime,
    );
  }
}
