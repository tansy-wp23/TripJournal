import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'journal_reminder_service.dart';

bool get supportsMobileSettingsFeatures => !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

class LocalJournalReminderService implements JournalReminderService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  @override
  bool get isSupported => supportsMobileSettingsFeatures;

  Future<void> _initialize() async {
    if (_initialized || !isSupported) return;
    tzdata.initializeTimeZones();
    final local = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(local.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    try {
      await _initialize();
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _plugin
                .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false;
      }
      return await _plugin
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> replaceScheduled(List<ScheduledJournalReminder> reminders) async {
    if (!isSupported) return;
    try {
      await _initialize();
      await cancelAll();
      for (final reminder in reminders) {
        await _plugin.zonedSchedule(
        id: reminder.id,
        title: 'TripJournal reminder',
        body: 'Take a moment to write today’s travel journal entry.',
        scheduledDate: tz.TZDateTime.from(reminder.when, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'trip_journal_reminders',
            'Travel journal reminders',
            channelDescription: 'Daily reminders while a trip is active',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {
      return;
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!isSupported) return;
    try {
      await _initialize();
      for (var i = 0; i < 60; i++) {
        await _plugin.cancel(id: 41000 + i);
      }
    } catch (_) {
      return;
    }
  }
}
