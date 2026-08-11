import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/settings/settings_controller.dart';
import 'package:tripjournal/features/settings/settings_preferences.dart';

class MemorySettingsStore implements SettingsStore {
  SettingsPreferences? value;
  @override
  Future<SettingsPreferences> load() async => value ?? SettingsPreferences.defaults;
  @override
  Future<void> save(SettingsPreferences preferences) async => value = preferences;
}

void main() {
  test('loads persisted preferences and saves changes', () async {
    final store = MemorySettingsStore()
      ..value = SettingsPreferences.defaults.copyWith(themeMode: ThemeMode.dark);
    final controller = SettingsController(store);
    await controller.load();
    expect(controller.preferences.themeMode, ThemeMode.dark);

    await controller.setReminderTime(const TimeOfDay(hour: 9, minute: 15));
    expect(store.value!.journalReminderTime, const TimeOfDay(hour: 9, minute: 15));
  });

  test('load failure falls back to safe defaults', () async {
    final controller = SettingsController(_FailingStore());
    await controller.load();
    expect(controller.preferences, same(SettingsPreferences.defaults));
  });
}

class _FailingStore implements SettingsStore {
  @override
  Future<SettingsPreferences> load() => throw StateError('broken preferences');
  @override
  Future<void> save(SettingsPreferences preferences) async {}
}
