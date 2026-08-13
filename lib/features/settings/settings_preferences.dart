import 'package:flutter/material.dart';

class SettingsPreferences {
  const SettingsPreferences({
    required this.themeMode,
    required this.journalReminderEnabled,
    required this.journalReminderTime,
    this.showFoodPhotosInCarousel = true,
  });

  static const defaults = SettingsPreferences(
    themeMode: ThemeMode.system,
    journalReminderEnabled: false,
    journalReminderTime: TimeOfDay(hour: 20, minute: 0),
    showFoodPhotosInCarousel: true,
  );

  final ThemeMode themeMode;
  final bool journalReminderEnabled;
  final TimeOfDay journalReminderTime;

  /// Whether meal photos share the trip header's carousel with the trip's own
  /// pictures. Defaults to on — a food photo is still a photo of the trip.
  ///
  /// Scoped to the carousel deliberately: the per-day strips and the
  /// full-screen slideshow always show everything, so turning this off tidies
  /// the header without making any photo unreachable.
  final bool showFoodPhotosInCarousel;

  SettingsPreferences copyWith({
    ThemeMode? themeMode,
    bool? journalReminderEnabled,
    TimeOfDay? journalReminderTime,
    bool? showFoodPhotosInCarousel,
  }) {
    return SettingsPreferences(
      themeMode: themeMode ?? this.themeMode,
      journalReminderEnabled: journalReminderEnabled ?? this.journalReminderEnabled,
      journalReminderTime: journalReminderTime ?? this.journalReminderTime,
      showFoodPhotosInCarousel: showFoodPhotosInCarousel ?? this.showFoodPhotosInCarousel,
    );
  }
}
