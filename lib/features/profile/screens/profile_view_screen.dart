import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/profile.dart';
import '../../../models/verification_code.dart';
import '../../auth/screens/code_entry_screen.dart';
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
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            key: const Key('profile-edit-button'),
            icon: const Icon(Icons.edit),
            tooltip: 'Edit profile',
            onPressed: () => _openEdit(context),
          ),
        ],
      ),
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 16),
        Center(
          child: ProfileAvatar(
            radius: 40,
            avatarUrl: profile.avatarUrl,
            initial: profile.displayName.isNotEmpty
                ? profile.displayName[0].toUpperCase()
                : '?',
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            profile.displayName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            profile.email,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  value: _formatDate(profile.createdAt),
                ),
                if (profile.lastLoginAt != null) ...[
                  const Divider(),
                  _InfoRow(
                    label: 'Last login',
                    value: _formatDate(profile.lastLoginAt!),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        OutlinedButton.icon(
          key: const Key('deactivate-account-button'),
          onPressed: () => _openDeactivation(context),
          icon: const Icon(Icons.person_off),
          label: const Text('Deactivate Account'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Deactivating closes your account and signs you out. You can '
            'reactivate later by signing in with the same Google account.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
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

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final y = local.year;
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
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
