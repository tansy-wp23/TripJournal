import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controller/auth_controller.dart';

/// Shown when a signed-in profile's [role][Profile.role] is
/// `UserRole.admin` — `AuthGate` refuses to treat it as an ordinary
/// traveler sign-in.
///
/// `docs/admin/PROGRESS.md`'s confirmed identity-model decision
/// (2026-08-12) says admin accounts are always dedicated — a separate
/// `Profile` row from any traveler account the same person might
/// separately have — so `AuthGate` and `AdminGate` were meant to be "two
/// independent, non-overlapping entry points," with no sign-in ever
/// resolving to both. That was only ever true by provisioning convention,
/// not enforced in code (found and fixed 2026-08-26, `AuthController.status`).
/// This screen is what closes the gap: rather than silently handing an
/// admin-role profile the traveler `HomeScreen`, it says so directly and
/// offers a way out (sign out, then sign in through the Admin Portal
/// instead — the hidden logo-tap entry on `LoginScreen`).
class AdminAccountScreen extends ConsumerWidget {
  const AdminAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'This Is an Administrator Account',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'This Google account is registered as an administrator, so '
                  "it can't sign in to the traveler app. Sign out, then use "
                  'the Admin Portal instead.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                OutlinedButton(
                  key: const Key('admin-account-sign-out'),
                  onPressed: () async {
                    await ref.read(authControllerProvider.notifier).signOut();
                  },
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
