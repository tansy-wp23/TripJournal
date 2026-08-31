import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../widgets/app_form_section.dart';
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
    await ref
        .read(journalReminderCoordinatorProvider)
        .reconcile(ref.read(tripControllerProvider).trips);
  }

  Future<void> _toggleReminder(bool enabled) async {
    final controller = ref.read(settingsControllerProvider);
    if (enabled) {
      final granted = await ref
          .read(journalReminderServiceProvider)
          .requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification permission was not granted.'),
            ),
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
      body: LayoutBuilder(
        builder: (context, viewport) => ListView(
          padding: EdgeInsets.fromLTRB(
            viewport.maxWidth < 480 ? 12 : 24,
            12,
            viewport.maxWidth < 480 ? 12 : 24,
            32,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 712),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppFormSection(
                      title: 'Appearance',
                      icon: Icons.palette_outlined,
                      helperText:
                          'Choose how TripJournal looks on this device.',
                      child: Column(
                        children: [
                          _ThemeModeOption(
                            key: const Key('theme-system'),
                            icon: Icons.brightness_auto_outlined,
                            title: 'System',
                            subtitle: 'Follow device setting',
                            selected: settings.themeMode == ThemeMode.system,
                            onTap: () =>
                                controller.setThemeMode(ThemeMode.system),
                          ),
                          const Divider(),
                          _ThemeModeOption(
                            key: const Key('theme-light'),
                            icon: Icons.light_mode_outlined,
                            title: 'Light',
                            subtitle: 'Bright sky surfaces',
                            selected: settings.themeMode == ThemeMode.light,
                            onTap: () =>
                                controller.setThemeMode(ThemeMode.light),
                          ),
                          const Divider(),
                          _ThemeModeOption(
                            key: const Key('theme-dark'),
                            icon: Icons.dark_mode_outlined,
                            title: 'Dark',
                            subtitle: 'Deep ocean surfaces',
                            selected: settings.themeMode == ThemeMode.dark,
                            onTap: () =>
                                controller.setThemeMode(ThemeMode.dark),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppFormSection(
                      title: 'Journal',
                      icon: Icons.menu_book_outlined,
                      helperText:
                          'Build a gentle writing habit while travelling.',
                      child: Column(
                        children: [
                          SwitchListTile(
                            key: const Key('journal-reminder-switch'),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Journal reminder'),
                            subtitle: Text(
                              mobile
                                  ? 'Only on days when a trip is active'
                                  : 'Notifications require an Android or iOS mobile device.',
                            ),
                            value: mobile && settings.journalReminderEnabled,
                            onChanged: mobile ? _toggleReminder : null,
                          ),
                          const Divider(),
                          ListTile(
                            key: const Key('journal-reminder-time'),
                            contentPadding: EdgeInsets.zero,
                            enabled: mobile && settings.journalReminderEnabled,
                            leading: const Icon(Icons.schedule_outlined),
                            title: const Text('Reminder time'),
                            trailing: Text(
                              settings.journalReminderTime.format(context),
                            ),
                            onTap: _pickReminderTime,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppFormSection(
                      title: 'Health',
                      icon: Icons.favorite_outline,
                      helperText:
                          'Bring steps and calories into your daily journal.',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          _healthConnected == true
                              ? Icons.check_circle_outline
                              : Icons.health_and_safety_outlined,
                        ),
                        title: Text(
                          !mobile
                              ? 'Requires an Android or iOS mobile device.'
                              : _healthConnected == true
                              ? 'Connected'
                              : 'Not connected',
                        ),
                        subtitle: const Text(
                          'Sync steps and calories from your phone health app.',
                        ),
                        trailing: mobile && _healthConnected != true
                            ? FilledButton(
                                onPressed: _connectHealth,
                                child: const Text('Connect'),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppFormSection(
                      title: 'About',
                      icon: Icons.info_outline,
                      helperText: 'App information and open-source notices.',
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.luggage_outlined),
                            title: const Text('TripJournal'),
                            subtitle: Text(
                              _version.isEmpty
                                  ? 'Travel and wellness journal'
                                  : 'Version $_version',
                            ),
                          ),
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.policy_outlined),
                            title: const Text('Legal notices'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => showLicensePage(
                              context: context,
                              applicationName: 'TripJournal',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeModeOption extends StatelessWidget {
  const _ThemeModeOption({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: selected ? colors.primary : null),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(
        selected ? Icons.check_circle : Icons.circle_outlined,
        color: selected ? colors.primary : colors.outline,
      ),
      selected: selected,
      onTap: onTap,
    );
  }
}
