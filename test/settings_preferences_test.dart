import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/settings/settings_preferences.dart';

void main() {
  test('defaults follow the system with reminders disabled at 8 PM', () {
    const settings = SettingsPreferences.defaults;
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.journalReminderEnabled, isFalse);
    expect(settings.journalReminderTime, const TimeOfDay(hour: 20, minute: 0));
  });

  test('copyWith changes one preference without losing the others', () {
    final changed = SettingsPreferences.defaults.copyWith(themeMode: ThemeMode.dark);
    expect(changed.themeMode, ThemeMode.dark);
    expect(changed.journalReminderEnabled, isFalse);
    expect(changed.journalReminderTime, const TimeOfDay(hour: 20, minute: 0));
  });
}
