import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/profile.dart';
import '../../../models/verification_code.dart';
import '../../auth/screens/code_entry_screen.dart';
import '../../auth/screens/delete_account_screen.dart';
import '../../settings/settings_screen.dart';
import '../../trip/screens/trip_trash_screen.dart';
import '../../../widgets/app_form_section.dart';
import '../../../widgets/app_page_header.dart';
import '../controller/profile_controller.dart';
import '../widgets/profile_avatar.dart';
import 'profile_edit_screen.dart';

class ProfileViewScreen extends ConsumerStatefulWidget {
  const ProfileViewScreen({super.key});

  @override
  ConsumerState<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends ConsumerState<ProfileViewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileControllerProvider.notifier).loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileController = ref.watch(profileControllerProvider);
    final profile = profileController.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _buildBody(context, profileController, profile),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ProfileController controller,
    Profile? profile,
  ) {
    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.error != null) {
      return Center(child: Text('Error: ${controller.error}'));
    }
    if (profile == null) {
      return const Center(child: Text('No profile found.'));
    }

    final horizontalPadding = ((MediaQuery.sizeOf(context).width - 760) / 2)
        .clamp(12.0, double.infinity);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        12,
        horizontalPadding,
        32,
      ),
      children: [
        AppPageHeader(
          title: 'Your travel profile',
          subtitle: 'Keep your identity and travel preferences up to date.',
          action: OutlinedButton.icon(
            key: const Key('profile-edit-button'),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit profile'),
            onPressed: () => _openEdit(context),
          ),
        ),
        _ProfileHero(profile: profile),
        const SizedBox(height: 16),
        AppFormSection(
          title: 'Travel preferences',
          icon: Icons.explore_outlined,
          helperText: 'The details that make TripJournal feel like yours.',
          child: Column(
            children: [
              _InfoRow(
                label: 'Interests',
                value: profile.travelInterests.isEmpty
                    ? 'Not set'
                    : profile.travelInterests.join(', '),
              ),
              const Divider(),
              _InfoRow(label: 'Country', value: profile.country ?? 'Not set'),
              const Divider(),
              _InfoRow(
                label: 'Date of birth',
                value: profile.dateOfBirth == null
                    ? 'Not set'
                    : _formatProfileDate(profile.dateOfBirth!),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppFormSection(
          title: 'App preferences',
          icon: Icons.tune_outlined,
          helperText: 'Personalise the app and manage recoverable trips.',
          child: Column(
            children: [
              ListTile(
                key: const Key('profile-settings-button'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                subtitle: const Text('Theme, reminders, health and legal'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openSettings(context),
              ),
              const Divider(),
              ListTile(
                key: const Key('profile-recently-deleted-button'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restore_from_trash_outlined),
                title: const Text('Recently Deleted'),
                subtitle: const Text('Restore trips before they expire'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openRecentlyDeleted(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppFormSection(
          title: 'Account safety',
          icon: Icons.shield_outlined,
          helperText: 'These actions sign you out and require confirmation.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                key: const Key('deactivate-account-button'),
                onPressed: () => _openDeactivation(context),
                icon: const Icon(Icons.person_off_outlined),
                label: const Text('Deactivate account'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Temporarily close your account. You can reactivate later.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                key: const Key('delete-account-button'),
                onPressed: () => _openDeletion(context),
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Delete account'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Permanently remove your account and all data. This cannot be undone.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openSettings(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  Future<void> _openRecentlyDeleted(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TripTrashScreen()),
    );
  }

  Future<void> _openEdit(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
    );
  }

  Future<void> _openDeactivation(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const CodeEntryScreen(purpose: VerificationPurpose.deactivation),
      ),
    );
  }

  Future<void> _openDeletion(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            ProfileAvatar(
              radius: 44,
              avatarUrl: profile.avatarUrl,
              initial: profile.displayName.isNotEmpty
                  ? profile.displayName[0].toUpperCase()
                  : '?',
            ),
            const SizedBox(height: 14),
            Text(
              profile.displayName,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            Text(
              profile.email,
              style: TextStyle(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _InfoRow(
                    label: 'Role',
                    value: profile.role.toString().split('.').last,
                  ),
                  const Divider(),
                  _InfoRow(
                    label: 'Status',
                    value: profile.status.toString().split('.').last,
                  ),
                  const Divider(),
                  _InfoRow(
                    label: 'Member since',
                    value: _formatProfileDate(profile.createdAt),
                  ),
                  if (profile.lastLoginAt != null) ...[
                    const Divider(),
                    _InfoRow(
                      label: 'Last login',
                      value: _formatProfileDate(profile.lastLoginAt!),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatProfileDate(DateTime date) {
  final local = date.toLocal();
  final y = local.year;
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
