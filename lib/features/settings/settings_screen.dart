import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../health/platform_health_data_source.dart';
import '../trip/controller/trip_controller.dart';
import 'local_journal_reminder_service.dart';
import 'settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _health = PlatformHealthDataSource();
  bool? _healthConnected;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final info = await PackageInfo.fromPlatform();
    bool? connected;
    if (supportsMobileSettingsFeatures) {
      connected = await _health.hasPermissions();
    }
    if (mounted) {
      setState(() {
        _version = '${info.version}+${info.buildNumber}';
        _healthConnected = connected;
      });
    }
  }

  Future<void> _syncReminders() async {
    await ref.read(journalReminderCoordinatorProvider).reconcile(
      ref.read(tripControllerProvider).trips,
    );
  }

  Future<void> _toggleReminder(bool enabled) async {
    final controller = ref.read(settingsControllerProvider);
    if (enabled) {
      final granted = await ref.read(journalReminderServiceProvider).requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification permission was not granted.')),
          );
        }
        return;
      }
    }
    await controller.setReminderEnabled(enabled);
    await _syncReminders();
  }

  Future<void> _pickReminderTime() async {
    final controller = ref.read(settingsControllerProvider);
    final time = await showTimePicker(
      context: context,
      initialTime: controller.preferences.journalReminderTime,
    );
    if (time == null) return;
    await controller.setReminderTime(time);
    await _syncReminders();
  }

  Future<void> _connectHealth() async {
    final connected = await _health.requestPermissions();
    if (mounted) setState(() => _healthConnected = connected);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(settingsControllerProvider);
    final settings = controller.preferences;
    final mobile = supportsMobileSettingsFeatures;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionTitle('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final mode in ThemeMode.values)
                  ChoiceChip(
                    key: Key('theme-${mode.name}'),
                    label: Text(switch (mode) {
                      ThemeMode.system => 'System',
                      ThemeMode.light => 'Light',
                      ThemeMode.dark => 'Dark',
                    }),
                    selected: settings.themeMode == mode,
                    onSelected: (_) => controller.setThemeMode(mode),
                  ),
              ],
            ),
          ),
          const Divider(),
          const _SectionTitle('Journal reminder'),
          SwitchListTile(
            key: const Key('journal-reminder-switch'),
            title: const Text('Remind me to write'),
            subtitle: Text(mobile
                ? 'Only on days when a trip is active'
                : 'Notifications require an Android or iOS mobile device.'),
            value: mobile && settings.journalReminderEnabled,
            onChanged: mobile ? _toggleReminder : null,
          ),
          ListTile(
            key: const Key('journal-reminder-time'),
            enabled: mobile && settings.journalReminderEnabled,
            leading: const Icon(Icons.schedule),
            title: const Text('Reminder time'),
            trailing: Text(settings.journalReminderTime.format(context)),
            onTap: _pickReminderTime,
          ),
          const Divider(),
          const _SectionTitle('Health data'),
          ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: Text(!mobile
                ? 'Requires an Android or iOS mobile device.'
                : _healthConnected == true
                    ? 'Connected'
                    : 'Not connected'),
            subtitle: const Text('Sync steps and calories from your phone health app.'),
            trailing: mobile && _healthConnected != true
                ? FilledButton(onPressed: _connectHealth, child: const Text('Connect'))
                : null,
          ),
          const Divider(),
          const _SectionTitle('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('TripJournal'),
            subtitle: Text(_version.isEmpty ? 'Travel and wellness journal' : 'Version $_version'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}
