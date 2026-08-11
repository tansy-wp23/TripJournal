import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'journal_reminder_service.dart';
import 'journal_reminder_coordinator.dart';
import 'local_journal_reminder_service.dart';
import 'settings_controller.dart';
import 'shared_preferences_settings_store.dart';

final settingsStoreProvider = Provider<SettingsStore>((ref) => SharedPreferencesSettingsStore());

final settingsControllerProvider = ChangeNotifierProvider<SettingsController>((ref) {
  final controller = SettingsController(ref.watch(settingsStoreProvider));
  controller.load();
  return controller;
});

final journalReminderServiceProvider = Provider<JournalReminderService>((ref) {
  return LocalJournalReminderService();
});

final journalReminderCoordinatorProvider = Provider<JournalReminderCoordinator>((ref) {
  return JournalReminderCoordinator(
    ref.watch(journalReminderServiceProvider),
    ref.watch(settingsControllerProvider),
  );
});
